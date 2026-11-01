"""Verify test builds cannot replace the board's accepted firmware artifacts."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_vexii_smoke as smoke
import run_vexii_yolo as full_graph


class FirmwareIsolation(unittest.TestCase):
    def run_case(self,fail_build=False):
        with tempfile.TemporaryDirectory(prefix="vexii_isolation_") as tmp:
            root=Path(tmp)
            cpu=root/"cpu"
            cpu.mkdir()
            (cpu/"sources.f").write_text("",encoding="ascii")
            out=root/"soc"
            out.mkdir()
            (out/"firmware_boot").mkdir()
            official=root/"gen/integration/vexii_firmware"
            official.mkdir(parents=True)
            (official/"firmware.bin").write_bytes(b"accepted 27 MHz firmware")
            (official/"manifest.json").write_bytes(b"accepted firmware manifest")
            before={p.name:p.read_bytes() for p in official.iterdir()}
            builds=[]

            def command(args,**kwargs):
                args=list(map(str,args))
                if any(Path(arg).name=="build_firmware.py" for arg in args):
                    builds.append(args)
                    folder=(Path(args[args.index("--out")+1])
                            if "--out" in args else official)
                    folder.mkdir(parents=True,exist_ok=True)
                    (folder/"firmware.bin").write_bytes(b"test UART firmware")
                    (folder/"manifest.json").write_bytes(b"test firmware manifest")
                    if fail_build:
                        raise subprocess.CalledProcessError(1,args)
                return subprocess.CompletedProcess(args,0,
                    stdout="VEXII_FIRMWARE_BOOT_PASS",stderr="")

            with patch.multiple(smoke,ROOT=root,CPU=cpu,OUT=out), \
                 patch.object(smoke,"generate"), \
                 patch.object(smoke.subprocess,"run",side_effect=command), \
                 contextlib.redirect_stdout(io.StringIO()):
                if fail_build:
                    with self.assertRaises(subprocess.CalledProcessError):
                        smoke.run(firmware=True)
                else:
                    smoke.run(firmware=True)
            after={p.name:p.read_bytes() for p in official.iterdir()}
            self.assertEqual(after,before,"A simulation overwrote the accepted board firmware")
            self.assertEqual(len(builds),1,"No shared-artifact restoration build is needed")
            self.assertIn("--out",builds[0])
            target=Path(builds[0][builds[0].index("--out")+1])
            self.assertEqual(target,out/"firmware_boot/firmware")

    def test_success_does_not_replace_board_firmware(self):
        self.run_case()

    def test_failed_build_does_not_replace_board_firmware(self):
        self.run_case(fail_build=True)


class FullGraphFirmwareIsolation(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix="yolo_firmware_isolation_")
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.run=self.root/"sim"
        self.run.mkdir()
        for name in ("cmd_full.hex","cmd_preloaded.hex","tx.log"):
            (self.run/name).write_text("00\n",encoding="ascii")
        self.official=self.root/"gen/integration/vexii_firmware"
        self.official.mkdir(parents=True)
        (self.official/"firmware.bin").write_bytes(b"accepted board firmware")
        (self.official/"manifest.json").write_text(json.dumps(dict(
            platform="vexii",cpu_hz=27000000,sim_preload=False)))
        self.before={p.name:p.read_bytes() for p in self.official.iterdir()}
        self.builds=[]

    def command(self,args,**kwargs):
        args=list(map(str,args))
        if any(Path(arg).name=="build_firmware.py" for arg in args):
            self.builds.append(args)
            folder=(Path(args[args.index("--out")+1])
                    if "--out" in args else self.official)
            folder.mkdir(parents=True,exist_ok=True)
            (folder/"firmware.bin").write_bytes(b"simulation firmware")
            (folder/"manifest.json").write_text(json.dumps(dict(
                platform="vexii",cpu_hz=100000000,sim_preload="--sim-preload" in args)))
        return subprocess.CompletedProcess(args,0,stdout="PASS",stderr="")

    def invoke(self,*args):
        with patch.multiple(full_graph,ROOT=self.root,RUN=self.run), \
             patch.object(full_graph,"compile_and_run",return_value="SIM_DONE"), \
             patch.object(full_graph.subprocess,"run",side_effect=self.command), \
             patch.object(sys,"argv",["run_vexii_yolo.py",*args]), \
             contextlib.redirect_stdout(io.StringIO()):
            full_graph.main()

    def test_normal_and_preloaded_simulations_preserve_board_firmware(self):
        for args in ((),("--preloaded",)):
            with self.subTest(args=args):
                self.builds.clear()
                self.invoke(*args)
                after={p.name:p.read_bytes() for p in self.official.iterdir()}
                self.assertEqual(after,self.before,"Full-graph simulation replaced board firmware")
                self.assertEqual(len(self.builds),1)
                self.assertIn("--out",self.builds[0])

    def test_skip_build_rejects_incompatible_private_image(self):
        private=self.run/"firmware"
        private.mkdir()
        (private/"firmware.bin").write_bytes(b"invalid configuration")
        (private/"manifest.json").write_text(json.dumps(dict(
            platform="vexii",cpu_hz=100000000,sim_preload=True)))
        with self.assertRaises(SystemExit):
            self.invoke("--skip-build")

    def test_skip_build_uses_matching_private_image(self):
        private=self.run/"firmware"
        private.mkdir()
        (private/"firmware.bin").write_bytes(b"\x5a")
        for preloaded in (False,True):
            with self.subTest(preloaded=preloaded):
                (private/"manifest.json").write_text(json.dumps(dict(
                    platform="vexii",cpu_hz=100000000,sim_preload=preloaded)))
                self.invoke("--skip-build",*(["--preloaded"] if preloaded else []))
                lane=self.run/"MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol0.bin"
                self.assertEqual(lane.read_text().splitlines()[0],"01011010")
                self.assertEqual(self.builds,[])


if __name__=="__main__":
    unittest.main()
