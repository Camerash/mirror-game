extends SceneTree
## Native review of the traveller in the game.
##
## Run without --headless:
##   godot --path . --script tests/traveller_gameplay_review.gd
## Saves frames to the ignored test-output/ directory.

const Game := preload("res://game.gd")

var game: Node3D
var elapsed := 0.0
var shot := 0
var shots: Array[float] = [0.6, 1.1, 1.6, 2.1, 2.6]


func _initialize() -> void:
	call_deferred("start")


func start() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var guard := FileAccess.open("res://test-output/.gdignore", FileAccess.WRITE)
	if guard != null:
		guard.close()
	game = Game.new()
	root.add_child(game)


func _process(delta: float) -> bool:
	if game == null:
		return false
	elapsed += delta
	if elapsed < 0.4:
		return false
	# The character walks on the spot and turns, so every frame is comparable
	# and the camera does not have to chase it. Position is deliberately not
	# advanced: this reviews the visual, not the navigation.
	var speed := 2.0
	var turn := (elapsed - 0.4) * 1.2
	var heading := Vector3(sin(turn), 0.0, cos(turn))
	var movement := heading * speed
	if game.walker.character_visual != null:
		game.walker.character_visual.update_motion(delta, movement, true, false)
	if shot < shots.size() and elapsed >= shots[shot]:
		var image := root.get_texture().get_image()
		image.save_png("res://test-output/gameplay-traveller-%d.png" % shot)
		shot += 1
	if elapsed > 3.2:
		print("Saved %d frames to test-output/." % shot)
		quit()
	return false
