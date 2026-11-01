"""Run CPU numerical checks locally, without WSL or board access."""
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "sim/offline_checks/native"


def compiler():
    gcc = shutil.which("gcc")
    if gcc:
        return gcc, os.environ.copy(), False
    cl = shutil.which("cl")
    if cl:
        return cl, os.environ.copy(), True
    if os.name != "nt":
        raise RuntimeError("Install a native C compiler (gcc or MSVC)")
    vswhere = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / (
        "Microsoft Visual Studio/Installer/vswhere.exe")
    install = subprocess.check_output([
        str(vswhere), "-latest", "-products", "*",
        "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "-property", "installationPath"], text=True).strip()
    setup = Path(install) / "VC/Auxiliary/Build/vcvars64.bat"
    if not install or not setup.is_file():
        raise RuntimeError("No native MSVC toolchain found")
    # cmd.exe parses its command string itself; list2cmdline's backslash-quote
    # escaping is for C runtimes and would turn the batch path into \"...\".
    output = subprocess.check_output(
        f'cmd /d /u /c call "{setup}" >nul && set')
    env = os.environ.copy()
    for line in output.decode("utf-16-le").splitlines():
        if "=" in line and not line.startswith("="):
            key, value = line.split("=", 1)
            env[key] = value
    cl = shutil.which("cl.exe", path=env.get("Path", env.get("PATH")))
    if not cl:
        raise RuntimeError("MSVC environment did not provide cl.exe")
    return cl, env, True


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tool, env, msvc = compiler()
    cases = (
        ("test_yolo_perf", ("sw/yolo_runtime.c", "tb/test_yolo_perf.c"), False),
        ("test_yolo_runtime", ("sw/yolo_runtime.c", "tb/test_yolo_runtime.c"), False),
        ("test_yolo_decode", ("sw/yolo_runtime.c", "sw/yolo_decode.c", "tb/test_yolo_decode.c"), False),
        ("deployment_native", ("sw/yolo_runtime.c", "tb/deployment_native.c"), True),
    )
    for name, sources, full in cases:
        exe = OUT / (name + (".exe" if os.name == "nt" else ""))
        if msvc:
            command = [tool, "/nologo", "/std:c11", "/O2", "/W4", "/WX",
                       "/D_CRT_SECURE_NO_WARNINGS", "/I" + str(ROOT / "sw"),
                       "/Fe:" + str(exe)]
            if full:
                command.append("/DTEST_MAIN")
        else:
            command = [tool, "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
                       "-I" + str(ROOT / "sw"), "-o", str(exe)]
            if full:
                command.append("-DTEST_MAIN")
        command.extend(str(ROOT / p) for p in sources)
        if not msvc:
            command.append("-lm")
        subprocess.run(command, cwd=OUT, env=env, check=True)
        args = [str(exe)]
        if full:
            args.extend(str(ROOT / p) for p in (
                "gen/integration/packed/model.bin", "gen/integration/cpu_oracle.bin"))
        subprocess.run(args, cwd=OUT, env=env, check=True)
        if full:
            graph_args=args+[str(ROOT / "gen/integration/cpu_oracle.input.bin")]
            for options in ("0","15","31","63"):
                subprocess.run(graph_args+[options],cwd=OUT,env=env,check=True)
    print("NATIVE_CHECKS_PASS; scalar convolution is not RTL or board verification")


if __name__ == "__main__":
    main()
