"""Pack approved-source WAVs as standard IMA ADPCM and independent RTL vectors.

Legacy voice_pcm8 filenames are retained for the existing synthesis ROM gate;
the manifest explicitly identifies their new codec. No frozen release is edited.
"""
import argparse,array,audioop,hashlib,json,math,wave
from pathlib import Path

STEP=[7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
CONTROL='''
    reg half;
    reg [1:0] repeats,warm;
    reg decoded_ready;
    reg signed [15:0] predictor,pcm;
    reg [6:0] step_index;
    wire [3:0] code=half?rom_q[3:0]:rom_q[7:4];
    reg [14:0] step_value;
    always @(*)begin
        case(step_index)
__STEP_CASE__
            default:step_value=32767;
        endcase
    end
    reg [16:0] magnitude;
    reg signed [17:0] reconstructed;
    reg signed [15:0] next_predictor;
    reg signed [8:0] next_index;
    always @(*)begin
        magnitude={2'b0,step_value}>>3;
        if(code[0])magnitude=magnitude+({2'b0,step_value}>>2);
        if(code[1])magnitude=magnitude+({2'b0,step_value}>>1);
        if(code[2])magnitude=magnitude+{2'b0,step_value};
        if(code[3])reconstructed=$signed({{2{predictor[15]}},predictor})-$signed({1'b0,magnitude});
        else reconstructed=$signed({{2{predictor[15]}},predictor})+$signed({1'b0,magnitude});
        if(reconstructed>18'sd32767)next_predictor=16'sh7fff;
        else if(reconstructed< -18'sd32768)next_predictor=16'sh8000;
        else next_predictor=reconstructed[15:0];
        case(code[2:0])
            4:next_index=$signed({2'b0,step_index})+9'sd2;
            5:next_index=$signed({2'b0,step_index})+9'sd4;
            6:next_index=$signed({2'b0,step_index})+9'sd6;
            7:next_index=$signed({2'b0,step_index})+9'sd8;
            default:next_index=$signed({2'b0,step_index})-9'sd1;
        endcase
        if(next_index<0)next_index=0;
        else if(next_index>88)next_index=88;
    end
    wire valid_request=request_valid&&request_asset_id>=1&&request_asset_id<=13;
    always @(posedge clk)bank_select_q<=address/BANK_SIZE;
    assign sample_valid=busy&&decoded_ready&&!valid_request;
    assign sample_pcm=pcm;
    assign sample_last=sample_valid&&remaining==1&&repeats==3;
    always @(posedge clk)begin
        if(rst)begin
            address<=0;remaining<=0;repeats<=0;warm<=0;busy<=0;
            half<=0;decoded_ready<=0;predictor<=0;pcm<=0;step_index<=0;
        end else if(valid_request)begin
            case(request_asset_id)
__CLIP_CASE__
                default:begin address<=0;remaining<=0;end
            endcase
            half<=0;repeats<=0;warm<=2;busy<=1;decoded_ready<=0;
            predictor<=0;pcm<=0;step_index<=0;
        end else if(busy)begin
            if(warm!=0)warm<=warm-1'b1;
            else if(!decoded_ready)begin
                predictor<=next_predictor;pcm<=next_predictor;step_index<=next_index[6:0];decoded_ready<=1;
            end else if(sample_ready)begin
                if(repeats==3)begin
                    repeats<=0;decoded_ready<=0;
                    if(remaining==1)begin busy<=0;remaining<=0;end
                    else begin
                        remaining<=remaining-1'b1;half<=!half;
                        if(half)begin address<=address+1'b1;warm<=2;end
                    end
                end else repeats<=repeats+1'b1;
            end
        end
    end
endmodule
'''
def main():
 p=argparse.ArgumentParser();p.add_argument('--audio',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--vectors',type=Path,required=True);a=p.parse_args()
 source=a.source.resolve();assert source.name=='source' and source.parent.name in ('overnight_020','continuation_023')
 assets=source/'extensions/business/application/assets/audio_rom';player=source/'extensions/business/application/rtl/trash_voice_rom_player.v'
 manifest=json.loads((a.audio/'sources.json').read_text(encoding='utf8'));blob=bytearray();gold=[];clips=[]
 for clip in manifest['clips']:
  ident=clip['id'];wav=a.audio/f'voice_{ident:02d}.wav'
  assert hashlib.sha256(wav.read_bytes()).hexdigest()==clip['wav_sha256']
  with wave.open(str(wav),'rb') as f:
   assert (f.getframerate(),f.getsampwidth(),f.getnchannels())==(12000,2,1)
   raw=f.readframes(f.getnframes())
  samples=len(raw)//2
  packed,state=audioop.lin2adpcm(raw+(b'\0\0' if samples%2 else b''),2,None)
  decoded,_=audioop.adpcm2lin(packed,2,None);decoded=decoded[:samples*2]
  ref=array.array('h',decoded);orig=array.array('h',raw)
  error=sum((x-y)**2 for x,y in zip(orig,ref));power=sum(x*x for x in orig)
  snr=10*math.log10(power/max(1,error));assert snr>20,(ident,snr)
  entry=dict(clip,asset_id=ident,offset=len(blob),samples=samples,bytes=len(packed),reference_sample_offset=len(gold),snr_db=snr)
  clips.append(entry);blob.extend(packed);gold.extend(ref)
 assert len(blob)<181892
 if source.parent.name=='continuation_023':assert len(blob)<=59*2048,'Existing voice-bank budget exceeded'
 assets.mkdir(parents=True,exist_ok=True);bank_count=(len(blob)+2047)//2048
 (assets/'voice_pcm8.hex').write_text(''.join(f'{x:02x}\n' for x in blob),encoding='ascii')
 for bank in range(bank_count):
  block=blob[bank*2048:(bank+1)*2048];block+=bytes(2048-len(block))
  (assets/f'voice_pcm8.hex.bank{bank:02d}.hex').write_text(''.join(f'{x:02x}\n' for x in block),encoding='ascii')
 packed_manifest={'format':'IMA ADPCM4 mono 12kHz; high nibble first; predictor/index reset to0 per clip; x4 at48kHz',
  'legacy_filename':'voice_pcm8.hex retained for build gate; content is ADPCM, not PCM8',
  'rom_bytes':len(blob),'blob_sha256':hashlib.sha256(blob).hexdigest(),'bank_count':bank_count,'assets':clips}
 (assets/'voice_rom_manifest.json').write_text(json.dumps(packed_manifest,ensure_ascii=False,indent=2),encoding='utf8')
 text=player.read_text(encoding='utf8');start=text.index('    // Keep each inferred memory')
 end=text.index('    reg half;') if '    reg half;' in text else text.index('    reg [1:0] repeats, warm, repeat_last;')
 banks=text[start:end]
 header='''// Natural Mandarin, standard IMA ADPCM4 at12kHz; each sample repeats4 times.
// Legacy ROM filename is retained for synthesis-load gate compatibility.
module trash_voice_rom_player #(
    parameter ROM_FILE="../../extensions/business/application/assets/audio_rom/voice_pcm8.hex",
    parameter integer ROM_SAMPLES=__BYTES__
)(input wire clk,rst,request_valid,input wire [3:0] request_asset_id,
  input wire sample_ready,output wire sample_valid,output wire [15:0] sample_pcm,
  output wire sample_last,output reg busy);
'''.replace('__BYTES__',str(len(blob)))
 control=CONTROL.replace('__STEP_CASE__','\n'.join(f'            {i}:step_value=15\'d{v};' for i,v in enumerate(STEP)))
 control=control.replace('request_asset_id<=13','request_asset_id<='+str(max(c['asset_id'] for c in clips)))
 control=control.replace('__CLIP_CASE__','\n'.join(f"                {c['asset_id']}:begin address<={c['offset']};remaining<={c['samples']};end" for c in clips))
 player.write_text(header+banks+control,encoding='utf8')
 if source.parent.name=='continuation_023':
  assert max(c['samples'] for c in clips)<65536
  player.write_text(player.read_text(encoding='utf8').replace('reg [31:0] remaining;','reg [15:0] remaining;'),encoding='utf8')
 a.vectors.mkdir(parents=True,exist_ok=True)
 (a.vectors/'voice_expected.hex').write_text(''.join(f'{x&65535:04x}\n' for x in gold),encoding='ascii')
 (a.vectors/'voice_vectors.svh').write_text('\n'.join(f"lengths[{c['asset_id']}]= {c['samples']}; offsets[{c['asset_id']}]= {c['reference_sample_offset']};" for c in clips)+'\n',encoding='ascii')
 print(json.dumps({'rom_bytes':len(blob),'banks':bank_count,'saved_bytes':181892-len(blob),'samples_checked':len(gold),'min_snr_db':min(c['snr_db'] for c in clips)}))
if __name__=='__main__':main()
