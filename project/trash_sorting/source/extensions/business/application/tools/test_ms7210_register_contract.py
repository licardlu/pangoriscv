"""Audit audio RTL addresses/masks/values against the pinned original driver.

Downloads unmodified upstream source snapshots with provenance on first run;
subsequent runs verify local snapshots against recorded Git blob hashes.
The expected operations are evaluated from C source calls, not RTL/TB values.
"""
from pathlib import Path
import ast
import base64
import hashlib
import json
import operator
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
COMMIT = 'd7632336b5369c3241256108e336310d018f8259'
REPO = 'avmwww/ms7210-linux-driver'
SNAPSHOT = ROOT / 'evidence/ms7210_reference'
SNAPSHOT.mkdir(parents=True, exist_ok=True)
meta_path = SNAPSHOT / 'provenance.json'
metadata = json.loads(meta_path.read_text('utf-8')) if meta_path.exists() else {}
for name in ('ms7210.h', 'ms7210.c', 'LICENSE'):
    dest = SNAPSHOT / name
    if not dest.exists():
        url = f'https://api.github.com/repos/{REPO}/contents/{name}?ref={COMMIT}'
        request = urllib.request.Request(url, headers={'User-Agent': 'MS7210-register-audit'})
        with urllib.request.urlopen(request, timeout=40) as response:
            entry = json.load(response)
        blob = base64.b64decode(entry['content'])
        dest.write_bytes(blob)
        metadata[name] = {'url': f'https://github.com/{REPO}/blob/{COMMIT}/{name}',
                          'git_blob_sha1': entry['sha'],
                          'sha256': hashlib.sha256(blob).hexdigest()}
    blob = dest.read_bytes()
    assert name in metadata, f'Missing provenance for {name}'
    git_sha = hashlib.sha1(f'blob {len(blob)}\0'.encode() + blob).hexdigest()
    assert git_sha == metadata[name]['git_blob_sha1'], f'Altered snapshot: {name}'
    assert hashlib.sha256(blob).hexdigest() == metadata[name]['sha256']
    meta_path.write_text(json.dumps(metadata, indent=2) + '\n', 'utf-8')

header = (SNAPSHOT / 'ms7210.h').read_text('utf-8')
c_source = (SNAPSHOT / 'ms7210.c').read_text('utf-8')
# Remove comments so prose does not accidentally become executable evidence.
clean = lambda s: re.sub(r'/\*.*?\*/|//[^\n]*', '', s, flags=re.S)
c = clean(c_source)
definitions = dict(re.findall(r'^\s*#define\s+(\w+)\s+([^\n]+)', clean(header), re.M))
for enum_name in ('HDMI_AUD_2CH', 'HDMI_AUD_LENGTH_16BITS'):
    definitions[enum_name] = re.search(r'\b' + enum_name + r'\s*=\s*(0x[0-9a-fA-F]+|\d+)', c)[1]

binary = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
          ast.LShift: operator.lshift, ast.RShift: operator.rshift,
          ast.BitOr: operator.or_, ast.BitAnd: operator.and_, ast.BitXor: operator.xor}

def evaluate(expression, context=None):
    expression = ' '.join(expression.split())
    expression = expression.replace('ms->hdmi_tx_chan', 'channel')
    expression = expression.replace('hc->audio_channels', 'audio_channels')
    expression = expression.replace('hc->audio_speaker_locations', 'speaker_locations')
    # These source expressions contain one simple C ternary, no nesting.
    if '?' in expression:
        cond, rest = expression.split('?', 1)
        yes, no = rest.split(':', 1)
        return evaluate(yes if evaluate(cond, context) else no, context)
    node = ast.parse(expression, mode='eval').body
    def visit(n):
        if isinstance(n, ast.Constant) and isinstance(n.value, int): return n.value
        if isinstance(n, ast.Name):
            if context is not None and n.id in context: return context[n.id]
            return evaluate(definitions[n.id], context)
        if isinstance(n, ast.BinOp) and type(n.op) in binary:
            return binary[type(n.op)](visit(n.left), visit(n.right))
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.Invert): return ~visit(n.operand)
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub): return -visit(n.operand)
        raise AssertionError(f'Unsupported C expression {expression!r}')
    return visit(node)

