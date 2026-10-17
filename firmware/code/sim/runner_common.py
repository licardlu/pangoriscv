"""ModelSim helpers shared by the regression runners.

Each runner imports ``run`` and ``validate_test`` to launch vlib/vlog/vsim with a
log file and to check the TEST_PASS/TEST_FAIL pattern::

    from runner_common import run, validate_test
"""

import os
import re
import subprocess


def validate_command(returncode, text, log):
    if returncode != 0 or re.search(r"\*\*\s*(Error|Fatal)", text, re.I):
        raise RuntimeError("COMMAND_FAIL: " + str(log))


def validate_test(text, log):
    if text.count("TEST_PASS") != 1 or re.search(
        r"TEST_FAIL|Time\s*Out|TIMEOUT", text, re.I
    ):
        raise RuntimeError("TEST_FAIL_OR_NO_PASS: " + str(log))


def run(cmd, cwd, log, timeout):
    with log.open("w", encoding="utf-8") as out:
        process = subprocess.Popen(
            cmd, cwd=cwd, stdout=out, stderr=subprocess.STDOUT
        )
        try:
            returncode = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            if os.name == "nt":
                subprocess.run(
                    ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                    stdout=out, stderr=subprocess.STDOUT,
                )
            else:
                process.kill()
            process.wait()
            raise RuntimeError("TIMEOUT: " + str(log))
    text = log.read_text(encoding="utf-8", errors="replace")
    validate_command(returncode, text, log)
    return text
