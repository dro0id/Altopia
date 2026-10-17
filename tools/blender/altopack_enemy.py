import bpy, os
K=os.environ.get("KENNEY_GLB","/tmp/claude-0/kenney/sk/Models/GLTF format/"); OUT=os.environ.get("OUT","./")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=K+"alien.glb")
def mat(name, rgb, metal, rough, emit=None, ei=0):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Metallic"].default_value=metal; b.inputs["Roughness"].default_value=rough
    if emit: b.inputs["Emission Color"].default_value=(*emit,1); b.inputs["Emission Strength"].default_value=ei
    return m
M={"crystal":mat("enemy_body",(0.3,0.04,0.25),0.2,0.25,(1.0,0.3,0.85),0.8),"metal":mat("enemy_plate",(0.07,0.09,0.13),0.8,0.45),
"metalDark":mat("enemy_dark",(0.03,0.035,0.06),0.6,0.5),"metalRed":mat("enemy_glow",(0.25,0.03,0.05),0.3,0.3,(1.0,0.2,0.3),1.2),"dark":mat("enemy_eye",(0.01,0.01,0.02),0.5,0.3,(1.0,0.2,0.3),1.5)}
for o in list(bpy.data.objects):
    if o.type=="MESH":
        for s in o.material_slots:
            n=s.material.name.split(".")[0] if s.material else "metal"
            if n in M: s.material=M[n]
        bpy.context.view_layer.objects.active=o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=0.002); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.shade_smooth(); m=o.modifiers.new("sub","SUBSURF"); m.levels=2; m.render_levels=2
    if o.type=="EMPTY" and o.parent is None: o.location=(0,0,0)
for o in bpy.data.objects:
    if o.name=="alien": o.location=(0,0,0)
bpy.ops.export_scene.gltf(filepath=OUT+"enemy_golem.glb", export_format='GLB', export_apply=True)
print("ENEMY OK",[o.name for o in bpy.data.objects if o.type=="MESH"])
