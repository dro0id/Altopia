"""Allège un GLB : poids de peau en octets normalisés (4 o au lieu de 16 o par sommet) et normales en octets normalisés (KHR_mesh_quantization).
python tools/blender/glb_slim.py fichier.glb [...]   (remplace le fichier ; sans perte visible, les normales gardent ~1° de précision)"""
import sys, json, struct

def slim(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]; j = json.loads(d[20:20 + jl])
    bo = 20 + jl; bl = struct.unpack("<I", d[bo:bo + 4])[0]; binb = d[bo + 8:bo + 8 + bl]
    acs, bvs = j["accessors"], j["bufferViews"]
    use = {}
    for i, a in enumerate(acs): use.setdefault(a.get("bufferView"), []).append(i)
    new = {}
    quant = False
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            at = p["attributes"]
            if "WEIGHTS_0" in at:
                a = acs[at["WEIGHTS_0"]]; bv = bvs[a["bufferView"]]
                if a["componentType"] == 5126 and len(use[a["bufferView"]]) == 1 and a["type"] == "VEC4":
                    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0); n = a["count"]
                    vals = struct.unpack("<%df" % (n * 4), binb[off:off + n * 16]); out = bytearray()
                    for i in range(n):
                        w = vals[i * 4:i * 4 + 4]; q = [int(round(x * 255)) for x in w]
                        diff = 255 - sum(q)
                        if diff: q[max(range(4), key=lambda k: w[k])] += diff
                        out += bytes(max(0, min(255, x)) for x in q)
                    new[a["bufferView"]] = bytes(out)
                    a["componentType"] = 5121; a["normalized"] = True; bv["byteLength"] = len(out); bv.pop("byteStride", None); bv["byteOffset"] = 0
            if "NORMAL" in at:
                a = acs[at["NORMAL"]]; bv = bvs[a["bufferView"]]
                if a["componentType"] == 5126 and len(use[a["bufferView"]]) == 1 and a["type"] == "VEC3":
                    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0); n = a["count"]
                    vals = struct.unpack("<%df" % (n * 3), binb[off:off + n * 12]); out = bytearray()
                    for i in range(n):
                        x, y, z = vals[i * 3:i * 3 + 3]
                        out += struct.pack("<bbbb", *[max(-127, min(127, int(round(c * 127)))) for c in (x, y, z)], 0)
                    new[a["bufferView"]] = bytes(out)
                    a["componentType"] = 5120; a["normalized"] = True; bv["byteLength"] = len(out); bv["byteStride"] = 4; bv["byteOffset"] = 0; quant = True
    # reconstruit le tampon
    out = bytearray()
    for i, bv in enumerate(bvs):
        if i in new: data = new[i]
        else:
            off = bv.get("byteOffset", 0); data = binb[off:off + bv["byteLength"]]
        while len(out) % 4: out += b"\0"
        bv["byteOffset"] = len(out); bv["byteLength"] = len(data); out += data
        if i not in new and "byteOffset" in bv: pass
    while len(out) % 4: out += b"\0"
    j["buffers"][0]["byteLength"] = len(out)
    if quant:
        j.setdefault("extensionsUsed", [])
        if "KHR_mesh_quantization" not in j["extensionsUsed"]: j["extensionsUsed"].append("KHR_mesh_quantization")
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4: js += b" "
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total)); f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(out), 0x004E4942)); f.write(out)
    return total

if __name__ == "__main__":
    for p in sys.argv[1:]: print(p, slim(p))
