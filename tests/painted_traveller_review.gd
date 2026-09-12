extends SceneTree
## Short native review for Godot's --write-movie option, not a performance test.

var study: Node
var frame := 0


func _initialize() -> void:
	call_deferred("start")


func start() -> void:
	study = load("res://art_trial/painted_traveller_study.tscn").instantiate()
	root.add_child(study)
	study.controls.hide()
	study.set_view(0)


func _process(_delta: float) -> bool:
	if study == null:
		return false
	frame += 1
	match frame:
		30, 120, 195: study.blink_once()
		65: study.set_expression(3)
		90: study.set_hood_lowered(true); study.set_view(3)
		150: study.small_view = true; study.set_view(4)
		180: study.set_hood_lowered(false)
		240: quit()
	return false
