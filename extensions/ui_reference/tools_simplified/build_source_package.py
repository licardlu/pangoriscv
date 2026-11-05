"""Create and verify a source-only YOLO/RTL + business-module ZIP.

Only the Python standard library is used. Packaging and static verification do
not invoke RISC-V tools, PDS, a simulator, a serial port, or a board.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tempfile
import zipfile


FORMAT = "simplified-source-package-v1"
ALLOWED_CHECKSUM_DELTA_PATH = "software/platform_main.c"
GENERATED_SUFFIXES = {
    ".adf", ".cmr", ".db", ".dmr", ".elf", ".map", ".pds", ".prr", ".prt",
    ".rdb", ".rtr", ".sbit", ".sfc", ".su", ".udb", ".vcd", ".wlf",
}
SOURCE_SUFFIXES = {
    ".bin", ".c", ".f", ".fdc", ".h", ".hex", ".idf", ".json", ".ld",
    ".mak", ".md", ".mk", ".pcf", ".py", ".s", ".sh", ".sv", ".tcl",
    ".txt", ".v", ".vh", ".vhdl", ".vp", ".xml",
}
FORBIDDEN_SEGMENTS = {
    "__pycache__", ".git", "build", "cards", "compile", "constraint_check",
    "device_map", "evidence", "local_data", "log", "logs", "logbackup",
    "offline_state", "pds", "pnr", "place_route", "release", "route_db",
    "standalone", "synthesize", "target", "work",
}
FORBIDDEN_NAME_TOKENS = (
    "qr_scan", "offline_state", "ledger.c", "ledger.h", "flash_maintenance",
    "standalone_main", "standalone_application", "standalone_display",
)

# Keep YOLO/OSD, camera preview, classification mapping, and audio streaming
# support. Servo control remains excluded; I²S output targets an external amp.
BUSINESS_FILES = (
    "application/firmware/audio_drain.c", "application/firmware/audio_drain.h",
    "application/firmware/io.c",
    "application/firmware/io.h", "application/firmware/vision.c",
    "application/firmware/vision.h", "application/firmware/app_yolo.c",
    "application/firmware/app_yolo.h", "application/firmware/app.c",
    "application/firmware/app.h", "application/firmware/service.c",
    "application/firmware/service.h", "application/tests/test_simplified_app.c",
    "application/firmware/platform.c", "application/firmware/platform.h",
    "application/rtl/camera_cdc.sv", "application/rtl/camera_preview.sv",
    "application/rtl/ui_rgb.sv", "application/rtl/vision_font.vh",
    "application/rtl/vision_overlay.sv", "application/rtl/i2s_tx.sv",
    "application/rtl/bcd32.sv", "application/rtl/vision_mmio.sv",
    "application/rtl/ui_light_panel.sv", "application/rtl/light_split_video.sv",
    "application/rtl/snapshot_cdc.sv",
    "application/tests/ui_points_audio_tb.sv", "application/tests/ui_points_audio_frame_tb.sv",
    "application/tests/vision_display_tb.sv", "application/tests/test_audio_assets.py",
    "application/tests/audio_retire_tb.sv",
    "application/tools/test_ui_points_audio.py", "application/tools/test_rtl.py",
    "application/tests/display_tb.sv", "application/tests/overlay_tb.sv",
    "application/assets/ui_bg.hex", "application/assets/ui_palette.hex", "application/assets/ui_status.hex",
    "application/assets/ui_light_bg.hex", "application/assets/ui_light_palette.hex", "application/assets/ui_light_status.hex",
    "application/assets/ui_light_layout.json",
    "application/assets/白色布局_实时视频链路_RTL仿真.png", "application/assets/摄像头仿真输入.png",
    "application/assets/audio/VOICE_MANIFEST.json",
    "application/tools/light_ui_assets.py", "application/tools/make_voice.ps1",
    "application/tools/test_light_split_video.py", "application/tools/test_light_live_frame.py",
    "application/tests/light_panel_tb.sv", "application/tests/light_split_video_tb.sv", "application/tests/light_live_frame_tb.sv",
    "application/tests/test_light_ui_assets.py", "application/tests/test_voice_assets.py",
    "application/docs/白色分屏与提示语音.md", "application/docs/语音素材清单.md",
    "application/docs/本次修改与验证.md",
    "rtl/camera_events.sv", "rtl/request_cdc.sv",
    "rtl/shared_boot_flash.sv", "rtl/uart_mode.sv",
    "application/docs/积分与音频状态界面.md",
)
REQUIRED_BUSINESS_FILES = {
    "application/firmware/audio_drain.c", "application/firmware/audio_drain.h",
    "application/firmware/io.c", "application/firmware/io.h",
    "application/firmware/vision.c", "application/firmware/vision.h",
    "application/firmware/app_yolo.c", "application/firmware/app_yolo.h",
    "application/firmware/app.c", "application/firmware/app.h",
    "application/firmware/service.c", "application/firmware/service.h",
    "application/tests/test_simplified_app.c",
    "application/firmware/platform.c", "application/firmware/platform.h",
    "application/rtl/vision_overlay.sv", "application/rtl/camera_preview.sv",
}
REQUIRED_VOICE = {"CORRECT.WAV", "PROMPT.WAV", "TIMEOUT.WAV", "WRONG.WAV"}
REQUIRED_MUSIC = {"MUSIC0.WAV", "MUSIC1.WAV", "MUSIC2.WAV"}
REQUIRED_AUDIO = REQUIRED_VOICE | REQUIRED_MUSIC
EXCLUDED_APPLICATION_PATHS = {
    "application/firmware/business_main.c", "application/firmware/main.c",
    "application/firmware/platform_business.h", "application/firmware/platform_yolo.inc",
    "application/firmware/platform_vision.inc", "application/firmware/ui_hitboxes.h",
    "application/rtl/app_mmio.sv",
    "application/rtl/servo_guard.sv",
    "application/rtl/servo_pwm.sv",
}
EXCLUDED_VOICE_ASSETS = set()
VOICE_ASSET_DIR = "application/assets/audio"
ALLOWED_VOICE_ASSET_PATHS = {
    f"extensions/business/{VOICE_ASSET_DIR}/{name}" for name in REQUIRED_AUDIO
} | {"extensions/business/application/assets/audio/VOICE_MANIFEST.json"}
ALLOWED_BUSINESS_PACKAGE_PATHS = {
    f"extensions/business/{relative}" for relative in BUSINESS_FILES
} | ALLOWED_VOICE_ASSET_PATHS
REQUIRED_PACKAGE_FILES = {
    "yolo/software/platform_main.c", "yolo/software/test_bbox_osd.c",
    "yolo/tb/tb_bbox_osd.v", "yolo/model/model.bin",
    "yolo/build_pre_pnr.tcl",
    "tools_simplified/build_source_package.py",
    "extensions/business/application/firmware/audio_drain.c",
    "extensions/business/application/firmware/app.c",
    "extensions/business/application/firmware/app.h",
    "extensions/business/application/firmware/service.c",
    "extensions/business/application/firmware/service.h",
    "extensions/business/application/tests/test_simplified_app.c",
    "extensions/business/application/firmware/io.c",
    "extensions/business/application/firmware/vision.c",
    "extensions/business/application/rtl/vision_overlay.sv",
    "extensions/business/application/rtl/camera_preview.sv",
    "extensions/business/application/rtl/i2s_tx.sv",
    *(f"extensions/business/application/assets/audio/{name}" for name in REQUIRED_AUDIO),
}
APP_SERVICE_PACKAGE_PATHS = {
    f"extensions/business/{relative}" for relative in (
        "application/firmware/app.c", "application/firmware/app.h",
        "application/firmware/service.c", "application/firmware/service.h",
        "application/tests/test_simplified_app.c",
    )
}
SERVO_MUSIC_SYMBOL = re.compile(
    r"\b(?:servo(?:_[A-Za-z0-9_]*)?|SERVO_[A-Z0-9_]*)\b",
    re.IGNORECASE,
)


def fail(message: str) -> None:
    raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_relative(value: str) -> PurePosixPath:
    if "\\" in value:
        fail(f"non-portable path: {value}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or (path.parts and ":" in path.parts[0]):
        fail(f"unsafe path: {value}")
    return path


def forbidden_path(value: str) -> bool:
    path = safe_relative(value)
    lowered = [part.lower() for part in path.parts]
    if any(part in FORBIDDEN_SEGMENTS for part in lowered):
        return True
    if any(token in path.name.lower() for token in FORBIDDEN_NAME_TOKENS):
        return True
    return any(part.upper().startswith("PRIVATE_") for part in path.parts)


def require_regular_under(root: Path, relative: str) -> Path:
    rel = safe_relative(relative)
    path = root.joinpath(*rel.parts)
    if path.is_symlink() or not path.is_file():
        fail(f"source input missing or not a regular file: {relative}")
    resolved = path.resolve()
    if root.resolve() not in resolved.parents:
        fail(f"source path escapes baseline root: {relative}")
    return path


def load_baseline_metadata(root: Path) -> tuple[dict, list[dict], list[dict]]:
    checksum_file = require_regular_under(root, "checksums.json")
    manifest_file = require_regular_under(root, "source_manifest.json")
    try:
        checksums = json.loads(checksum_file.read_text(encoding="utf-8-sig"))
        source_manifest = json.loads(manifest_file.read_text(encoding="utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"invalid baseline metadata: {exc}")
    if not isinstance(checksums, list) or not isinstance(source_manifest, dict):
        fail("baseline checksums.json/source_manifest.json schema mismatch")
    checked: set[str] = set()
    checksum_exceptions: list[dict] = []
    for row in checksums:
        rel = str(row.get("path", ""))
        safe_relative(rel)
        if rel in checked:
            fail(f"duplicate baseline checksum entry: {rel}")
        checked.add(rel)
        source = require_regular_under(root, rel)
        current_bytes = source.stat().st_size
        current_sha256 = file_sha256(source)
        if current_bytes != row.get("bytes") or current_sha256 != row.get("sha256"):
            if rel != ALLOWED_CHECKSUM_DELTA_PATH:
                fail(f"baseline checksum mismatch: {rel}")
            checksum_exceptions.append({
                "path": rel,
                "changed": True,
                "expected_bytes": row.get("bytes"),
                "expected_sha256": row.get("sha256"),
                "current_bytes": current_bytes,
                "current_sha256": current_sha256,
            })
    allowed_unhashed = {"software/test_bbox_osd.c", "tb/tb_bbox_osd.v"}
    all_files = set()
    for source in root.rglob("*"):
        if source.is_symlink():
            fail(f"symlink is not allowed in baseline: {source.relative_to(root)}")
        if source.is_file():
            rel = source.relative_to(root).as_posix()
            safe_relative(rel)
            all_files.add(rel)
    untracked = all_files - checked - {"checksums.json"}
    if untracked - allowed_unhashed:
        fail(f"unexpected unchecksummed baseline files: {sorted(untracked - allowed_unhashed)}")
    frozen = source_manifest.get("sources")
    if not isinstance(frozen, list) or not frozen:
        fail("baseline source_manifest.json has no frozen source records")
    for row in frozen:
        snapshot = str(row.get("snapshot", "")).replace("\\", "/").rsplit("/", 1)[-1]
        if not snapshot or "/" in snapshot:
            fail("invalid snapshot basename in source_manifest.json")
        source = require_regular_under(root, f"sources/{snapshot}")
        if file_sha256(source) != row.get("sha256"):
            fail(f"frozen source identity mismatch: {snapshot}")
    return source_manifest, checksums, checksum_exceptions


LEGACY_CALL = re.compile(r"\b(qr_scan_[A-Za-z0-9_]*|offline_state_[A-Za-z0-9_]*|ledger_[A-Za-z0-9_]*|app_redeem)\s*\(")


def reject_legacy_runtime_calls(payload: dict[str, bytes]) -> None:
    declaration = re.compile(
        r"^\s*(?:static\s+)?[A-Za-z_][\w\s\*]*\b"
        r"(ledger_load|ledger_save|app_redeem)\s*\([^;]*\)\s*(?:\{|;)", re.M
    )
    for name, data in payload.items():
        if not name.startswith("extensions/business/application/firmware/") or not name.endswith((".c", ".h", ".inc")):
            continue
        text = data.decode("utf-8", errors="replace")
        declarations = [match.span() for match in declaration.finditer(text)]
        for match in LEGACY_CALL.finditer(text):
            if not any(start <= match.start() < end for start, end in declarations):
                fail(f"legacy QR/points call in {name}: {match.group(1)}")
        # Display-only session points are part of the current reward UI. The
        # account/ledger persistence paths remain excluded by the checks above.


def reject_servo_music_symbols(payload: dict[str, bytes]) -> None:
    for name, data in payload.items():
        if name not in APP_SERVICE_PACKAGE_PATHS:
            continue
        text = data.decode("utf-8", errors="replace")
        match = SERVO_MUSIC_SYMBOL.search(text)
        if match:
            fail(f"servo/music feature symbol in {name}: {match.group(0)}")


def baseline_filter(relative: str) -> str | None:
    """Return None to include; otherwise return a coarse exclusion category."""
    path = safe_relative(relative)
    if forbidden_path(relative):
        return "private_or_legacy_path"
    suffix = path.suffix.lower()
    if suffix in GENERATED_SUFFIXES:
        return "generated_eda_artifact"
    if suffix in {".log", ".tmp", ".bak", ".orig", ".swp", ".pyc"}:
        return "generated_or_temporary_file"
    if suffix not in SOURCE_SUFFIXES:
        return "unsupported_file_type"
    return None


def collect_baseline(root: Path) -> tuple[dict[str, bytes], dict, dict[str, int]]:
    source_manifest, checksums, checksum_exceptions = load_baseline_metadata(root)
    payload: dict[str, bytes] = {}
    excluded: dict[str, int] = {}
    for source in sorted(root.rglob("*")):
        if source.is_symlink():
            fail(f"symlink is not allowed in baseline: {source.relative_to(root)}")
        if not source.is_file():
            continue
        rel = source.relative_to(root).as_posix()
        safe_relative(rel)
        # Keep the upstream package README under a distinct name; the delivered
        # package gets one top-level README describing both source groups.
        output_rel = "README.pre_pnr.md" if rel == "README.md" else rel
        reason = baseline_filter(rel)
        if reason:
            excluded[reason] = excluded.get(reason, 0) + 1
            continue
        output_path = f"yolo/{output_rel}"
        if forbidden_path(output_path):
            excluded["private_or_legacy_path"] = excluded.get("private_or_legacy_path", 0) + 1
            continue
        payload[output_path] = source.read_bytes()
    required = {
        "yolo/software/platform_main.c", "yolo/software/test_bbox_osd.c",
        "yolo/tb/tb_bbox_osd.v", "yolo/model/model.bin",
        "yolo/build_pre_pnr.tcl", "yolo/source_manifest.json",
        "yolo/checksums.json",
    }
    missing = required - payload.keys()
    if missing:
        fail(f"baseline source package is incomplete: {sorted(missing)}")
    return payload, {
        "name": root.name,
        "source_manifest_sha256": file_sha256(root / "source_manifest.json"),
        "checksums_sha256": file_sha256(root / "checksums.json"),
        "verified_checksum_records": len(checksums),
        "checksum_exceptions": checksum_exceptions,
        "frozen_source_records": len(source_manifest["sources"]),
        "cpu_hz": source_manifest.get("firmware", {}).get("cpu_hz"),
        "model_sha256": source_manifest.get("firmware", {}).get("model_sha256"),
    }, excluded


def collect_business(repo: Path) -> dict[str, bytes]:
    payload: dict[str, bytes] = {}
    if set(BUSINESS_FILES) & EXCLUDED_APPLICATION_PATHS:
        fail("business allowlist overlaps excluded application modules")
    missing = []
    for relative in BUSINESS_FILES:
        source = repo / relative
        if source.is_symlink():
            fail(f"business source must not be a symlink: {relative}")
        if not source.is_file():
            if relative in REQUIRED_BUSINESS_FILES:
                missing.append(relative)
            continue
        rel = Path(relative).as_posix()
        if forbidden_path(rel):
            fail(f"business allowlist includes forbidden runtime path: {rel}")
        payload[f"extensions/business/{rel}"] = source.read_bytes()
    if missing:
        fail(f"required business modules are missing: {sorted(missing)}")
    audio_dir = repo / VOICE_ASSET_DIR
    found_audio = set()
    if audio_dir.is_dir():
        for source in sorted(audio_dir.iterdir()):
            if source.is_symlink():
                fail(f"voice asset must not be a symlink: {source.name}")
            if source.is_file() and source.name.upper() in REQUIRED_AUDIO:
                rel = f"{VOICE_ASSET_DIR}/{source.name}"
                payload[f"extensions/business/{rel}"] = source.read_bytes()
                found_audio.add(source.name.upper())
    absent_audio = REQUIRED_AUDIO - found_audio
    if absent_audio:
        fail(f"required voice-feedback assets are missing: {sorted(absent_audio)}")
    reject_legacy_runtime_calls(payload)
    reject_servo_music_symbols(payload)
    return payload


def make_readme(baseline: dict) -> bytes:
    text = f"""# 简化源码交付包

