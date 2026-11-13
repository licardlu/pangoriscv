"""Host-only restoration protocol regression; never accesses real hardware."""
import hashlib
import json
from pathlib import Path
import struct
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import restore_full_board as restore


class RestoreStartup(unittest.TestCase):
    def run_restore(self, camera_frames, measured=0, fail_start=False, probes=0, support_probe=True):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / 'release'
            (release / 'model').mkdir(parents=True)
            (release / 'model/model.bin').write_bytes(b'test-model')
            (release / 'yolo_camera_top.sbit').write_bytes(b'test-bit')
            (release / 'manifest.json').write_text(json.dumps(dict(
                bitstream_sha256=hashlib.sha256(b'test-bit').hexdigest(),
                model_sha256=hashlib.sha256(b'test-model').hexdigest(),
                timing_pass=True, peripheral_test_mode=0,
                servo_reversed_mask='1111', raw_model_classes=4,cpu_hz=54000000,
                camera_probe_command=12 if support_probe else None)), encoding='utf8')
            model = dict(classes=['kitchen', 'recyclable', 'hazardous', 'other'],
                         blob_base=0, blob_crc32=1)
            model['tensors'] = [dict(address=0)]
            fake = SimpleNamespace(
                NAMES=model['classes'],
                load_deployment=Mock(return_value=(model, b'test-model')),
                write_image=Mock(), parse_detections=Mock(side_effect=camera_frames + [[]]),
                read_exact=Mock(side_effect=[b'YAI1\0\0\0\0', b'\0' * 4]),
                parse_reply=Mock(return_value=b'frame'))

            def transact(port, command, *args, **kwargs):
                if command == 9:
                    return struct.pack('<I', 63)
                if command == 7 and fail_start:
                    raise RuntimeError('start acknowledgement failed')
                return b''

            fake.transact = Mock(side_effect=transact)
            spec = SimpleNamespace(loader=SimpleNamespace(exec_module=Mock()))
            argv = ['restore', '--port', 'FAKE', '--pds', str(root),
                    '--out', str(root / 'result'), '--release-dir', str(release),
                    '--measure-frames', str(measured)]
            if probes:
                argv += ['--probe-frames',str(probes),'--collect-profile']
            profiler=SimpleNamespace(parse_profile=Mock(return_value=dict(
                cpu_hz=54000000,flags=63,stages=dict(capture=.001,forward=.001,decode=.001,display=0),
                operators=[dict(cycles=54)])))
            with patch.object(restore.sys, 'argv', argv), \
                 patch.dict(restore.sys.modules, {'board_perf':profiler}), \
                 patch.object(restore.importlib.util, 'spec_from_file_location', return_value=spec), \
                 patch.object(restore.importlib.util, 'module_from_spec', return_value=fake), \
                 patch('serial.Serial'), patch.object(restore.subprocess, 'run'):
                if fail_start:
                    with self.assertRaisesRegex(RuntimeError, 'acknowledgement'):
                        restore.main()
                else:
                    restore.main()
            state = json.loads((root / 'result/result.json').read_text(encoding='utf8'))
            return state, fake

    def test_pending_quiz_does_not_wait_for_next_frame(self):
        state, fake = self.run_restore([[dict(category='recyclable')]])
        self.assertTrue(state['autonomous_started'])
        self.assertTrue(state['first_question_pending'])
        self.assertFalse(state['autonomous_frame_received'])
        self.assertIn('completed_utc', state)
        fake.read_exact.assert_not_called()

    def test_empty_scene_checks_first_autonomous_frame(self):
        state, fake = self.run_restore([[]])
        self.assertTrue(state['autonomous_frame_received'])
        self.assertEqual(fake.read_exact.call_count, 2)

    def test_later_measured_target_also_blocks_next_frame(self):
        state, fake = self.run_restore([[], [dict(category='other')]], measured=3)
        self.assertTrue(state['first_question_pending'])
        self.assertEqual(len(state['camera_timing_seconds']), 1)
        self.assertIn('locked', state['camera_timing_stop_reason'])
        fake.read_exact.assert_not_called()

    def test_first_camera_target_skips_requested_timing(self):
        state, fake = self.run_restore([[dict(category='other')]], measured=3)
        self.assertEqual(state['camera_timing_seconds'], [])
        self.assertNotIn('camera_timing_mean_seconds', state)
        self.assertTrue(state['first_question_pending'])
        self.assertEqual([c.args[1] for c in fake.transact.call_args_list].count(6), 1)

    def test_failed_start_is_not_reported_as_running(self):
        state, fake = self.run_restore([[dict(category='hazardous')]], fail_start=True)
        self.assertFalse(state['autonomous_started'])
        self.assertIn('acknowledgement', state['error'])
        fake.read_exact.assert_not_called()

    def test_probe_targets_do_not_lock_the_real_quiz(self):
        selected=[dict(category='recyclable')]
        state,fake=self.run_restore([selected,selected,selected,[]],probes=2)
        self.assertEqual(len(state['camera_probe_frames']),2)
        self.assertIn('NO display/quiz commit',state['camera_probe_scope'])
        self.assertTrue(state['autonomous_frame_received'])
        self.assertNotIn('first_question_pending',state)
        self.assertEqual([c.args[1] for c in fake.transact.call_args_list].count(12),3)

    def test_real_target_after_probes_still_locks_quiz(self):
        state,fake=self.run_restore([[],[],[dict(category='other')]],probes=1)
        self.assertEqual(len(state['camera_probe_frames']),1)
        self.assertTrue(state['first_question_pending'])
        fake.read_exact.assert_not_called()

    def test_old_release_rejects_probes_before_programming(self):
        with self.assertRaisesRegex(ValueError,'does not support'):
            self.run_restore([[]],probes=1,support_probe=False)


if __name__ == '__main__':
    unittest.main()
