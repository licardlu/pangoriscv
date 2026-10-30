"""Audit remaining legacy references without changing attribution or evidence."""
import csv
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
RELEASE = ROOT/'project/pds_native_120'
OUT = ROOT/'docs/verification'
ENTRY_POINTS = {
    'scripts/package_release.py': 'tools/runtime/classpath.json',
    'scripts/check-board-rtl.py': 'rtl/generated/MicroSoc.v',
    'scripts/rebuild.ps1': 'scripts/build.py generate',
    'platform/build.tcl': 'rtl generated MicroSoc.v',
    'platform/open_project.tcl': 'rtl/generated/MicroSoc.v',
    'project/core_exact/build.tcl': 'tools/core_replica/run_exact.py',
    'tools/core_replica/extract_exact.py': 'rtl/core/reference_exact/manifest.json',
    'tools/core_replica/extract_shifters.py': 'from extract_exact import',
    'tools/core_replica/run_exact.py': 'from extract_exact import',
    'tools/core_replica/collect_exact.py': 'from extract_exact import',
    'tools/core_replica/program_exact.ps1': 'build/core_exact/',
    'tools/core_replica/test_source_guards.py': 'import extract_exact',
    'tools/core_replica/export_standalone.py': 'build/core_exact/native-pds-001',
}
OLD_RUNS = ['board120', 'ref_parity_pds/run-001', 'core_exact/pds-002', 'core_exact/native-pds-001']
MATCH = re.compile(r'VexiiRiscv|SpinalHDL|reference_exact|upstream[/\\]Vexii|pango_vexii', re.I)
TEXT = {'.py','.ps1','.tcl','.v','.sv','.vh','.svh','.vm','.vo','.md','.txt','.json','.csv','.f','.fdc','.pcf','.pds'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    # All proposed removals are concrete inactive files. Never select a path by
    # a copyright/author-name match, and never strip a notice from a retained file.
    candidates = []
    for relative, marker in ENTRY_POINTS.items():
        path = ROOT/relative
        if path.is_file():
            if marker not in path.read_text(encoding='utf-8', errors='replace'):
                raise ValueError('Legacy marker differs; manual review required: '+relative)
            candidates.append((path, 'retired_reference_entry', 'Obsolete entry reads inputs already removed; standalone replacement exists'))
            if path.suffix == '.py':
                for cached in sorted((path.parent/'__pycache__').glob(path.stem+'.*.pyc')):
                    candidates.append((cached, 'retired_entry_bytecode', 'Bytecode of the same retired entry point'))
    for run in OLD_RUNS:
        path = ROOT/'build'/run/'synthesize/pango_vexii_top_syn.vm'
        if path.is_file():
            head = path.read_text(encoding='utf-8', errors='replace')[:3000]
            if '// Generated (version 2022.2-SP6.1' not in head:
                raise ValueError('Unexpected old netlist header: '+str(path))
            candidates.append((path, 'inactive_reference_netlist', 'Old PDS generated netlist; current release has its own proven implementation'))
    rows = []
    for path, category, reason in candidates:
        path = path.resolve()
        relative = path.relative_to(ROOT).as_posix()
        if path.is_relative_to(RELEASE) or 'coremark' in relative.lower() or relative.startswith(('firmware/','docs/','evidence/','.git/')):
            raise ValueError('Protected removal candidate: '+relative)
        rows.append({'relative_path':relative, 'absolute_path':str(path), 'category':category,
                     'bytes':path.stat().st_size, 'sha256':sha(path), 'reason':reason})
    if len({r['relative_path'] for r in rows}) != len(rows):
        raise ValueError('Duplicate candidate')
    fields = ['relative_path','absolute_path','category','bytes','sha256','reason']
    with (OUT/'remaining-legacy-delete-files.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=fields);writer.writeheader();writer.writerows(rows)

    hits = []
    for directory, dirs, files in os.walk(ROOT):
        base = Path(directory)
        dirs[:] = [d for d in dirs if not (base/d).is_symlink() and
                   d != '__pycache__' and (base/d).relative_to(ROOT).as_posix() != '.git']
        for name in files:
            path = base/name
            if path.is_symlink() or path.suffix.lower() not in TEXT:
                continue
            text = path.read_text(encoding='utf-8',errors='replace')
            if not MATCH.search(text):
                continue
            relative=path.relative_to(ROOT).as_posix()
            if relative.startswith('project/pds_native_120/'):
                category='KEEP_ACTIVE_PORT_AND_NOTICES'
            elif relative.startswith('firmware/') or 'coremark' in relative.lower():
                category='KEEP_COREMARK'
            elif relative.startswith(('docs/','evidence/','.workbuddy/')):
                category='KEEP_TRUE_HISTORY_AND_EVIDENCE'
            elif relative in {r['relative_path'] for r in rows}:
                category='NEW_REDUNDANT_REMOVAL'
            elif relative == 'scripts/build.py':
                category='KEEP_MIXED_FIRMWARE_BUILDER'
            else:
                category='KEEP_OR_REVIEW_NOT_PROVEN_AUTHOR_SOURCE'
            hits.append({'relative_path':relative,'category':category})
    with (OUT/'remaining-legacy-keyword-audit.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=['relative_path','category']);writer.writeheader();writer.writerows(hits)
    summary={'status':'AUDITED_NOT_YET_EXECUTED','date':'2026-10-30','new_removal_files':len(rows),
             'new_removal_bytes':sum(r['bytes'] for r in rows),
             'categories':dict(Counter(r['category'] for r in rows)),
             'keyword_hit_files':len(hits),'keyword_categories':dict(Counter(r['category'] for r in hits)),
             'upstream_directory_currently_exists':(ROOT/'upstream').exists(),
             'protected_simulation_libraries':'Prior automatic-review rejection: no deletion attempted and no alternate method used',
             'protected_scope':['entire active PDS release','CoreMark and firmware','licenses and provenance',
                                'docs and evidence','Git history','previously blocked deletion targets'],
             'attribution':'Current core remains an upstream-derived port; removing old copies does not make it an original rewrite'}
    (OUT/'remaining-legacy-audit.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    paths='\n'.join('- `'+r['relative_path']+'` — '+r['category'] for r in rows)
    content=f'''# 旧参考残留复核

日期：2026-10-30。仅清理确定已失效的旧入口、其 Python 字节码及旧参考 PDS 网表。没有按作者名字、注释或关键字直接删除文件。

## 新发现的可清理文件

{len(rows)} 个，{sum(r['bytes'] for r in rows)/1048576:.2f} MiB。逐文件 SHA256 见 remaining-legacy-delete-files.csv；执行结果另记 remaining-legacy-cleanup-result.json。

{paths}

## 保留项与边界

- 新版 project/pds_native_120 整包、CoreMark、全部程序镜像不动。
- 新版仍是参考原式移植；保留许可证、作者/生成器说明、来源映射和真实历史，不做改名伪装或删改归属。
- .git、docs、evidence、个人工具记忆不删除，也不改写旧实测结果。
- scripts/build.py 同时含 CoreMark 固件构建功能，保留整个文件；其中旧 Scala/参考实现路径已经失效，不能仅为删关键字而破坏固件工具。
- 本地 V1/V2 实验代码及通用 PLL/reset/测试台不根据出现 VexiiRiscv 字样判定为前作者源码，继续保留。
- 旧 ModelSim 编译库清理曾被自动审批拒绝，本轮不重试，也不改为逐文件或其他工具绕过。此前 upstream 空目录删除也不重试；本次只观察其目前存在状态。
- 关键字扫描结果是位置索引，不是作者归属结论，见 remaining-legacy-keyword-audit.csv。

不能据此声称整个项目里完全没有上游实现或历史痕迹。当前目标是保留可复现的独立 PDS 版本并清掉无用副本，原计划的其余语义模块化、ILA 和最终 STA 仍另列。
'''
    (OUT/'remaining-legacy-audit.md').write_text(content,encoding='utf-8')
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    main()
