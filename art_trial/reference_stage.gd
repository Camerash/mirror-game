extends Node3D
## Isolated art assets. No gameplay collision or history is changed.
const Materials := preload("res://art_trial/reference_materials.gd")
const Frame := preload("res://world/mirror_frame.gd")
var blocks: Array[Node3D] = []
var mirror := Node3D.new()

func _ready() -> void:
 for index: int in 8:
  var kind := "ceramic" if index < 3 else ("reflected" if index < 6 else "jade")
  var path := "res://assets/reference/jade_block.glb" if kind == "jade" else "res://assets/reference/ceramic_block.glb"
  if index == 7: path = "res://assets/reference/goal_block.glb"
  var block := (load(path) as PackedScene).instantiate() as Node3D
  block.position.x = index * 1.015 + (0.35 if index == 7 else 0.0)
  if kind == "reflected": block.scale.x = -1.0
  add_child(block)
  blocks.append(block)
  apply_surface(block, Materials.build("goal" if index == 7 else kind, 5 - index if kind == "reflected" else index % 3))
 _build_mirror()

func apply_surface(root: Node, material: Material) -> void:
 if root is MeshInstance3D and "Gold" not in root.name:
  root.material_override = material
 for child: Node in root.get_children():
  apply_surface(child, material)

func _build_mirror() -> void:
 add_child(mirror)
 mirror.position = Vector3(2.5375,1.15,0)
 mirror.rotation.y = PI/2
 var frame := Frame.new()
 mirror.add_child(frame)
 frame.update_frame(Vector2(1.12,2.45),false,true)
 frame.metal.albedo_color = Color("c4ae79")
 frame.metal.roughness = 0.2
 var panel := MeshInstance3D.new()
 var mesh := QuadMesh.new()
 mesh.size = Vector2(1.1,2.43)
 panel.mesh = mesh
 var glass := ShaderMaterial.new()
 glass.shader = preload("res://art_trial/reference_glass.gdshader")
 panel.material_override = glass
 panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mirror.add_child(panel)


 _edge_light()

func _edge_light()->void:
 var tool := SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var corners := [Vector3(-0.55,-1.215,0),Vector3(0.55,-1.215,0),Vector3(0.55,1.215,0),Vector3(-0.55,1.215,0)]
 for index: int in 4:
  var a: Vector3=corners[index]
  var b: Vector3=corners[(index+1)%4]
  for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
   tool.set_uv(corner)
   tool.add_vertex(a.lerp(b,corner.x)+Vector3.BACK*corner.y*0.12)
 var glow := MeshInstance3D.new()
 glow.mesh=tool.commit()
 var material := ShaderMaterial.new()
 material.shader=preload("res://art_trial/reference_edge.gdshader")
 glow.material_override=material
 glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mirror.add_child(glow)