def function(name):
    start = re.search(r'\b' + name + r'\s*\([^;]*?\)\s*\{', c)
    assert start, name
    opening = c.index('{', start.start())
    depth = 1
    end = opening + 1
    while depth:
        if c[end] == '{': depth += 1
        elif c[end] == '}': depth -= 1
        end += 1
    return c[opening + 1:end - 1]

def calls(body):
    result = []
    for m in re.finditer(r'\b(ms7210_(?:tx_chan_)?(?:update_bits|write))\s*\(', body):
        pos, depth, part, args = m.end(), 1, '', []
        while depth:
            char = body[pos]
            if char == '(': depth += 1
            elif char == ')': depth -= 1
            if (char == ',' and depth == 1) or depth == 0:
                args.append(part.strip());part = ''
            else: part += char
            pos += 1
        # The initial arguments are device and, for tx_chan calls, channel.
        result.append((m[1], args[2:] if '_tx_chan_' in m[1] else args[1:]))
    return result

context = {'channel': 0, 'spdif': 0, 'hdmi_out': 1, 'audio_bits': evaluate('HDMI_AUD_LENGTH_16BITS'),
           'audio_channels': evaluate('HDMI_AUD_2CH'), 'speaker_locations': 0}
expected = []

def add_call(fn, register, which=0, local=None, body=None):
    body = function(fn) if body is None else body
    selected = [entry for entry in calls(body) if ''.join(entry[1][0].split()) == ''.join(register.split())]
    kind, args = selected[which]
    scope = dict(context, **(local or {}))
    assert 'update_bits' in kind
    expected.append({'step': len(expected), 'address': evaluate(args[0], scope),
                     'mask': evaluate(args[1], scope), 'value': evaluate(args[2], scope),
                     'register': register, 'source_function': fn,
                     'source_mask_expression': args[1], 'source_value_expression': args[2]})

reset = 'ms7210_hdmi_tx_shell_reset_enable'
init = 'ms7210_hdmi_tx_shell_init'
add_call(reset, 'MS7210_HDMI_TX_MISC_HDMI_RST_REG', local={'en': 1})
add_call(init, 'MS7210_HDMI_TX_MISC_HDMI_CLK_REG')
add_call(init, 'MS7210_HDMI_TX_MISC_AUD_CTRL')
pad = 'ms7210_misc_audio_pad_in_spdif'
# Select the actual spdif!=2 branch, which selects the input pad clock.
pad_body = function(pad).split('} else {', 1)[1]
add_call(pad, 'MS7210_CLK_CTRL5_REG', body=pad_body)
add_call(pad, 'MS7210_PINMUX_REG')
sample = function('ms7210_hdmi_tx_shell_set_audio_mode').split('case HDMI_AUD_MODE_AUDIO_SAMPLE:', 1)[1].split('break;', 1)[0]
add_call('ms7210_hdmi_tx_shell_set_audio_mode',
         'MS7210_HDMI_TX_AUDIO_CFG_REG +\n\t\t\t\t\tms->hdmi_tx_chan * MS7210_HDMI_TX_CHN_REG_ADDRESS_OFST', body=sample)
