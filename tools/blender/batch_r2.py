import bpy, glob, os
K=os.environ.get("KENNEY_GLB","/tmp/claude-0/kenney/sk/Models/GLTF format/"); OUT=os.environ.get("OUT","assets/kenney_r2/"); os.makedirs(OUT,exist_ok=True)
R2={"metal":((0.38,0.46,0.58),0.65,0.38,None,0),"metalDark":((0.07,0.09,0.13),0.8,0.45,None,0),"dark":((0.011,0.016,0.024),0.5,0.35,(0.2,0.9,1.0),0.12),
"metalRed":((0.012,0.07,0.09),0.4,0.3,(0.2,0.9,1.0),0.7),"skin":((0.01,0.025,0.04),0.9,0.08,(0.1,0.5,0.7),0.25),"crystal":((0.25,0.03,0.2),0.2,0.2,(1.0,0.3,0.85),0.9),
"rock":((0.09,0.1,0.15),0.1,0.95,None,0),"rockDark":((0.03,0.035,0.06),0.1,0.95,None,0),"rockTrack":((0.1,0.11,0.17),0.1,0.95,None,0),"bone":((0.45,0.48,0.55),0.1,0.8,None,0),"_defaultMat":((0.38,0.46,0.58),0.6,0.4,None,0)}
cache={}
def newmat(k):
    if k in cache: return cache[k]
    c,m,r,e,ei=R2[k]; mt=bpy.data.materials.new(k); mt.use_nodes=True; b=mt.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*c,1); b.inputs["Metallic"].default_value=m; b.inputs["Roughness"].default_value=r
    if e: b.inputs["Emission Color"].default_value=(*e,1); b.inputs["Emission Strength"].default_value=ei
    cache[k]=mt; return mt
files=sorted(glob.glob(K+"*.glb")); ok=0
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True); cache.clear()
    bpy.ops.import_scene.gltf(filepath=f)
    for o in bpy.data.objects:
        if o.type=="MESH":
            for i,s in enumerate(o.material_slots):
                n=s.material.name.split(".")[0] if s.material else "metal"
                if n in R2: s.material=newmat(n)
    bpy.ops.export_scene.gltf(filepath=OUT+os.path.basename(f), export_format='GLB', export_apply=True); ok+=1
print("BATCH",ok,"/",len(files))
