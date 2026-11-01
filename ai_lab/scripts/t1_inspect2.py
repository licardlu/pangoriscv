import onnxruntime as ort, json, os
m = r"E:\file\pango\project\ai_lab\data\models\garbage-detector.onnx"
s = ort.InferenceSession(m, providers=["CPUExecutionProvider"])
md = s.get_modelmeta()
for attr in ["producer_name","graph_name","description","domain","version","custom_metadata_map"]:
    try: print(attr, "=", str(getattr(md, attr))[:800])
    except Exception as e: print(attr, "ERR", e)
print("inputs", [(i.name, i.shape) for i in s.get_inputs()])
print("outputs", [(o.name, o.shape) for o in s.get_outputs()])
