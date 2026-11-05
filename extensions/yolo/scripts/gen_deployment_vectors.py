"""RTL vectors from the exact packed deployment, not the old calibration."""
import json
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]


def words(path,data):
    data+=bytes((-len(data))%8)
    path.write_text("".join(f"{int.from_bytes(data[i:i+8],'little'):016x}\n"
                            for i in range(0,len(data),8)),encoding="ascii")


def generate():
    graph=json.loads((ROOT/"gen/integration/packed/memory_map.json").read_text())
    bundle=json.loads((ROOT/"gen/integration/deployment/bundle.json").read_text())
    blob=(ROOT/"gen/integration/packed/model.bin").read_bytes()
    oracle=np.load(ROOT/"gen/integration/cpu_oracle.npz")
    image=np.random.default_rng(193).random((1,3,320,320),dtype=np.float32)
    quant=np.floor(image*127+0.5).astype(np.int8)
    for index in (0,1,22,81):
        original=bundle["ops"][index]
        item=graph["ops"][index]
        if item["kind"]!="YOLO_CONV":
            raise ValueError(f"Expected conv {index}")
        cfg=dict(item["conv"])
        source=original["inputs"][0]
        inp=(quant if source==-1 else oracle[f"op{source}"])[0].transpose(1,2,0)
        padded=np.zeros((cfg["in_h"],cfg["in_w"],cfg["cin"]),dtype=np.int8)
        padded[...,:inp.shape[-1]]=inp
        expected=oracle[f"op{index}"][0].transpose(1,2,0).tobytes()
        memory=bytearray(padded.tobytes())
        local_addresses={"a_base":0}
        sizes={"w_base":cfg["cout"]*cfg["k"]**2*cfg["cin"],
               "q_base":cfg["cout"]*8,"t_base":256}
        for name,length in sizes.items():
            local_addresses[name]=(len(memory)+255)//256*256
            memory.extend(bytes(local_addresses[name]-len(memory)))
            offset=cfg[name]-graph["blob_base"]
            memory.extend(blob[offset:offset+length])
        local_addresses["y_base"]=(len(memory)+255)//256*256
        memory.extend(bytes(local_addresses["y_base"]-len(memory)))
        memory.extend(bytes([0xa5])*len(expected))
        folder=ROOT/"gen/integration/rtl_vectors"/f"deploy{index}"
        folder.mkdir(parents=True,exist_ok=True)
        words(folder/"ddr.hex",bytes(memory))
        words(folder/"expected.hex",expected)
        params=("IN_H","IN_W","CINPAD","COUT","K","STRIDE","ACT","TR","PAD","OH","OW")
        values=(cfg["in_h"],cfg["in_w"],cfg["cin"],cfg["cout"],cfg["k"],
                cfg["stride"],cfg["act"],cfg["tr"],cfg["pad"],cfg["out_h"],cfg["out_w"])
        text="localparam integer "+", ".join(f"P_{k}={v}" for k,v in zip(params,values))+";\n"
        text+=f"localparam integer P_MEMW={(len(memory)+7)//8}, P_NOUT={len(expected)//8};\n"
        text+=f'`define DDR_FILE "{(folder/"ddr.hex").as_posix()}"\n'
        text+=f'`define EXP_FILE "{(folder/"expected.hex").as_posix()}"\n'
        text+="localparam [31:0] "+", ".join(
            f"P_{k.upper()}=32'h{v:08x}" for k,v in local_addresses.items())+";\n"
        (folder/"tb_params.vh").write_text(text,encoding="ascii")
        print(f"DEPLOYMENT_VECTOR {index} {original['module']} {len(expected)} bytes")


if __name__=="__main__":
    generate()