本源码 ZIP 使用用户新给的 YOLO/RTL 基线 `{baseline['name']}`，包含本次识别框修改和应用扩展。原始输入与修改边界见 `extensions/business/application/docs/本次修改与验证.md`。

- `yolo/` 保存输入包里的预 PnR 源快照、模型输入、IP 源码、`platform_main.c`、`test_bbox_osd.c` 和 `tb_bbox_osd.v`。
- `extensions/business/` 保存视觉/OSD、摄像头预览、分类映射源码、按键答题与 +100 会话积分逻辑、专项测试，以及 WAV 解析/播放排空支持、I²S 发送器和四种提示音及三种音乐 WAV。
- 正确答案固定播放 `MUSIC0.WAV`，经 `audio_bclk/audio_lrclk/audio_data` 输出到外接 I²S 功放；舵机控制仍不进入包。
- 不包含二维码登录、账户持久化账本、PnR 数据库、ELF 和位流。
- 本版采用白色亮系左右分屏；右侧 640×720 使用原生实时视频中心裁剪并保留 YOLO 框。三句中文提示音已重生成；详情见 `extensions/business/application/docs/白色分屏与提示语音.md`。

输入清单与当前 `software/platform_main.c` 不同的情况会在 `manifest.json` 的 `baseline.checksum_exceptions` 中记录原始/当前字节数和 SHA-256；其他清单文件仍逐项严格校验。

