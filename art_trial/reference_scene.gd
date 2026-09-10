extends Node3D
const Stage := preload("res://art_trial/reference_stage.gd")
const Lighting := preload("res://art_trial/reference_lighting.gd")
const Character := preload("res://art_trial/reference_character.gd")
const Cut := preload("res://art_trial/reference_cut.gd")
var stage := Stage.new()
var character := Character.new()
var camera := Camera3D.new()
var controls := HFlowContainer.new()
var angle := 0
var view := 0
var moving := false
var motion_time := 0.0
var sliced := false
var cap_inspection := false
var original_meshes: Dictionary = {}
var original_transforms: Dictionary = {}
var intact_mirror := Transform3D.IDENTITY

func _ready() -> void:
 add_child(Lighting.new())
 add_child(stage)
 add_child(character)
 character.position = Vector3(0,0.7,0)
 character.rotation.y = PI/2
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.near = 0.02
 camera.far = 80
 add_child(camera)
 camera.current = true
 get_viewport().msaa_3d = Viewport.MSAA_4X
 _controls()
 get_viewport().size_changed.connect(fit_camera)
 intact_mirror=stage.mirror.transform
 if "--record" in OS.get_cmdline_user_args():
  moving=true
  controls.hide()
 fit_camera()

func _controls() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 layer.add_child(controls)
 controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 controls.offset_top = -64
 controls.offset_left = 16
 controls.offset_right = -16
 for item: Array in [["View",func(): angle=(angle+1)%4; fit_camera()],["Detail",func(): view=(view+1)%4; fit_camera()],["Walk",func(): moving=not moving; motion_time=0.0; character.reset_motion()],["Cut",toggle_cut],["Caps",toggle_caps],["Hide",func(): controls.hide()]]:
  var button := Button.new()
  button.text = item[0]
  button.custom_minimum_size = Vector2(64,48)
  button.pressed.connect(item[1])
  controls.add_child(button)

func fit_camera() -> void:
 var viewport_size := get_viewport().get_visible_rect().size
 var columns := maxi(1,int((viewport_size.x-32.0)/68.0))
 controls.offset_top = -ceilf(6.0/columns)*52.0-16.0
 var centre := Vector3(3.65,0.9,0)
 var width := 8.9
 if view == 1: centre=character.position+Vector3.UP*0.4; width=1.65
 if view == 2: centre=Vector3(1.0,0.4,0); width=2.4
 if view == 3: centre=Vector3(6.1,0.4,0); width=2.4
 if sliced:
  centre=Vector3(2.0,0.5,0)
  width=4.8
 var yaw := deg_to_rad(-27+90*angle)
 camera.position=centre+Vector3(sin(yaw)*10,7,cos(yaw)*10)
 camera.look_at(centre)
 var aspect := get_viewport().get_visible_rect().size.aspect()
 camera.size=maxf(width/aspect,4.4 if view==0 and not sliced else (3.0 if sliced else 1.5))
 if view==0 and not sliced:
  var bounds := AABB(Vector3(-0.55,-0.1,-0.6),Vector3(8.65,2.55,1.2))
  var inverse := camera.basis.inverse()
  for index: int in 8:
   var corner := inverse*(bounds.get_endpoint(index)-centre)
   camera.size=maxf(camera.size,2.15*maxf(absf(corner.y),absf(corner.x)/aspect))


func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed:
  if event.keycode == KEY_H: controls.visible=not controls.visible
  if event.keycode == KEY_SPACE: moving=not moving
  if event.keycode == KEY_C: toggle_cut()
  if event.keycode in [KEY_Q,KEY_E]: angle=posmod(angle+(1 if event.keycode==KEY_E else -1),4); fit_camera()
 if event is InputEventScreenTouch and event.pressed and not controls.visible: controls.show()

func _process(delta:float)->void:
 if not moving: character.update_motion(delta,Vector3.ZERO); return
 motion_time += delta
 var t := fmod(motion_time,8.0)
 var old := character.position
 if t < 3.0: character.position.x=t*0.65
 elif t < 4.0: character.position.x=1.95
 elif t < 7.0: character.position.x=1.95-(t-4.0)*0.65
 else: character.position.x=0
 character.update_motion(delta,(character.position-old)/maxf(delta,0.001))

func toggle_cut()->void:
 cap_inspection=false
 stage.mirror.show()
 sliced=not sliced
 moving=false
 character.visible=not sliced
 for index: int in stage.blocks.size(): stage.blocks[index].visible=not sliced or index in [2,3]
 var normal := Vector3(1,0.35,0.2).normalized()
 var source_centre := stage.blocks[2].position+Vector3.UP*0.35
 var plane_centre := source_centre+normal*0.08
 if sliced:
  stage.mirror.position=plane_centre
  stage.mirror.basis=Basis.looking_at(normal,Vector3.UP)
 else: stage.mirror.transform=intact_mirror
 for index: int in [2,3]:
  var root: Node3D=stage.blocks[index]
  var core := root.find_child("*core*",true,false) as MeshInstance3D
  if core==null: continue
  if not original_meshes.has(index):
   original_meshes[index]=core.mesh
   original_transforms[index]=root.transform
  if not sliced:
   root.transform=original_transforms[index]
   core.mesh=original_meshes[index]
   core.material_override=Stage.Materials.build("ceramic" if index==2 else "reflected")
  else:
   var surface := Stage.Materials.build("ceramic" if index==2 else "reflected")
   var cap := StandardMaterial3D.new()
   cap.albedo_color=Color("d3c8ac") if index==2 else Color("b8ced6")
   cap.roughness=0.55
   if index==3:
    var reflection := Basis.IDENTITY
    reflection.x-=2*normal*normal.x
    reflection.y-=2*normal*normal.y
    reflection.z-=2*normal*normal.z
    root.transform=Transform3D(reflection,stage.blocks[2].position-2*normal*(normal.dot(stage.blocks[2].position-plane_centre)))
   core.material_override=null
   core.mesh=Cut.clip(original_meshes[index],Plane(Vector3(1,0.35,0.2).normalized(),0.08),surface,cap)

 fit_camera()

func toggle_caps()->void:
 if not sliced: toggle_cut()
 cap_inspection=not cap_inspection
 stage.blocks[3].visible=not cap_inspection
 stage.mirror.visible=not cap_inspection
 if cap_inspection: angle=2
 fit_camera()
