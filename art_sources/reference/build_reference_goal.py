"""Build the jade goal block with a recessed gold fitting.

Run with: blender --background --python art_sources/reference/build_reference_goal.py
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_sources" / "reference"
ASSETS = ROOT / "assets" / "reference"

def make_material(name, colour, roughness, metallic=0.0):
	material = bpy.data.materials.new(name)
	shader = material.node_tree.nodes.get("Principled BSDF")
	shader.inputs["Base Color"].default_value = (*colour, 1.0)
	shader.inputs["Roughness"].default_value = roughness
	shader.inputs["Metallic"].default_value = metallic
	return material

def jade_core(jade):
	bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, 0.35))
	core = bpy.context.object
	core.name = "Jade goal core"
	core.dimensions = (1.0, 1.0, 0.7)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	core.data.materials.append(jade)
	bevel = core.modifiers.new("Soft 0.09 bevel", "BEVEL")
	bevel.width = 0.09
	bevel.segments = 5
	bpy.context.view_layer.objects.active = core
	bpy.ops.object.modifier_apply(modifier=bevel.name)
	for polygon in core.data.polygons:
		polygon.use_smooth = True
	# The cutter reaches above the top so it leaves a true 0.06 deep socket.
	bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=0.14, depth=0.065, location=(0.0, 0.0, 0.7 - 0.03))
	cutter = bpy.context.object
	boolean = core.modifiers.new("Goal socket", "BOOLEAN")
	boolean.operation = "DIFFERENCE"
	boolean.solver = "EXACT"
	boolean.object = cutter
	bpy.context.view_layer.objects.active = core
	bpy.ops.object.modifier_apply(modifier=boolean.name)
	bpy.data.objects.remove(cutter, do_unlink=True)
	return core

def gold_ring(gold):
	# Profile starts at the top outer lip, travels down the socket wall, then
	# returns along the inner wall. The bottom segment makes physical contact.
	profile = ((0.190, 0.356), (0.190, 0.334), (0.165, 0.315), (0.140, 0.315), (0.140, 0.356))
	sides = 64
	vertices = []
	faces = []
	for radius, height in profile:
		height += 0.35
		for side in range(sides):
			angle = math.tau * side / sides
			vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, height))
	for ring in range(len(profile)):
		for side in range(sides):
			next_side = (side + 1) % sides
			faces.append((ring * sides + side, ring * sides + next_side, ((ring + 1) % len(profile)) * sides + next_side, ((ring + 1) % len(profile)) * sides + side))
	mesh = bpy.data.meshes.new("Gold fitting ring mesh")
	mesh.from_pydata(vertices, [], faces)
	mesh.materials.append(gold)
	uv = mesh.uv_layers.new(name="FittingUV")
	for polygon in mesh.polygons:
		for loop_index in polygon.loop_indices:
			vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
			uv.data[loop_index].uv = (math.atan2(vertex.y, vertex.x) / math.tau + 0.5, (vertex.z - 0.665) / 0.041)
	ring = bpy.data.objects.new("Gold fitting ring", mesh)
	bpy.context.collection.objects.link(ring)
	bevel = ring.modifiers.new("Soft gold edges", "BEVEL")
	bevel.width = 0.006
	bevel.segments = 2
	bpy.context.view_layer.objects.active = ring
	bpy.ops.object.modifier_apply(modifier=bevel.name)
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	return ring

def build():
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False)
	ASSETS.mkdir(parents=True, exist_ok=True)
	root = bpy.data.objects.new("JadeGoalBlock", None)
	bpy.context.collection.objects.link(root)
	core = jade_core(make_material("Jade goal glaze", (0.27, 0.47, 0.34), 0.31))
	ring = gold_ring(make_material("Gold fitting", (0.75, 0.48, 0.10), 0.18, 0.88))
	core.parent = root
	ring.parent = root
	bpy.context.view_layer.objects.active = root
	root.select_set(True)
	bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "goal_block.blend"))
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=str(ASSETS / "goal_block.glb"), export_format="GLB", export_materials="EXPORT", export_apply=True, export_yup=True)

if __name__ == "__main__":
	build()
