import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest

from build_full import PROJECT, routed_resources, timing_gate, verify_firmware_sources


def report(omit_clock=None, bad_hold=False):
    text = "Timing analysis mode : multi corner\nDesign Summary : All Constraints Met.\n"
    clocks = ("sys_clk", "pix_clk", "cfg_clk", "clk_25M",
              "cam1_sccb", "cam2_sccb", "ddrphy_sysclk")
    for corner in ("Slow", "Fast"):
        for kind in ("Setup", "Hold", "Recovery", "Removal", "Minimum Pulse Width"):
            text += f"\n{kind} Summary({corner} Corner):\n"
            for clock in clocks:
                if clock != omit_clock:
                    failing = bad_hold and corner == "Fast" and kind == "Hold"
                    text += f" {clock} {clock} {'-0.001 0.001 1' if failing else '0.1 0 0'} 10\n"
    return text


class ResourceGate(unittest.TestCase):
    def table(self):
        return '\n'.join(f'| {label} | {used} | {available} |' for label, used, available in (
            ('Use of APM', 123, 240), ('FF', 15978, 93400), ('LUT', 20197, 46700),
            ('FF', 6093, 39800), ('LUT', 8294, 19900), ('Distributed RAM', 290, 1000),
            ('Use of DRM', 132.5, 155), ('Use of IO', 100, 300)))

    def test_both_logic_pools_are_counted(self):
        resources = routed_resources(self.table())
        self.assertEqual(resources['FF']['used'], 22071)
        self.assertEqual(resources['LUT']['used'], 28491)
        self.assertEqual(resources['LUT']['available'], 66600)
        self.assertEqual(resources['DRM']['used'], 132.5)

    def test_missing_pool_is_rejected(self):
        with self.assertRaises(ValueError):
            routed_resources(self.table().replace('| LUT | 8294 | 19900 |', ''))

    def test_capacity_is_enforced(self):
        with self.assertRaisesRegex(ValueError, 'Over-capacity'):
            routed_resources(self.table().replace('| 132.5 | 155 |', '| 156 | 155 |'))


class TimingGate(unittest.TestCase):
    def test_all_required_clock_domains_and_corners(self):
        self.assertEqual(len(timing_gate(report())), 10)

    def test_pass_banner_does_not_hide_fast_hold_failure(self):
        with self.assertRaisesRegex(ValueError, "Timing violation"):
            timing_gate(report(bad_hold=True))

    def test_unconstrained_camera_domain_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "cam2_sccb"):
            timing_gate(report(omit_clock="cam2_sccb"))


class FirmwareGate(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.frozen = Path(directory.name)
        self.cwd = self.frozen / "yolo/sources"
        self.cwd.mkdir(parents=True)
        source = PROJECT / "source"
        manifest = source / "yolo/sources/firmware-source-manifest.json"
        data = json.loads(manifest.read_text(encoding="utf8"))
        for name in data["source_hashes"]:
            relative = Path(name).relative_to("project/trash_sorting/source")
            target = self.frozen / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / relative, target)
        for name in ("firmware-source-manifest.json", "firmware.bin",
                     *(f"firmware_lane{i}.bin" for i in range(8))):
            shutil.copy2(source / "yolo/sources" / name, self.cwd / name)
        for relative in ('yolo/model/memory_map.json','yolo/model/model.bin',
                         'yolo/portable/052_yolo_camera_top.v',
                         'yolo/ipcore/pll/pll.v','yolo/ipcore/pll/pll.idf'):
            target=self.frozen/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source/relative,target)

    def test_candidate_source_and_rom_agree(self):
        verify_firmware_sources(self.frozen)

    def test_hand_cannot_be_declared_as_a_fifth_bin(self):
        path=self.cwd/'firmware-source-manifest.json'
        data=json.loads(path.read_text())
        data.update(raw_model_classes=5,hand_locator_class=4,
                    effective_output_ids=[0,1,2,3,4],single_label=True)
        data['compiler_command']=[s.replace('-DYOLO_CLASSES=4','-DYOLO_CLASSES=5') for s in data['compiler_command']]
        path.write_text(json.dumps(data),encoding='utf8')
        with self.assertRaisesRegex(ValueError,'internal locator'):
            verify_firmware_sources(self.frozen)

    def test_class_metadata_cannot_change_the_compiled_decoder(self):
        path=self.cwd/'firmware-source-manifest.json'
        data=json.loads(path.read_text())
        data['raw_model_classes']=5
        path.write_text(json.dumps(data),encoding='utf8')
        with self.assertRaisesRegex(ValueError,'Compiler/manifest'):
            verify_firmware_sources(self.frozen)

    def test_clock_change_without_firmware_rebuild_is_rejected(self):
        path = self.frozen / 'yolo/portable/052_yolo_camera_top.v'
        text = path.read_text(encoding='utf8')
        mode = re.search(r'parameter\s+AI_FAST_CLOCK\s*=\s*([012])', text)
        self.assertIsNotNone(mode)
        changed = str((int(mode[1])+1)%3)
        text = text[:mode.start(1)]+changed+text[mode.end(1):]
        path.write_text(text, encoding='utf8')
        with self.assertRaisesRegex(ValueError, 'CPU clock mismatch'):
            verify_firmware_sources(self.frozen)

    def test_stale_rom_after_c_edit_is_rejected(self):
        path = self.frozen / "yolo/software/yolo_decode.c"
        path.write_bytes(path.read_bytes() + b"\n/* later edit */\n")
        with self.assertRaisesRegex(ValueError, "not rebuilt"):
            verify_firmware_sources(self.frozen)

    def test_packed_add_flag_must_match_manifest(self):
        path=self.cwd/'firmware-source-manifest.json'
        data=json.loads(path.read_text())
        data['packed_add']=not data.get('packed_add',False)
        path.write_text(json.dumps(data),encoding='utf8')
        with self.assertRaisesRegex(ValueError,'packed ADD mismatch'):
            verify_firmware_sources(self.frozen)

    def test_changed_binary_is_rejected(self):
        path = self.cwd / "firmware.bin"
        data = bytearray(path.read_bytes())
        data[0] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "binary identity"):
            verify_firmware_sources(self.frozen)

    def test_wrong_rom_lane_content_is_rejected(self):
        path = self.cwd / "firmware_lane0.bin"
        lines = path.read_text().splitlines()
        lines[0] = f"{int(lines[0], 2) ^ 1:08b}"
        path.write_text("\n".join(lines) + "\n")
        with self.assertRaisesRegex(ValueError, "do not match"):
            verify_firmware_sources(self.frozen)

    def test_short_rom_lane_is_rejected(self):
        path = self.cwd / "firmware_lane7.bin"
        path.write_text("\n".join(path.read_text().splitlines()[:-1]) + "\n")
        with self.assertRaisesRegex(ValueError, "each cover"):
            verify_firmware_sources(self.frozen)


if __name__ == "__main__":
    unittest.main()
