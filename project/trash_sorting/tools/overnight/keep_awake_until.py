"""Hold a Windows system-awake request until an explicit UTC deadline.

Does not request display power or change persistent power settings. A successful
API call confirms request registration, not immunity to lid closure/power loss.
"""
import argparse
import ctypes
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import time


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--until',required=True,help='Timezone-aware ISO timestamp')
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    deadline=datetime.fromisoformat(a.until.replace('Z','+00:00'))
    if deadline.tzinfo is None:raise ValueError('Explicit timezone required')
    if os.name!='nt':raise RuntimeError('Windows API required')
    a.out.mkdir(parents=True,exist_ok=False)
    request=ctypes.windll.kernel32.SetThreadExecutionState
    request.argtypes=[ctypes.c_uint32];request.restype=ctypes.c_uint32
    def save(active,**extra):
        (a.out/'state.json').write_text(json.dumps(dict(pid=os.getpid(),active=active,
            deadline_utc=deadline.astimezone(timezone.utc).isoformat(),display_required=False,
            utc=datetime.now(timezone.utc).isoformat(),**extra),indent=2),encoding='utf8')
    active=False
    try:
        while datetime.now(timezone.utc)<deadline:
            previous=int(request(0x80000001)) # CONTINUOUS | SYSTEM_REQUIRED
            if not previous:raise ctypes.WinError()
            active=True;save(True,request_return=previous)
            time.sleep(min(30,max(0,(deadline-datetime.now(timezone.utc)).total_seconds())))
    finally:
        released=int(request(0x80000000)) if active else None
        save(False,release_return=released)


if __name__=='__main__':main()