add_call('ms7210_hdmi_tx_shell_set_hdmi_out', 'MS7210_HDMI_TX_SHELL_DVI_REG')
add_call(init, 'MS7210_HDMI_TX_AUDIO_RATE_REG')
rate = function('ms7210_hdmi_tx_shell_set_audio_rate').split('case HDMI_AUD_RATE_44K1:', 1)[1]
add_call('ms7210_hdmi_tx_shell_set_audio_rate', 'MS7210_HDMI_TX_AUDIO_RATE_REG', body=rate)
add_call('ms7210_hdmi_tx_shell_set_audio_bits', 'MS7210_HDMI_TX_AUDIO_CFG_I2S_REG')
add_call('ms7210_hdmi_tx_shell_set_audio_channels', 'MS7210_HDMI_TX_AUDIO_CH_EN_REG')
add_call(init, 'MS7210_HDMI_TX_SHELL_VOLUME_CFG0_REG')
add_call(reset, 'MS7210_HDMI_TX_MISC_HDMI_RST_REG', local={'en': 0})
info_fn = 'ms7210_hdmi_tx_shell_set_audio_infoframe'
info = function(info_fn)
add_call(info_fn, 'MS7210_HDMI_TX_SHELL_CTRL_REG', which=0)
frames = {}
for i in (0, 1, 2, 4, 7):
    expr = re.search(r'frame\[' + str(i) + r'\]\s*=\s*([^;]+);', info)[1]
    frames[i] = evaluate(expr, context)
payload = [0] * frames[2]
payload[0] = frames[4];payload[3] = frames[7]
checksum = (-sum([frames[0], frames[1], frames[2], *payload])) & 255
for reg, value in [('MS7210_HDMI_TX_SHELL_INFO_TYPE_REG', frames[0]),
                   ('MS7210_HDMI_TX_SHELL_INFO_VER_REG', frames[1]),
                   ('MS7210_HDMI_TX_SHELL_INFO_LEN_REG', frames[2]),
                   *[('MS7210_HDMI_TX_SHELL_INFO_PACK_REG', v) for v in [checksum, *payload]]]:
    assert any(entry[1][0] == reg for entry in calls(info)), reg
    expected.append({'step': len(expected), 'address': evaluate(reg), 'mask': 255,
                     'value': value, 'register': reg, 'source_function': info_fn})
add_call(info_fn, 'MS7210_HDMI_TX_SHELL_CTRL_REG', which=-1)
add_call('ms7210_hdmi_tx_shell_audio_mute_enable', 'MS7210_HDMI_TX_SHELL_AVMUTE_REG', local={'en': 0})

rtl = (ROOT / 'rtl/ms7210_audio_init.v').read_text('utf-8')
actual_registers = {name: int(value, 16) for name, value in re.findall(
    r'localparam\s+\[15:0\]\s+(\w+)\s*=16\x27h([\da-fA-F]+)', rtl)}
for name, value in actual_registers.items():
    assert value == evaluate(name), f'Header/RTL address mismatch {name}: {value:04x}/{evaluate(name):04x}'
actual = {}
for match in re.finditer(r'((?:\d+\s*,\s*)*\d+)\s*:\s*operation\s*=\s*\{(\w+),8\x27h([\da-fA-F]+),8\x27h([\da-fA-F]+)\}', rtl):
    indices, reg, mask, value = match.groups()
    for index in indices.split(','):
        actual[int(index)] = (actual_registers[reg], int(mask, 16), int(value, 16))
assert len(actual) == len(expected) == 30
for row in expected:
    independent = (row['address'], row['mask'], row['value'])
    assert actual[row['step']] == independent, f'Operation mismatch {row} vs {actual[row["step"]]}'
contract = {'source_commit': COMMIT, 'source_metadata': metadata,
            'source_license_note': 'C source says GPL-2; repository LICENSE is GPL-3.0 text; both retained unmodified.',
            'selected_configuration': {'channel': 0, 'spdif': 0, 'sample_rate_hz': 48000,
                                       'sample_bits': 16, 'channels': 2},
            'not_specified_by_driver': ['I2S slot width', 'BCLK/fs ratio', 'separate MCLK/fs ratio'],
            'operations': expected}
(ROOT / 'evidence/ms7210_audio_register_contract.json').write_text(json.dumps(contract, indent=2) + '\n', 'utf-8')
print(f'TEST_PASS ms7210_register_contract {len(actual_registers)} header addresses + {len(expected)} source-evaluated address/mask/value operations')
for row in expected:
    print(f'{row["step"]:02}: {row["address"]:04X} mask={row["mask"]:02X} value={row["value"]:02X} {row["source_function"]}')
