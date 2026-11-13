"""Exercise the real generated Tcl without touching a JTAG cable."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import tkinter
import unittest
from unittest.mock import patch

import program_board


class ProgramBoard(unittest.TestCase):
    def run_case(self, statuses, program_result=1, disconnect_result=1):
        with tempfile.TemporaryDirectory(prefix="servo_program_test_") as tmp:
            root = Path(tmp)
            sbit = root / "test.sbit"
            sbit.write_bytes(b"test image")
            out = root / "evidence"
            calls = []
            status_iter = iter(statuses)
            tcl = tkinter.Tcl()
            tcl.eval("rename after real_after; proc after {args} {}")
            tcl.eval("proc cfg_scan_chain {} {return 1}")
            tcl.eval("proc cfg_assign_file {args} {return 1}")
            tcl.eval("proc cfg_program {} {return " + str(program_result) + "}")
            tcl.createcommand("cfg_read_device_property", lambda *args:
                              "00602899" if args == ("-mode", "0")
                              else next(status_iter))

            def disconnect():
                calls.append("disconnect")
                return disconnect_result

            tcl.createcommand("cfg_disconnect", disconnect)

            class Client:
                def __init__(self, command, **kwargs):
                    script = Path(command[command.index("-file") + 1])
                    tcl.eval(script.read_text())

                def poll(self):
                    return None

                def terminate(self):
                    calls.append("terminate")

                def wait(self, timeout):
                    return 0

            argv = ["program_board.py", "--sbit", str(sbit), "--out", str(out)]
            error = None
            with patch("sys.argv", argv), \
                    patch.object(program_board.tool_paths, "pds_bin", return_value=root), \
                    patch.object(program_board.subprocess, "Popen", Client), \
                    contextlib.redirect_stdout(io.StringIO()):
                try:
                    program_board.main()
                except RuntimeError as exc:
                    error = str(exc)
            self.assertEqual(calls, ["disconnect", "terminate"])
            result = json.loads((out / "result.json").read_text()) \
                if (out / "result.json").exists() else None
            return error, result, (out / "trace.txt").read_text()

    def test_active_configuration_survives_delay(self):
        error, result, trace = self.run_case(["081ffca0", "081ffca0"])
        self.assertIsNone(error)
        self.assertTrue(result["configuration_active_verified"])
        self.assertFalse(result["physical_motion_verified"])
        self.assertEqual(result["configuration_status_hex"], ["081ffca0"] * 2)
        self.assertIn("JTAG_SCRIPT_DONE", trace)

    def test_transfer_success_with_inactive_fpga_is_failure(self):
        error, result, trace = self.run_case(["00180c80"])
        self.assertIn("configuration is not active", error)
        self.assertIsNone(result)
        self.assertNotIn("JTAG_SCRIPT_DONE", trace)

    def test_configuration_lost_after_delay_is_failure(self):
        error, result, _ = self.run_case(["081ffca0", "00180c80"])
        self.assertIn("did not remain active", error)
        self.assertIsNone(result)

    def test_transfer_failure_still_disconnects(self):
        error, result, _ = self.run_case([], program_result=0)
        self.assertIn("Programming failed", error)
        self.assertIsNone(result)

    def test_disconnect_failure_is_not_reported_as_success(self):
        error, result, _ = self.run_case(["081ffca0"] * 2, disconnect_result=0)
        self.assertIn("disconnect failed", error)
        self.assertIsNone(result)


if __name__ == "__main__":
    unittest.main()
