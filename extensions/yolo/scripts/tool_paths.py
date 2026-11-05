"""Resolve external toolchains and upstream sources without machine-specific paths.

Priority is command line argument, then environment variable, then a generic
default.  Nothing here may contain a user name or a drive letter that only
exists on the machine the project was imported from.
"""
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _from_env(name):
    value = os.environ.get(name)
    return Path(value) if value else None


def _first_existing(candidates, probe, hint):
    for candidate in candidates:
        if candidate and (candidate / probe).is_file():
            return candidate
    raise RuntimeError(hint)


def modelsim_bin(cli=None):
    """Directory containing vlib/vlog/vsim."""
    explicit = Path(cli) if cli else _from_env("MODELSIM_BIN")
    if explicit:
        return _first_existing([explicit], "vlog.exe", f"ModelSim 目录不可用: {explicit}")
    found = shutil.which("vlog.exe") or shutil.which("vlog")
    if found:
        return Path(found).parent
    default = _from_env("MODELSIM_HOME")
    candidates = [default / "win64" if default else None,
                  Path("D:/modeltech64_10.6e/win64"),
                  Path("C:/modeltech64_10.6e/win64")]
    return _first_existing(candidates, "vlog.exe",
                           "找不到 ModelSim（vlog.exe）。设置 MODELSIM_BIN 指向 win64 目录")


def riscv_gcc_bin(cli=None):
    """Directory containing riscv-none-elf-* binaries."""
    explicit = Path(cli) if cli else _from_env("RISCV_GCC_BIN")
    if explicit:
        return _first_existing(
            [explicit], "riscv-none-elf-gcc.exe",
            f"RISC-V GCC 目录不可用: {explicit}")
    for name in ("riscv-none-elf-gcc.exe", "riscv-none-elf-gcc",
                 "riscv64-unknown-elf-gcc.exe", "riscv64-unknown-elf-gcc"):
        found = shutil.which(name)
        if found:
            return Path(found).parent
    return _first_existing(
        [Path("C:/xpack-riscv-none-elf-gcc/bin"),
         Path("C:/Program Files/xpack-riscv-none-elf-gcc/bin")],
        "riscv-none-elf-gcc.exe",
        "找不到 RISC-V GCC。设置 RISCV_GCC_BIN 指向含 riscv-none-elf-gcc 的目录")


def pds_bin(cli=None):
    """Directory containing pds_shell.exe."""
    explicit = Path(cli) if cli else _from_env("PDS_BIN")
    if explicit:
        return _first_existing([explicit], "pds_shell.exe", f"PDS 目录不可用: {explicit}")
    found = shutil.which("pds_shell.exe") or shutil.which("pds_shell")
    if found:
        return Path(found).parent
    return _first_existing(
        [Path("C:/pango/PDS_2022.2-SP6.1/bin"),
         Path("D:/pango/PDS_2022.2-SP6.1/bin")],
        "pds_shell.exe",
        "找不到 PDS。设置 PDS_BIN 指向含 pds_shell.exe 的 bin 目录")


def cpu_rtl(cli=None):
    """RISC-V CPU source checkout used to rebuild the SoC wrapper."""
    explicit = Path(cli) if cli else _from_env("CPU_RTL")
    candidate = explicit or ROOT.parents[1] / "project" / "cpu120"
    candidate = candidate.resolve()
    if not (candidate / "sources.f").is_file():
        raise RuntimeError(
            f"CPU 源码目录不可用: {candidate}（缺 sources.f）。"
            "设置环境变量 CPU_RTL 或命令行 --cpu-rtl")
    return candidate


def video_src(cli=None, required=True):
    """Upstream video template (hdmi1080p) checkout."""
    explicit = Path(cli) if cli else _from_env("VIDEO_SRC")
    candidate = explicit or ROOT.parent / "video" / "hdmi1080p"
    candidate = candidate.resolve()
    if required and not candidate.is_dir():
        raise RuntimeError(
            f"视频模板目录不可用: {candidate}。设置环境变量 VIDEO_SRC "
            "指向包含 source/rtl 与 ipcore 的 hdmi1080p 目录")
    return candidate
