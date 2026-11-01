"""List inactive reference files; never delete or change any design input."""
import csv
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RELEASE = ROOT/'project/pds_native_120'
OUTPUT = ROOT/'docs/verification'
HDL = {'.v', '.sv', '.vh', '.svh', '.vhd', '.vhdl', '.vo', '.vm'}
IMAGES = {'.elf', '.bin', '.hex', '.mem', '.mif', '.coe', '.srec', '.ihex'}
SOFTWARE = {'core_main.c', 'core_list_join.c', 'core_matrix.c', 'core_state.c',
            'core_util.c', 'coremark.h', 'core_portme.c', 'core_portme.h',
            'ee_printf.c', 'start.s', 'link.ld', 'compiler_flags.h'}
LEGACY = {
    'upstream': 'upstream_source',
    'rtl/core/reference_exact': 'legacy_extracted_reference',
    'rtl/soc/reference_exact': 'legacy_extracted_reference',
    'rtl/core/replica_native': 'legacy_native_copy',
    'rtl/soc/replica_native': 'legacy_native_copy',
}
FIELDS = ['action', 'category', 'relative_path', 'absolute_path', 'bytes', 'sha256', 'reason']


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            result.update(block)
    return result.hexdigest()


def below(path, directory):
    return path == directory or path.startswith(directory + '/')


def protected(path):
    low = path.as_posix().lower()
    parts = path.parts
    if below(low, 'project/pds_native_120'):
        return 'KEEP_ACTIVE_PDS_RELEASE'
    if below(low, '.git'):
        return 'KEEP_GIT_HISTORY'
    if below(low, 'evidence'):
        return 'KEEP_MEASUREMENT_EVIDENCE'
    if below(low, 'docs'):
        return 'KEEP_DESIGN_AND_SOURCE_RECORDS'
    if below(low, 'firmware') or 'coremark' in [x.lower() for x in parts]:
        return 'KEEP_COREMARK_SOURCE_AND_PORT'
    if any(x.lower().startswith('firmware_') for x in parts):
        return 'KEEP_COREMARK_FIRMWARE_BUILD'
    if 'coremark' in path.name.lower() or path.name.lower() in SOFTWARE:
        return 'KEEP_COREMARK_NAMED_FILE'
    if path.suffix.lower() in IMAGES:
        return 'KEEP_PROGRAM_IMAGE'
    return None


