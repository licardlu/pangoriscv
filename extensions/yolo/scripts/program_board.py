"""Program SRAM through the vendor JTAG tool and retain the hardware trace."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

import tool_paths


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--sbit",type=Path)
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--port",type=int,default=65420)
    parser.add_argument("--pds",type=Path,
                        help="含 cdt_cfg.exe 的 PDS bin 目录；默认读 PDS_BIN")
    args=parser.parse_args()
    TOOLS=tool_paths.pds_bin(args.pds)
    out=args.out.resolve()
    out.mkdir(parents=True,exist_ok=False)
    if args.sbit:
        sbit=args.sbit.resolve(strict=True)
        if sbit.suffix.lower()!=".sbit":
            raise ValueError("Only SRAM .sbit images are supported")
    trace=out/"trace.txt"
    script=[
        f"set fh [open {{{trace.as_posix()}}} w]",
        f'cfg_connect -ip 127.0.0.1 -port {args.port}',
        'puts $fh "scan: [cfg_scan_chain]"',
        'flush $fh',
        'set id [cfg_read_device_property -mode 0]',
        'puts $fh "id: $id"',
        'flush $fh',
        'if {![string equal -nocase [string trim $id] "0x00602899"] && '
        '![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}',
    ]
    if args.sbit:
        script.extend([
            f'cfg_assign_file -file {{{sbit.as_posix()}}}',
            'set result [cfg_program]',
            'puts $fh "program: $result"',
            'flush $fh',
            'if {$result != 1} {error "Programming failed"}',
            'puts $fh "after: [cfg_scan_chain]"',
        ])
    script.extend(['puts $fh "JTAG_SCRIPT_DONE"','flush $fh','close $fh'])
    tcl=out/"run.tcl"
    tcl.write_text("\n".join(script)+"\n",encoding="ascii")
    env=os.environ.copy()
    env["PANGO_JTAG_PORT"]=str(args.port)
    start=time.monotonic()
    with (out/"stdout.log").open("w") as stdout,(out/"stderr.log").open("w") as stderr:
        proc=subprocess.Popen(
            [str(TOOLS/"cdt_cfg.exe"),"-file",str(tcl),"-ip","127.0.0.1",
             "-port",str(args.port),"-work_dir",str(out)],cwd=out,env=env,
            stdout=stdout,stderr=stderr)
        try:
            while time.monotonic()-start<90:
                text=trace.read_text(errors="replace") if trace.is_file() else ""
                if "JTAG_SCRIPT_DONE" in text:
                    break
                if proc.poll() is not None:
                    raise RuntimeError("JTAG client exited before completion; inspect logs")
                time.sleep(0.2)
            else:
                raise TimeoutError("JTAG did not complete in 90 seconds; inspect logs")
        finally:
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=10)
    print(text,flush=True)
    metadata=dict(seconds=time.monotonic()-start,jtag_port=args.port,
                  programming_requested=bool(args.sbit),trace_complete=True)
    if args.sbit:
        metadata.update(sbit=str(sbit),sha256=hashlib.sha256(sbit.read_bytes()).hexdigest())
    (out/"result.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")


if __name__=="__main__":
    main()
