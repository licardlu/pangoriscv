"""Simulate POR and cable mapping extracted from the actual repair top.

Also runs the existing servo, quiz, and standalone peripheral regressions.
No FPGA implementation or download operation is performed by this tool.
"""
import os
from pathlib import Path
import argparse
import re
import subprocess


def one(pattern, source, label):
    matches = re.findall(pattern, source, re.MULTILINE | re.DOTALL)
    if len(matches) != 1:
        raise RuntimeError(f"Expected one {label}, found {len(matches)}")
    return matches[0]


def main():
    app = Path(__file__).resolve().parents[1]
    project = app.parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim', type=Path, default=Path(os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64')))
    parser.add_argument('--top', type=Path, default=project / 'yolo/portable/052_yolo_camera_top.v')
    parser.add_argument('--build-dir', type=Path)
    args = parser.parse_args()
    source = args.top.read_text(encoding='utf-8-sig')
    count_decl = one(r'(reg\s*\[\s*\d+\s*:\s*0\s*\]\s*peripheral_por_count\s*=\s*0\s*;)', source, 'POR counter declaration')
    reset_decl = one(r'(reg\s*\[\s*1\s*:\s*0\s*\]\s*peripheral_reset\s*=\s*0\s*;)', source, 'POR reset declaration')
    por = one(r'(always\s*@\(posedge sys_clk\)\s*begin\s*if\(peripheral_por_count\b.*?end\s*else\s*peripheral_reset\s*<=.*?;\s*end)', source, 'actual POR process')
    mapping = one(r'(assign\s+servo_pwm\s*=\s*logical_servo_pwm\s*;)', source, 'direct physical cable assignment')
    mask = one(r'\.SERVO_REVERSED_MASK\(\s*(4\s*\x27b[01_]+)\s*\)', source, 'normal servo direction mask')
    if int(mask.split('b')[1].replace('_', ''), 2) != 0b0000:
        raise RuntimeError('Top must reverse green0/gray2 pulse widths with mask0101')
    mode = one(r'parameter\s+PERIPHERAL_TEST_MODE\s*=\s*([01])\b', source, 'active camera quiz mode')
    if mode != '0':
        raise RuntimeError('Top must run camera-driven quiz mode0')
    peripheral_source = (app / 'rtl/trash_peripherals.sv').read_text(encoding='utf-8-sig')
    if not re.search(r'\.REVERSED_MASK\(SERVO_REVERSED_MASK\)', peripheral_source):
        raise RuntimeError('Peripheral wrapper does not pass normal servo direction mask')
    if 'locked' in por:
        raise RuntimeError('Peripheral POR still depends on PLL lock')
    if not re.search(r'application_peripherals\s*\(.*?\.servo_pwm\(logical_servo_pwm\)', source, re.DOTALL):
        raise RuntimeError('Peripheral instance does not feed logical_servo_pwm')
    build = args.build_dir or (project / 'yolo/build_camera_servo_v3_20261103/regression')
    build.mkdir(parents=True, exist_ok=True)
    harness = build / 'servo_repair_top_tb.sv'
    harness.write_text('''`timescale 1ns/1ps
module servo_repair_top_tb;
reg sys_clk=0, locked=0;
always #5 sys_clk=~sys_clk;
reg [3:0] logical_servo_pwm=0;
wire [3:0] servo_pwm;
''' + count_decl + '\n' + reset_decl + '\n' + por + '\n' + mapping + "\nlocalparam [3:0] TOP_REVERSED_MASK=" + mask + ";\n" + '''
integer n, channel;
initial begin
    for(n=1;n<=270001;n=n+1) begin
        @(posedge sys_clk); #1;
        if(n<270000 && peripheral_reset!==0)
            $fatal(1,"POR released early at cycle %0d",n);
        if(n==270000 && peripheral_reset!==2'b01)
            $fatal(1,"POR first synchronizer stage missing");
        if(n==270001 && peripheral_reset!==2'b11)
            $fatal(1,"POR must release at cycle 270001");
        @(negedge sys_clk);
        locked=~locked;
    end
    repeat(20) begin
        locked=~locked; #1;
        if(peripheral_reset!==2'b11)
            $fatal(1,"PLL lock transition asynchronously reset peripherals");
        @(posedge sys_clk); #1;
        if(peripheral_reset!==2'b11 || peripheral_por_count!==269999)
            $fatal(1,"POR did not saturate independently of PLL lock");
        @(negedge sys_clk);
    end
    for(channel=0;channel<4;channel=channel+1) begin
        logical_servo_pwm=1<<channel; #1;
        if(servo_pwm!==(4'b0001<<channel))
            $fatal(1,"Logical channel %0d has wrong physical cable mapping",channel);
    end
    for(n=0;n<16;n=n+1) begin
        logical_servo_pwm=n; #1;
        for(channel=0;channel<4;channel=channel+1)
            if(servo_pwm[channel]!==logical_servo_pwm[channel])
                $fatal(1,"Combined mapping failed %b",logical_servo_pwm);
    end
    $display("TEST_PASS servo_repair_top POR release=270001, counter saturates, PLL-independent, camera mode0, normal_mask0000, direct four one-hot and all16 cable mappings");
    $finish;
end
initial begin #3000000; $fatal(1,"Top regression timeout"); end
endmodule
''', encoding='utf-8')
    rtl = app / 'rtl'
    tests = app / 'tests'
    sources = [harness] + [rtl / name for name in (
        'servo_pwm4.sv', 'key_debounce4.sv', 'servo_key_controller.sv',
        'trash_quiz_controller.sv', 'trash_peripherals.sv')]
    cases = ['servo_repair_top', 'servo_pwm4', 'servo_key_controller',
             'trash_quiz_controller', 'trash_peripherals']
    sources += [tests / (name + '_tb.sv') for name in cases[1:]]
    logs = []

    def run(exe, *arguments):
        print('RUN ' + exe + ' ' + ' '.join(map(str, arguments)), flush=True)
        result = subprocess.run([str(args.modelsim / exe), *map(str, arguments)],
                                cwd=build, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=90)
        logs.append(result.stdout)
        (build / 'regression.log').write_text('\n'.join(logs), encoding='utf-8')
        if result.returncode or re.search(r'\*\* (?:Fatal|Error):', result.stdout):
            raise RuntimeError(result.stdout)
        return result.stdout

    try:
        if not (build / 'work').exists():
            run('vlib.exe', 'work')
        run('vlog.exe', '-sv', '-work', 'work', *sources)
        for case in cases:
            output = run('vsim.exe', '-c', '-lib', 'work', case + '_tb', '-do',
                         'onerror {quit -code 1}; run -all; quit -code 0')
            markers = [line for line in output.splitlines() if 'TEST_PASS ' + case in line]
            if not markers:
                raise RuntimeError(f'{case} did not report TEST_PASS\n{output}')
            print(markers[-1])
    finally:
        (build / 'regression.log').write_text('\n'.join(logs), encoding='utf-8')
    print('TEST_PASS servo_repair_regression; log=' + str(build / 'regression.log'))


if __name__ == '__main__':
    main()
