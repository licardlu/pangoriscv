"""Program SRAM through the vendor JTAG tool and retain the hardware trace."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
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
        # cdt_cfg connects before executing -file. Do not reconnect an open
        # cable; always release it explicitly before the GUI process exits.
        'set failed [catch {',
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
    script.extend([
        'set status [cfg_read_device_property -mode 3]',
        'puts $fh "status: $status"',
        'flush $fh',
    ])
    if args.sbit:
        script.extend([
            # PG2L100H: DONE, global output/clock/write enables and global
            # reset release must all be set. A successful transfer alone is
            # not evidence that the loaded circuit is running.
            'if {[scan $status %x status_value] != 1 || '
            '($status_value & 0x0007d000) != 0x0007d000 || '
            '($status_value & 0x00000007) != 0} '
            '{error "FPGA configuration is not active or has configuration errors"}',
            'after 5000',
            'set status [cfg_read_device_property -mode 3]',
            'puts $fh "status_after_5s: $status"',
            'flush $fh',
            'if {[scan $status %x status_value] != 1 || '
            '($status_value & 0x0007d000) != 0x0007d000 || '
            '($status_value & 0x00000007) != 0} '
            '{error "FPGA configuration did not remain active"}',
        ])
    script.extend([
        '} detail]',
        'set release_failed [catch {cfg_disconnect} release_detail]',
        'puts $fh "disconnect: $release_detail"',
        'if {$release_failed || $release_detail != 1} '
        '{set failed 1; append detail "; JTAG disconnect failed: $release_detail"}',
        'if {$failed} {puts $fh "JTAG_SCRIPT_FAILED: $detail"} '
        'else {puts $fh "JTAG_SCRIPT_DONE"}',
        'flush $fh', 'close $fh',
    ])
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
                if "JTAG_SCRIPT_FAILED" in text:
                    raise RuntimeError(text)
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
    statuses = re.findall(r"^status(?:_after_5s)?:\s*([0-9a-fA-F]+)\s*$", text, re.M)
    metadata=dict(seconds=time.monotonic()-start,jtag_port=args.port,
                  programming_requested=bool(args.sbit),trace_complete=True,
                  configuration_status_hex=statuses,
                  configuration_active_verified=bool(args.sbit),
                  physical_motion_verified=False,
                  cable_disconnected=True)
    if args.sbit:
        metadata.update(sbit=str(sbit),sha256=hashlib.sha256(sbit.read_bytes()).hexdigest())
    (out/"result.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")


if __name__=="__main__":
    main()