本包是源码交付物，不代表完成布局布线或实板验收。静态校验只依赖 Python 标准库，不需要 RISC-V 工具链、PDS、仿真器、串口或开发板。

重要：本包仍是源码交付物，未执行布局布线、位流生成或实板验收；输入快照中的 ROM 镜像不能代表本次 C/RTL 修改已经烧录。本次已把实时分屏接入 `portable/052_yolo_camera_top.v`；应用积分与音频状态还需总线/按键/音频时钟接口适配，新顶层暂接启动默认值，不能直接烧录验收积分与音频两项功能。

## 离线静态复核

```powershell
python tools_simplified/build_source_package.py --verify <source-package.zip>
```

包内自带打包与校验脚本；静态校验无需工具链。

## 重新生成源码 ZIP

```powershell
python tools_simplified/build_source_package.py `
  --baseline-root <pre_pnr_source_20261103_002112> `
  --repo-root <board_system> `
  --out <source-package.zip>
```

脚本核对输入包中的 checksums 与 source manifest，并拒绝覆盖已有输出。`manifest.json` 记录基线身份及每个交付文件的 SHA-256；`SHA256SUMS.txt` 校验清单和全部包内文件。输入相同则 ZIP 内容可复现。
"""
    return text.encode("utf-8")


def zip_bytes(payload: dict[str, bytes]) -> bytes:
    stream = tempfile.SpooledTemporaryFile(max_size=64 * 1024 * 1024)
    with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            safe_relative(name)
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    stream.seek(0)
    result = stream.read()
    stream.close()
    return result


def package_payload(baseline: Path, repo: Path) -> dict[str, bytes]:
    yolo, baseline_info, excluded = collect_baseline(baseline)
    business = collect_business(repo)
    payload = {**yolo, **business}
    payload["README.md"] = make_readme(baseline_info)
    packager_path = Path(__file__).resolve()
    payload["tools_simplified/build_source_package.py"] = packager_path.read_bytes()
    records = [
        {"path": name, "bytes": len(data), "sha256": sha256(data)}
        for name, data in sorted(payload.items())
    ]
    manifest = {
        "format": FORMAT,
        "baseline": baseline_info,
        "toolchain_required_for_static_verify": False,
        "exclusions": excluded,
        "contents": {
            "yolo_source_files": sum(name.startswith("yolo/") for name in payload),
            "business_module_and_asset_files": sum(name.startswith("extensions/business/") for name in payload),
            "vision_osd_camera_and_classification_modules_included": True,
            "simplified_app_service_and_test_included": True,
            "voice_feedback_asset_names": sorted(REQUIRED_VOICE),
            "music_asset_names": sorted(REQUIRED_MUSIC),
            "i2s_external_amp_output_included": True,
            "servo_or_music_feature_code_included": True,
            "servo_control_included": False,
            "reward_music_included": True,
            "bright_split_layout_included": True,
            "native_live_camera_right_half_included": True,
            "board_score_audio_adapter_complete": False,
            "music_assets_included": True,
            "points_display_included": True,
            "qr_or_account_runtime_included": False,
            "build_or_pnr_artifacts_included": False,
        },
        "files": records,
    }
    payload["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()
    checksum_lines = [f"{sha256(data)}  {name}" for name, data in sorted(payload.items())]
    payload["SHA256SUMS.txt"] = ("\n".join(checksum_lines) + "\n").encode()
    return payload


def verify_package(path: Path) -> int:
    try:
        with zipfile.ZipFile(path, "r") as archive:
            if archive.testzip() is not None:
                fail("ZIP CRC check failed")
            names = archive.namelist()
            if len(names) != len(set(names)):
                fail("duplicate ZIP entry")
            for name in names:
                safe_relative(name)
                if forbidden_path(name) or PurePosixPath(name).suffix.lower() in GENERATED_SUFFIXES:
                    fail(f"forbidden package path: {name}")
            if "README.md" not in names or "manifest.json" not in names or "SHA256SUMS.txt" not in names:
                fail("README.md, manifest.json and SHA256SUMS.txt are required")
            manifest = json.loads(archive.read("manifest.json").decode("utf-8"))
            if manifest.get("format") != FORMAT:
                fail("unsupported package format")
            contents = manifest.get("contents", {})
            if (contents.get("servo_or_music_feature_code_included") is not True
                    or contents.get("music_assets_included") is not True
                    or contents.get("i2s_external_amp_output_included") is not True
                    or contents.get("points_display_included") is not True
                    or contents.get("simplified_app_service_and_test_included") is not True
                    or contents.get("voice_feedback_asset_names") != sorted(REQUIRED_VOICE)):
                fail("manifest business-module scope does not match the package contract")
            records = {row["path"]: row for row in manifest.get("files", [])}
            payload_names = set(names) - {"manifest.json", "SHA256SUMS.txt"}
            if set(records) != payload_names:
                fail("manifest file list does not match ZIP payload")
            for name, record in records.items():
                data = archive.read(name)
                if len(data) != record.get("bytes") or sha256(data) != record.get("sha256"):
                    fail(f"hash mismatch: {name}")
            embedded = {
                name: archive.read(name) for name in records
                if name.startswith("extensions/business/application/firmware/")
                and name.endswith((".c", ".h", ".inc"))
            }
            reject_legacy_runtime_calls(embedded)
            reject_servo_music_symbols({
                name: archive.read(name) for name in APP_SERVICE_PACKAGE_PATHS & set(names)
            })
            missing = REQUIRED_PACKAGE_FILES - set(names)
            if missing:
                fail(f"required source/assets missing: {sorted(missing)}")
            business_paths = {
                name for name in names if name.startswith("extensions/business/")
            }
            unexpected_business = business_paths - ALLOWED_BUSINESS_PACKAGE_PATHS
            if unexpected_business:
                fail(f"unexpected business source/assets in package: {sorted(unexpected_business)}")
            excluded_paths = {f"extensions/business/{name}" for name in EXCLUDED_APPLICATION_PATHS}
            present_excluded = excluded_paths & set(names)
            present_music = {
                name for name in names
                if name.startswith(f"extensions/business/{VOICE_ASSET_DIR}/")
                and PurePosixPath(name).name.upper() in EXCLUDED_VOICE_ASSETS
            }
            if present_excluded or present_music:
                fail(f"excluded servo/application/music items in package: {sorted(present_excluded | present_music)}")
            audio_payload = {
                name for name in names
                if name.startswith(f"extensions/business/{VOICE_ASSET_DIR}/")
            }
            unexpected_audio = audio_payload - ALLOWED_VOICE_ASSET_PATHS
            if unexpected_audio:
                fail(f"unexpected audio assets in package: {sorted(unexpected_audio)}")
            sums = archive.read("SHA256SUMS.txt").decode("utf-8").splitlines()
            expected = {}
            for line in sums:
                if "  " not in line:
                    fail("malformed SHA256SUMS.txt line")
                digest, name = line.split("  ", 1)
                safe_relative(name)
                if name in expected:
                    fail(f"duplicate SHA256SUMS entry: {name}")
                expected[name] = digest
            if set(expected) != set(names) - {"SHA256SUMS.txt"}:
                fail("SHA256SUMS.txt file list does not match ZIP")
            for name, digest in expected.items():
                if sha256(archive.read(name)) != digest:
                    fail(f"SHA256SUMS mismatch: {name}")
    except zipfile.BadZipFile as exc:
        fail(f"invalid ZIP: {exc}")
    print(f"STATIC_VERIFY_PASS files={len(records)} toolchain=not-required")
    return len(records)


def write_package(baseline: Path, repo: Path, out: Path) -> None:
    baseline = baseline.resolve()
    repo = repo.resolve()
    out = out.resolve()
    if not baseline.is_dir():
        fail(f"baseline source directory not found: {baseline}")
    if not repo.is_dir():
        fail(f"repository directory not found: {repo}")
    if out.exists():
        fail(f"output already exists: {out}")
    payload = package_payload(baseline, repo)
    archive_data = zip_bytes(payload)
    out.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(prefix=out.name + ".", suffix=".building", dir=out.parent)
    os.close(handle)
    temporary = Path(temporary_name)
    try:
        temporary.write_bytes(archive_data)
        verify_package(temporary)
        # A second existence check closes the race without replacing any file.
        if out.exists():
            fail(f"output already exists: {out}")
        os.replace(temporary, out)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"SOURCE_PACKAGE_READY {out} sha256={file_sha256(out)} bytes={out.stat().st_size}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-root", type=Path, help="incoming pre-PnR source package directory")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out", type=Path, help="new output ZIP path")
    parser.add_argument("--verify", type=Path, metavar="ZIP", help="statically verify an existing ZIP")
    args = parser.parse_args(argv)
    try:
        if args.verify:
            verify_package(args.verify.resolve())
            return 0
        if not args.baseline_root or not args.out:
            parser.error("--baseline-root and --out are required when building")
        write_package(args.baseline_root, args.repo_root, args.out)
        return 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
