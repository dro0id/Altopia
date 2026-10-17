import bpy, math, os
K=os.environ.get("KENNEY_GLB","/tmp/claude-0/kenney/sk/Models/GLTF format/"); OUT=os.environ.get("OUT","./")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=K+"astronautA.glb")
P={o.name:o for o in bpy.data.objects}
P["astronautA"].location=(0,0,0); bpy.context.view_layer.update()
def mat(name, rgb, metal=0.2, rough=0.5, emit=None, ei=0):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Metallic"].default_value=metal; b.inputs["Roughness"].default_value=rough
    if emit: b.inputs["Emission Color"].default_value=(*emit,1); b.inputs["Emission Strength"].default_value=ei
    return m
SUIT=mat("suit_steel",(0.42,0.5,0.62),0.25,0.5); JOINT=mat("suit_dark",(0.011,0.016,0.024),0.5,0.35,(0.2,0.9,1.0),0.12)
ACC=mat("accent_cyan",(0.012,0.07,0.09),0.4,0.3,(0.2,0.9,1.0),0.7); PACK=mat("pack_navy",(0.07,0.09,0.13),0.8,0.45)
VIS=mat("visor_glass",(0.01,0.025,0.04),0.9,0.08,(0.1,0.5,0.7),0.25); GLOW=mat("glow_magenta",(0.25,0.03,0.2),0.2,0.2,(1.0,0.3,0.85),0.9)

def smooth(o, levels=2):
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=0.002); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_smooth()
    m=o.modifiers.new("sub","SUBSURF"); m.levels=levels; m.render_levels=levels
def assign(o, mats):
    o.data.materials.clear()
    for m in mats: o.data.materials.append(m)
# 1) arrondir les pièces Kenney (look "gonflé") et remplacer leurs matières
for n,mats in (("body",[SUIT,SUIT,ACC]),("armLeft",[SUIT,SUIT,SUIT]),("armRight",[SUIT,SUIT,SUIT]),("legLeft",[SUIT,JOINT,SUIT]),("legRight",[JOINT,SUIT,SUIT])):
    o=P[n]; assign(o,mats); smooth(o,2)
    o.scale=(o.scale[0]*1.15,o.scale[1]*1.15,o.scale[2]*1.05)
# 2) gros casque sphérique + visière + joint de cou
def prim(kind,name,loc,scale,parent,m,**kw):
    getattr(bpy.ops.mesh,f"primitive_{kind}_add")(location=loc,**kw); o=bpy.context.active_object; o.name=name
    from mathutils import Matrix, Vector
    o.parent=parent; o.matrix_world=P["astronautA"].matrix_world @ Matrix.LocRotScale(Vector(loc),None,Vector(scale)); o.data.materials.append(m); bpy.ops.object.shade_smooth(); return o
head=P["head"]; head.hide_set(True); head.hide_render=True  # l'ancienne tête est remplacée
helmet=prim("uv_sphere","helmet",(0,0.0,0.65),(0.185,0.185,0.185),P["body"],SUIT,segments=32,ring_count=20)
visor=prim("uv_sphere","visor",(0,0.085,0.66),(0.145,0.13,0.11),P["body"],VIS,segments=32,ring_count=20)
neck=prim("torus","neck_ring",(0,0,0.5),(0.1,0.1,0.1),P["body"],ACC,major_radius=1.0,minor_radius=0.25)
pack=prim("cube","backpack",(0,-0.19,0.38),(0.16,0.09,0.17),P["body"],PACK); bv=pack.modifiers.new("bev","BEVEL"); bv.width=0.35; bv.segments=4; bv.limit_method='NONE'
prim("cube","pack_panel",(0,-0.285,0.38),(0.1,0.01,0.1),P["body"],ACC)
prim("cylinder","antenna",(0.09,-0.19,0.62),(0.012,0.012,0.1),P["body"],JOINT)
prim("uv_sphere","antenna_tip",(0.09,-0.19,0.72),(0.028,0.028,0.028),P["body"],GLOW)
prim("uv_sphere","pack_lamp",(-0.07,-0.285,0.46),(0.025,0.02,0.025),P["body"],GLOW)
for s_,x in (("L",-0.075),("R",0.075)):
    prim("uv_sphere","boot"+s_,(x,0.02,0.045),(0.07,0.1,0.055),P["leg"+("Left" if s_=="L" else "Right")],ACC)
for s_,x in (("L",-0.186),("R",0.186)):
    prim("uv_sphere","glove"+s_,(x,0.0,0.16),(0.065,0.065,0.065),P["arm"+("Left" if s_=="L" else "Right")],JOINT)

# 5) animation : mêmes clips que le capitaine V1 (pivots épaules/hanches)
def pivot(o,z):
    cur=bpy.context.scene.cursor; cur.location=o.matrix_world.translation.copy(); cur.location.z=z
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o; bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
# les modificateurs ne gênent pas origin_set ; on garde les pivots d'origine des pièces
for n,z in (("armLeft",0.58),("armRight",0.58),("legLeft",0.32),("legRight",0.32)): pivot(P[n],z)
bpy.context.scene.render.fps=24
def key(o,f,rx=0,rz=0,loc=None):
    o.rotation_mode='XYZ'; o.rotation_euler=(rx,0,rz); o.keyframe_insert("rotation_euler",frame=f)
    if loc is not None: o.location=loc; o.keyframe_insert("location",frame=f)
def walk(o):
    a=0.7; L={"armLeft":a,"armRight":-a,"legLeft":-a,"legRight":a}
    if o.name in L: key(o,1,rx=L[o.name]); key(o,13,rx=-L[o.name]); key(o,25,rx=L[o.name])
    if o.name=="body":
        b=o.location.copy()
        for f,dz in ((1,0),(7,0.015),(13,0),(19,0.015),(25,0)): key(o,f,loc=(b.x,b.y,b.z+dz))
def idle(o):
    if o.name=="body":
        b=o.location.copy()
        for f,dz in ((1,0),(30,0.012),(60,0)): key(o,f,loc=(b.x,b.y,b.z+dz))
def shoot(o):
    if o.name=="armRight": key(o,1); key(o,6,rx=-1.5); key(o,10,rx=-1.4); key(o,16)
    if o.name=="body": b=o.location.copy(); key(o,1,loc=tuple(b)); key(o,7,loc=(b.x,b.y+0.02,b.z)); key(o,16,loc=tuple(b))
PARTS=[P[k] for k in ("armLeft","armRight","legLeft","legRight","body")]
for o in PARTS: o.animation_data_create()
for nm,fn in (("Walk",walk),("Idle",idle),("Shoot",shoot)):
    for o in PARTS:
        act=bpy.data.actions.new(f"{nm}_{o.name}"); o.animation_data.action=act; fn(o); o.animation_data.action=None
        fc=[fc for l in act.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves]
        if not fc: bpy.data.actions.remove(act); continue
        tr=o.animation_data.nla_tracks.new(); tr.name=nm; tr.strips.new(nm,1,act)
bpy.ops.export_scene.gltf(filepath=OUT+"captain_astro.glb", export_format='GLB', export_animation_mode='NLA_TRACKS', export_apply=True, use_visible=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT+"captain_astro.blend")
print("ASTRO OK", sorted(o.name for o in bpy.data.objects if o.type=="MESH"))
