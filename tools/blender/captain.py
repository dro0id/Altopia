import bpy, math, sys
import os
K=os.environ.get("KENNEY_GLB","/tmp/claude-0/kenney/sk/Models/GLTF format/")
OUT=os.environ.get("OUT","./")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=K+"astronautA.glb")
P={o.name:o for o in bpy.data.objects}
root=P["astronautA"]

def mat(name, rgb, metal=0.6, rough=0.4, emit=None, ei=0):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Metallic"].default_value=metal; b.inputs["Roughness"].default_value=rough
    if emit: b.inputs["Emission Color"].default_value=(*emit,1); b.inputs["Emission Strength"].default_value=ei
    return m

# --- TEST 1 : modification de géométrie : silhouette du capitaine ---
steel=mat("cap_steel",(0.35,0.42,0.55)); cyan=mat("cap_cyan",(0.05,0.3,0.4),0.3,0.3,(0.2,0.9,1.0),1.0); gold=mat("cap_gold",(0.8,0.6,0.15),1.0,0.25)
def add(kind, name, loc, scale, parent, m, **kw):
    getattr(bpy.ops.mesh,f"primitive_{kind}_add")(location=loc, **kw)
    o=bpy.context.active_object; o.name=name; o.scale=scale; o.parent=parent; o.data.materials.append(m)
    bpy.ops.object.shade_smooth(); return o
# épaulettes
for s,x in (("L",-0.19),("R",0.19)):
    p=add("cube","pad"+s,(x,0,0.5),(0.06,0.11,0.035),P["body"],gold)
    p.parent=P["arm"+("Left" if s=="L" else "Right")]; p.location=(x*0.0+(-0.03 if s=="L" else 0.03),0,0.12)
# crête de casque
add("cube","crest",(0,0,0.68),(0.012,0.12,0.04),P["head"],cyan)
# cape
cape=add("cube","cape",(0,-0.15,0.38),(0.2,0.012,0.17),P["body"],steel)
# sac dorsal lumineux
add("cube","pack",(0,-0.17,0.3),(0.11,0.05,0.12),P["body"],steel)
add("cube","pack_light",(0,-0.222,0.3),(0.07,0.006,0.1),P["body"],cyan)
print("TEST1 objets:",sorted(o.name for o in bpy.data.objects if o.type=="MESH"))

# --- TEST 2 : animation : idle, marche, tir ---
for n in ("armLeft","armRight","legLeft","legRight","head","body","cape"):
    P[n]=bpy.data.objects[n] if n in bpy.data.objects else P.get(n)
def pivot(o, z):  # origine à l'épaule/hanche pour pivoter
    cur=bpy.context.scene.cursor; cur.location=o.matrix_world.translation.copy(); cur.location.z=z
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
for n,z in (("armLeft",0.58),("armRight",0.58),("legLeft",0.32),("legRight",0.32)): pivot(P[n],z)
sc=bpy.context.scene; sc.render.fps=24
def key(o,frame,rx=0,ry=0,rz=0,loc=None):
    o.rotation_mode='XYZ'; o.rotation_euler=(rx,ry,rz); o.keyframe_insert("rotation_euler",frame=frame)
    if loc is not None: o.location=loc; o.keyframe_insert("location",frame=frame)
def clip(name, f0, f1, fn):
    act=bpy.data.actions.new(name)
    for o in (P["armLeft"],P["armRight"],P["legLeft"],P["legRight"],P["body"],P["head"]):
        o.animation_data_create(); o.animation_data.action=act; fn(o)
    for o in (P["armLeft"],P["armRight"],P["legLeft"],P["legRight"],P["body"],P["head"]):
        o.animation_data.action=None
    tr=P["armLeft"].animation_data.nla_tracks.new(); 
    return act
def walk(o):
    a=0.7; L={"armLeft":a,"armRight":-a,"legLeft":-a,"legRight":a}
    if o.name in L:
        key(o,1,rx=L[o.name]); key(o,13,rx=-L[o.name]); key(o,25,rx=L[o.name])
    if o.name=="body":
        b=o.location.copy()
        for f,dz in ((1,0),(7,0.015),(13,0),(19,0.015),(25,0)): key(o,f,loc=(b.x,b.y,b.z+dz))
def idle(o):
    if o.name=="body":
        b=o.location.copy()
        for f,dz in ((1,0),(30,0.012),(60,0)): key(o,f,loc=(b.x,b.y,b.z+dz))
    if o.name=="head": key(o,1); key(o,30,rz=0.4); key(o,60)
def shoot(o):
    if o.name=="armRight": key(o,1,rx=0); key(o,6,rx=-1.5); key(o,10,rx=-1.4); key(o,16,rx=0)
    if o.name=="body":
        b=o.location.copy(); key(o,1,loc=tuple(b)); key(o,7,loc=(b.x,b.y+0.02,b.z)); key(o,16,loc=tuple(b))
PARTS=[P[k] for k in ("armLeft","armRight","legLeft","legRight","body","head")]
for o in PARTS: o.animation_data_create()
for nm,fn in (("Walk",walk),("Idle",idle),("Shoot",shoot)):
    for o in PARTS:
        act=bpy.data.actions.new(f"{nm}_{o.name}"); o.animation_data.action=act; fn(o)
        o.animation_data.action=None
        if len(act.fcurves if hasattr(act,'fcurves') else [fc for l in act.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves])==0:
            bpy.data.actions.remove(act); continue
        tr=o.animation_data.nla_tracks.new(); tr.name=nm; st=tr.strips.new(nm,1,act)
print("TEST2 actions:",len(bpy.data.actions))

# --- TEST 3 : export glTF + .blend ---
bpy.ops.export_scene.gltf(filepath=OUT+"captain.glb", export_format='GLB', export_animation_mode='NLA_TRACKS', export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT+"captain.blend")
print("EXPORT OK")
