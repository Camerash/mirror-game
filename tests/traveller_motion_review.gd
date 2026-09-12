extends SceneTree
## Native recording: --write-movie .local/traveller.avi --fixed-fps 30
var scene: Node3D
var elapsed := 0.0
var close_view := false

func _initialize() -> void:
 call_deferred("start")

func start() -> void:
 scene = load("res://art_trial/reference_scene.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 scene.controls.hide()

func _process(delta: float) -> bool:
 if scene == null: return false
 elapsed += delta
 if elapsed >= 8.0:
  quit()
  return false
 if elapsed >= 4.0 and not close_view:
  close_view = true
  scene.character.reset_motion()
  scene.character.position = Vector3(0,0.7,0)
  scene.view = 1
  scene.fit_camera()
  var centre := Vector3(0.30,1.10,0)
  scene.camera.position = centre + Vector3(-4.54,7,8.91)
  scene.camera.look_at(centre)
  scene.camera.size = 1.65
 var t := fmod(elapsed,4.0)
 var velocity := Vector3.ZERO
 if t >= 0.4 and t < 1.4: velocity.x = 0.65
 if t >= 1.8 and t < 2.8: velocity.x = -0.65
 scene.character.position += velocity * delta
 scene.character.update_motion(delta,velocity)
 return false
