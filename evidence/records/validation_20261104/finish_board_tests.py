"""Wait for the current dataset owner, then serialize CPU and restore operations."""
from pathlib import Path
import json,subprocess,sys,time
BASE=Path(__file__).resolve().parent
def main():
    print('WAITING_FOR_EXISTING_DATASET_PROCESS',flush=True)
    while True:
        data=json.loads((BASE/'dataset_board_results.json').read_text())
        if data.get('failed'):raise RuntimeError('Dataset failed; preserve board for diagnosis')
        if data.get('completed') and len(data['runs'])==18:break
        time.sleep(2)
    time.sleep(2)
    print('DATASET_FINISHED_STARTING_COREMARK',flush=True)
    with (BASE/'coremark_fresh.log').open('x',encoding='utf-8') as log:
        code=subprocess.call([sys.executable,str(BASE/'coremark_fresh.py')],stdout=log,stderr=subprocess.STDOUT)
    print('COREMARK_EXIT',code,flush=True)
    with (BASE/'restore_camera.log').open('x',encoding='utf-8') as log:
        code2=subprocess.call([sys.executable,str(BASE/'restore_camera.py')],stdout=log,stderr=subprocess.STDOUT)
    print('RESTORE_EXIT',code2,flush=True)
    if code2:raise RuntimeError('Restore failed; inspect restore log')
if __name__=='__main__':main()