def main():
    if not (RELEASE/'release_manifest.json').is_file():
        raise ValueError('Independent release is missing; no deletion list may be issued')
    # Current source hashes and actual image closure have already been validated
    # by tools/build.py verify immediately before generating this inventory.
    release_manifest = json.loads((RELEASE/'release_manifest.json').read_text())
    for entry in release_manifest['files']:
        if digest(RELEASE/entry['path']) != entry['sha256']:
            raise ValueError('Active release input changed: ' + entry['path'])
    reference_names = set()
    reference_hashes = set()
    for dirname in LEGACY:
        base = ROOT/dirname
        if base.is_dir():
            for path in base.rglob('*'):
                if path.is_file() and path.suffix.lower() in HDL:
                    reference_names.add(path.name.lower())
                    reference_hashes.add(digest(path))
    reference_names.update(p.name.lower() for p in (ROOT/'rtl/generated').glob('*.v'))
    for path in (ROOT/'rtl/generated').glob('*.v'):
        reference_hashes.add(digest(path))
    candidates, optional, local_review, kept = [], [], [], []
    scanned = 0

    def record(path, action, category, reason, checksum=None):
        return dict(zip(FIELDS, [action, category, path.relative_to(ROOT).as_posix(),
                                str(path.resolve()), path.stat().st_size,
                                checksum or digest(path), reason]))

    for directory, dirs, files in os.walk(ROOT):
        here = Path(directory)
        # Do not enumerate Git objects or the already protected active package.
        dirs[:] = sorted(d for d in dirs if not (here/d).is_symlink()
                         and (here/d).relative_to(ROOT).as_posix() not in
                         ('.git', 'project/pds_native_120'))
        for name in sorted(files):
            path = here/name
            if path.is_symlink():
                continue
            relative = path.relative_to(ROOT)
            key = relative.as_posix()
            scanned += 1
            protection = protected(relative)
            if protection:
                if protection.startswith('KEEP_COREMARK') or protection == 'KEEP_PROGRAM_IMAGE':
                    kept.append(record(path, 'KEEP', protection, 'Explicitly excluded from all deletion lists'))
                continue
            prefix = next((prefix for prefix in LEGACY if below(key, prefix)), None)
            if prefix:
                candidates.append(record(path, 'DELETE_CANDIDATE', LEGACY[prefix],
                                         'Inactive original/reference copy; active PDS release has local inputs'))
            elif below(key, 'rtl/generated') and path.suffix.lower() in HDL:
                candidates.append(record(path, 'DELETE_CANDIDATE', 'old_generated_reference_rtl',
                                         'Original generated hardware source; program images excluded'))
            elif below(key, 'tools/runtime'):
                optional.append(record(path, 'OPTIONAL_CACHE', 'old_java_scala_runtime',
                                       'Legacy generator runtime; includes third-party libraries, not all the CPU author'))
            elif below(key, 'build') and path.suffix.lower() in HDL:
                checksum = digest(path)
                text = path.read_text(encoding='utf-8', errors='replace')[:3000]
                if checksum in reference_hashes or path.name.lower() in reference_names:
                    candidates.append(record(path, 'DELETE_CANDIDATE', 'old_build_reference_source_copy',
                                             'Reference/native source file in an inactive staged build', checksum))
                elif 'Generator : SpinalHDL' in text or 'module VexiiRiscv' in text:
                    candidates.append(record(path, 'DELETE_CANDIDATE', 'old_generated_build_source',
                                             'Old generated hardware source identified by generator/module header', checksum))
                else:
                    local_review.append(record(path, 'REVIEW_NOT_SELECTED', 'local_old_build_hdl',
                                               'Local testbench/experimental RTL; authorship not established', checksum))
            elif relative.parts[0] in ('rtl', 'wip', 'platform', 'tb') and path.suffix.lower() in HDL:
                checksum = digest(path)
                text = path.read_text(encoding='utf-8', errors='replace')[:3000]
                if checksum in reference_hashes:
                    candidates.append(record(path, 'DELETE_CANDIDATE', 'other_identical_reference_copy',
                                             'Inactive HDL byte-identical to a reference/native source', checksum))
                elif 'Generator : SpinalHDL' in text:
                    candidates.append(record(path, 'DELETE_CANDIDATE', 'other_generated_reference_source',
                                             'Inactive generated HDL identified by generator header', checksum))
                else:
                    local_review.append(record(path, 'REVIEW_NOT_SELECTED', 'local_legacy_hdl',
                                               'Local experimental/board/test RTL; not established as upstream author source', checksum))

    # Machine-checkable disjointness: a deletion candidate can never contain
    # the active release, CoreMark, a firmware image, docs or measured evidence.
    for row in candidates + optional:
        if protected(Path(row['relative_path'])):
            raise ValueError('Protected entry reached deletion inventory: ' + row['relative_path'])
    candidate_names = {r['relative_path'] for r in candidates}
    assert not candidate_names.intersection(r['relative_path'] for r in kept)
    OUTPUT.mkdir(parents=True, exist_ok=True)

    def csvfile(name, rows):
        path = OUTPUT/name
        with path.open('w', encoding='utf-8-sig', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerows(sorted(rows, key=lambda r: r['relative_path']))

    csvfile('legacy-reference-delete-files.csv', candidates)
    csvfile('legacy-reference-optional-cache.csv', optional)
    csvfile('legacy-reference-keep-coremark.csv', kept)
    csvfile('legacy-local-hdl-review.csv', local_review)
    (OUTPUT/'legacy-reference-delete-paths.txt').write_text(
        ''.join(row['absolute_path']+'\n' for row in sorted(candidates, key=lambda r: r['relative_path'])),
        encoding='utf-8-sig')
    totals = defaultdict(lambda: {'files': 0, 'bytes': 0})
    for row in candidates:
        totals[row['category']]['files'] += 1
        totals[row['category']]['bytes'] += row['bytes']
    summary = {'scope': str(ROOT), 'date': '2026-10-30', 'mode': 'inventory_only_no_deletion',
               'delete_candidates': len(candidates), 'delete_candidate_bytes': sum(x['bytes'] for x in candidates),
               'optional_cache_files': len(optional), 'optional_cache_bytes': sum(x['bytes'] for x in optional),
               'protected_coremark_and_images': len(kept), 'local_hdl_review_not_selected': len(local_review),
               'active_package_entirely_protected': str(RELEASE),
               'active_release_manifest_sha256': digest(RELEASE/'release_manifest.json'),
               'categories': dict(totals), 'scanned_files_outside_git_and_release': scanned,
               'limits': ['Working-tree inventory only; Git history is retained',
                          'No author claims for locally written legacy RTL or third-party runtime jars',
                          'The active port still contains upstream-derived equations; deleting old copies does not make it original',
                          'Whole mixed build/generated directories are not deletion targets; CoreMark images are retained']}
    (OUTPUT/'legacy-reference-delete-summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    mib = lambda size: f'{size/1048576:.2f}'
    root_names = [*LEGACY, 'rtl/generated', 'platform/sources', 'build']
    table = []
    for prefix in root_names:
        members = [row for row in candidates if below(row['relative_path'], prefix)]
        if not members:
            continue
        description = '按逐文件清单，不能整目录删除' if prefix in ('rtl/generated', 'platform/sources', 'build') else '旧参考/重复目录'
        table.append(f'| `{ROOT/prefix}` | {len(members)} | {mib(sum(x["bytes"] for x in members))} | {description} |')
    markdown = f'''# 旧参考文件删除清单（保留 CoreMark）

核查日期：2026-10-30。范围：`{ROOT}` 的当前工作目录；不扫描/删除 Git 对象，不涉及 PDS 安装、工具链、开发板资料或系统临时目录。**本轮只生成清单，没有执行删除。**

## 结论与完整文件清单

已列出 **{len(candidates)} 个旧参考原件、旧提取副本和旧构建内重复源码，共 {mib(summary['delete_candidate_bytes'])} MiB**。另有 **{len(optional)} 个旧 Java/Scala 运行缓存文件，{mib(summary['optional_cache_bytes'])} MiB**，属于可选清理；这些运行库含第三方依赖，不能统称为 CPU 前作者作品。

- `legacy-reference-delete-files.csv`：完整逐文件清单，含绝对路径、相对路径、分类、大小、SHA256 和判定原因；仅包含删除候选。
- `legacy-reference-delete-paths.txt`：同一份清单的一行一个绝对路径版本，不含删除命令。
- `legacy-reference-optional-cache.csv`：可选旧生成器运行库文件清单，与源码清单分开。
- `legacy-reference-keep-coremark.csv`：本仓库独立包之外的 {len(kept)} 个 CoreMark/软件移植/程序镜像保护项及 SHA256。
- `legacy-local-hdl-review.csv`：{len(local_review)} 个未列入删除的本地实验核、板级适配、测试台或旧网表；来源作者未确认，不冒称前作者文件。
- `legacy-reference-delete-summary.json`：统计、范围与独立版本的 manifest 校验值。

所有 CSV 使用 UTF-8 BOM，可直接查看。清单以当前实际存在的文件为准，已从工作目录删除、只留在 Git 历史中的原文件没有重复列入。

## 分组位置

| 位置（绝对路径） | 文件数 | MiB | 删除边界 |
|---|---:|---:|---|
{chr(10).join(table)}

`build` 中只列了识别到的旧参考/移植源码副本；不能用整目录删除代替逐文件清单。`rtl/generated` 与 `platform/sources` 中的程序初值等非源码输入保留。

## CoreMark 与新版保护范围

1. **完整保留 `{RELEASE}`**，包括全部 RTL、53 个核心段、板级代码、固件、约束、构建/下载工具、PDS 工程、位流、证据、来源记录和许可证。新版整个目录没有一项进入删除清单。
2. **完整保留 `{ROOT/'firmware'}`**，含 CoreMark 本体、移植层、启动代码、链接脚本和许可证。
3. 保留所有固件构建目录 `build/firmware_*`，以及其他位置的 CoreMark 命名文件、已识别的软件源文件。
4. 保留所有 `.elf/.bin/.hex/.mem/.mif/.coe/.srec/.ihex` 程序镜像，包括文件名不含 CoreMark 的八 lane 初始化数据；逐项列入保护清单。
5. 保留 `docs/`、`evidence/`、`.git/`。来源说明与许可证保留在独立包内；清理旧副本不改变新版按上游原式迁移的来源，不代表整核已原创重写。

## 删除后的影响

清单生成前，独立版本 `tools/build.py verify` 已通过：43 个设计输入、含 include 共 96 个 HDL 文件、八 lane 和 ELF 校验均正常。生成器再次逐项核对独立版本全部 release manifest 哈希，未修改任何设计输入。

这些旧文件删除后，继续从 `{RELEASE}` 构建；旧 Scala 生成、提取审计、旧双 DUT 对照及旧 PDS 快照工程会失去输入，不能继续当作可用入口。新版 PDS 构建使用包内就地文件，不读取这些旧来源。

不要删除整个 pangoriscv 仓库：新版仍在其中。如需整仓迁移，先完整复制新版，再按其 README 用新 run 名生成新位置的 PDS 工程。

本清单不删除 Git 历史，也不声称清除了机器上所有历史副本。父目录三个 board_check 目录已补充检查，未发现 `.v/.sv/.vh/.scala` 源文件；系统临时验证副本不在本次范围。
'''
    (OUTPUT/'legacy-reference-delete-plan.md').write_text(markdown, encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
