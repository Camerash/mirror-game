extends SceneTree
const Cut := preload("res://art_trial/reference_cut.gd")
var count := 0
var failures := 0
func _initialize()->void:
 call_deferred("run")
func check(value:bool,message:String)->void:
 count+=1
 if not value:
  failures+=1
  push_error(message)
func run()->void:
 check(ProjectSettings.get_setting("rendering/renderer/rendering_method")=="mobile","Mobile must be the sole renderer")
 var source := (load("res://assets/reference/ceramic_block.glb") as PackedScene).instantiate()
 var core := source.find_child("*core*",true,false) as MeshInstance3D
 check(core!=null,"Core exists")
 var plane := Plane(Vector3(1,0.35,0.2).normalized(),0.08)
 var result := Cut.clip(core.mesh,plane,StandardMaterial3D.new(),StandardMaterial3D.new())
 check(result.get_surface_count()==2,"Cut has an independent cap")
 var faces := result.get_faces()
 var edges := {}
 for i: int in range(0,faces.size(),3):
  for j: int in 3:
   var a := faces[i+j].snapped(Vector3.ONE*0.0001)
   var b := faces[i+(j+1)%3].snapped(Vector3.ONE*0.0001)
   var key := str(a)+str(b) if str(a)<str(b) else str(b)+str(a)
   edges[key]=edges.get(key,0)+1
 for n: int in edges.values(): check(n==2,"Cut mesh must be closed")
 var cap := result.surface_get_arrays(1)
 for point: Vector3 in cap[Mesh.ARRAY_VERTEX]: check(absf(plane.distance_to(point))<0.0001,"Cap lies on cut plane")
 source.free()
 check_baked_maps()
 check_character_motion()
 var materials := preload("res://art_trial/reference_materials.gd")
 var original := materials.build("ceramic",2)
 var reflected := materials.build("reflected",2)
 check(original.get_shader_parameter("variation")==reflected.get_shader_parameter("variation"),"Reflection inherits source texture variation")
 print("Reference art: %d checks, %d failures"%[count,failures])
 quit(1 if failures else 0)

func check_baked_maps() -> void:
 for family: String in ["ceramic", "jade"]:
  for face: String in ["side", "top"]:
   var path := "res://assets/reference/detail_%s_%s" % [family,face]
   var normal := Image.load_from_file(ProjectSettings.globalize_path(path + "_normal.png"))
   var masks := Image.load_from_file(ProjectSettings.globalize_path(path + "_masks.png"))
   check(normal != null and masks != null, "Baked maps exist")
   if normal == null or masks == null: continue
   check(normal.get_size()==Vector2i(1024,1024), "Detail bake resolution")
   var minimum := 1.0
   var maximum := 0.0
   for y: int in range(0,1024,16):
    for x: int in range(0,1024,16):
     var sample := normal.get_pixel(x,y)
     minimum = minf(minimum,sample.r)
     maximum = maxf(maximum,sample.r)
   check(maximum-minimum>0.05, "Relief normal must not be flat")
   var flat := normal.get_pixel(512,128)
   if family=="ceramic" and face=="side":
    check(absf(flat.r-0.5)<0.12 and absf(flat.g-0.5)<0.12,"Normal data is linear, not sRGB")

func check_character_motion() -> void:
 var character := preload("res://art_trial/reference_character.gd").new()
 root.add_child(character)
 check(character.cloak != null, "Cloak node exists")
 if character.cloak != null:
  check(character.cloak.mesh.get_blend_shape_count()==2, "Cloak retains both motion shapes")
  var imported := character.CharacterScene.instantiate()
  var source_cloak := imported.find_child("Cloak", true, false) as MeshInstance3D
  check(character.cloak.mesh != source_cloak.mesh, "Art material changes use a local mesh resource")
  var soft_material := character.cloak.mesh.surface_get_material(0) as StandardMaterial3D
  check(soft_material != source_cloak.mesh.surface_get_material(0), "Imported cloak material remains separate")
  check(soft_material.roughness >= 0.72, "Soft cloak keeps a matte finish")
  imported.free()
  for step: int in 60: character.update_motion(1.0/60.0,Vector3(0,0,0.65))
  check(character.hem_offset.length()>0.005 and character.hem_offset.length()<=character.HEM_SWAY_LIMIT,"Walking produces restrained cloth motion")
  for step: int in 180: character.update_motion(1.0/60.0,Vector3.ZERO)
  check(character.hem_offset.length()<0.0001, "Cloak settles at rest")
  character.reset_motion()
  check(character.hem_offset==Vector2.ZERO,"Reset clears cloth motion")
 character.free()
