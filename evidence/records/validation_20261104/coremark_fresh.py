"""Capture two real CoreMark runs before restoring the full camera image."""
from pathlib import Path
import hashlib,importlib.util,json,sys,threading,time
import serial
BASE=Path(__file__).resolve().parent
REPO=BASE.parents[2]
sys.path.insert(0,str(REPO/'extensions/yolo/scripts'))
import program_board
program_board.TOOLS=Path(r'D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin')
spec=importlib.util.spec_from_file_location('cpu_measure',REPO/'project/cpu120/tools/measure.py')
measure=importlib.util.module_from_spec(spec);spec.loader.exec_module(measure)
SBIT=REPO/'project/pds_native_120/bitstream/current/pango_replica_core_120.sbit'

def main():
    result=BASE/'coremark_fresh_results.json'
    if result.exists():raise RuntimeError('Preserve existing results; do not overwrite')
    report=dict(bitstream=str(SBIT),sha256=hashlib.sha256(SBIT.read_bytes()).hexdigest(),
        sta_closed=False,setup_slow_wns_ns=-1.426,runs=[])
    result.write_text(json.dumps(report,indent=2),encoding='utf-8')
    for index in range(2):
        buffer=bytearray();stop=threading.Event()
        with serial.Serial('COM34',115200,timeout=.2,write_timeout=10) as port:
            port.reset_input_buffer()
            def reader():
                while not stop.is_set():
                    part=port.read(max(1,port.in_waiting))
                    if part:buffer.extend(part)
            thread=threading.Thread(target=reader,daemon=True);thread.start()
            try:
                sys.argv=['program_board','--sbit',str(SBIT),'--out',str(BASE/f'coremark_program_{index+1}')]
                program_board.main()
                deadline=time.monotonic()+90
                while b'BENCH_DONE' not in buffer and time.monotonic()<deadline:time.sleep(.1)
                if b'BENCH_DONE' not in buffer:raise TimeoutError('No completed CoreMark output')
                time.sleep(.3)
            finally:
                stop.set();thread.join(timeout=2)
                (BASE/f'coremark_run_{index+1}.bin').write_bytes(buffer)
                (BASE/f'coremark_run_{index+1}.txt').write_text(buffer.decode('ascii',errors='replace'),encoding='utf-8')
        row=measure.assess(buffer.decode('ascii',errors='replace'))
        row.update(fresh_hardware_capture=True,board_verified=True,sta_closed=False,
            coremark_per_second=row['iterations']/row['seconds'],
            coremark_per_lut=row['iterations']/row['seconds']/8875,
            uart_sha256=hashlib.sha256(buffer).hexdigest())
        report['runs'].append(row)
        result.write_text(json.dumps(report,indent=2),encoding='utf-8')
        print('FRESH_COREMARK',index+1,json.dumps(row),flush=True)
    report['completed']=True
    result.write_text(json.dumps(report,indent=2),encoding='utf-8')

if __name__=='__main__':main()
