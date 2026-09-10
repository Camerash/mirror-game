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
 print("Reference art: %d checks, %d failures"%[count,failures])
 quit(1 if failures else 0)
