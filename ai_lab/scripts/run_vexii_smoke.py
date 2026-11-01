"""Execute actual Vexii CPU instructions through the generated MMIO boundary."""
from pathlib import Path
import subprocess
import argparse
from generate_vexii_soc import ROOT,CPU,OUT,generate

TOOLS=Path(r"E:\donwload\win64")
GCC=Path(r"C:\Users\lenovo\WorkBuddy\2026-10-27-00-18-16\toolchain\xpack-riscv-none-elf-gcc-15.2.0-1\bin")
FAST_TEST_UART_HZ=1_000_000


def run(accelerator=False,firmware=False):
    accelerator=accelerator or firmware
    generate()
    out=OUT/("firmware_boot" if firmware else "cpu_acc" if accelerator else "cpu_smoke")
    out.mkdir(exist_ok=True)
    prefix=str(GCC/"riscv-none-elf-")
    commands=[
        [prefix+"gcc.exe","-march=rv32im","-mabi=ilp32","-nostdlib",
         "-Ttext=0x80000000","-Wl,-e,_start",
         str(ROOT/("sw/vexii_acc_smoke.S" if accelerator else "sw/vexii_mmio_smoke.S")),
         "-o",str(out/"smoke.elf")],
        [prefix+"objcopy.exe","-O","binary",str(out/"smoke.elf"),str(out/"smoke.bin")]]
    for cmd in commands:
        subprocess.run(cmd,cwd=out,check=True,capture_output=True)
    if firmware:
        import sys
        import struct
        import zlib
        from board_loader import request
        firmware_out=out/"firmware"
        subprocess.run([sys.executable,str(ROOT/"scripts/build_firmware.py"),
                        "--platform","vexii","--cpu-hz",str(FAST_TEST_UART_HZ),
                        "--out",str(firmware_out)],check=True)
        data=(firmware_out/"firmware.bin").read_bytes()
        base=0x01000000
        words=[0x1122334455667700+i for i in range(24)]
        req=bytearray()
        request_lengths=[]
        for blk in range(3):
            frame=request(1,base+blk*0x40,
                          b"".join(struct.pack("<Q",w) for w in words[blk*8:blk*8+8]))
            req.extend(frame)
            request_lengths.append(len(frame))
        for index in range(len(words)):
            frame=request(2,base+index*8)
            req.extend(frame)
            request_lengths.append(len(frame))
        def rep(payload):
            head=struct.pack("<4sBHB",b"YAR1",0,len(payload),0)
            body=head+payload
            return body+struct.pack("<I",zlib.crc32(body))
        response=b"".join(rep(b"") for _ in range(3))
        for word in words:
            response+=rep(struct.pack("<Q",word))
        for name,values in (("request.hex",req),
                            ("request_frames.hex",request_lengths),
                            ("reply.hex",response)):
            (out/name).write_text("".join(f"{b:02x}\n" for b in values))
    else:
        data=(out/"smoke.bin").read_bytes()
    if len(data)>65536: raise ValueError("Smoke firmware exceeds RAM")
    data=data.ljust(65536,b"\0")
    for lane in range(8):
        (out/f"MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin").write_text(
            "".join(f"{value:08b}\n" for value in data[lane::8]),encoding="ascii")
    sources=[CPU/line for line in (CPU/"sources.f").read_text().splitlines()
             if line and "MicroSoc.v" not in line and "rtl/board/" not in line]
    # Compile the generated UART with the defined empty-read patch instead of
    # the vendor copy; the rest of the CPU tree is used verbatim.
    sources=[OUT/"TilelinkUartCtrl.v" if p.name=="TilelinkUartCtrl.v" else p
             for p in sources]
    top="tb_vexii_acc_smoke" if accelerator else "tb_vexii_cpu_smoke"
    extra=([ROOT/"rtl"/name for name in
            ("conv_engine_axil.v","conv_band_rt.v","mac_array.v")] if accelerator else [])
    commands=[
        [TOOLS/"vlib.exe","work"],
        [TOOLS/"vlog.exe","-sv",f"+incdir+{CPU/'rtl/core'}",
         *(["+define+FIRMWARE_BOOT","+define+FAST_UART"] if firmware else []),
         OUT/"vexii_ai_soc.v",ROOT/"rtl/tlul_to_axil.v",
         ROOT/"tb"/(top+".v"),*extra,*sources],
        [TOOLS/"vsim.exe","-c","-quiet",top,"-do",
         "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"]]
    for i,cmd in enumerate(commands):
        result=subprocess.run([str(x) for x in cmd],cwd=out,capture_output=True,
                              text=True,errors="replace",timeout=900)
        text=result.stdout+result.stderr
        (out/f"{i}.log").write_text(text,encoding="utf-8")
        if result.returncode or "** Error" in text or "** Fatal" in text:
            raise RuntimeError(text[-5000:])
    marker=("VEXII_FIRMWARE_BOOT_PASS" if firmware else
            "VEXII_CPU_ACC_PASS" if accelerator else "VEXII_CPU_MMIO_PASS")
    if marker not in text: raise RuntimeError(text[-5000:])
    print(next(line for line in text.splitlines() if marker in line))


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--accelerator",action="store_true")
    parser.add_argument("--firmware",action="store_true")
    args=parser.parse_args()
    run(args.accelerator,args.firmware)
