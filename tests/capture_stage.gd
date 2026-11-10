extends SceneTree
## Captures one stage for art review. Not a test: it asserts nothing.
##   godot --path . --rendering-method mobile -s res://tests/capture_stage.gd -- --level 01_route --out /abs/dir
## Options: `--clean 1` hides the interface, `--turns 1` adds the three
## quarter turns, `--motion 1` adds six frames half a second apart,
## `--size 1600x1000`. In the cloud container, run it under `xvfb-run -a`.
## Writes plain.png (mirror down), mirror.png (mirror up), with motion
## motion0.png to motion5.png, and with turns turn1.png to turn3.png.
const Game := preload("res://game.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {}
	var list := OS.get_cmdline_user_args()
	for index: int in range(0, list.size() - 1, 2):
		args[list[index].trim_prefix("--")] = list[index + 1]
	var out := str(args.get("out", ProjectSettings.globalize_path("res://test-output/capture")))
	DirAccess.make_dir_recursive_absolute(out)
	var size := str(args.get("size", "1600x1000")).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	var game := Game.new()
	game.direct_controls = true
	root.add_child(game)
	var index := Game.LEVEL_PATHS.find("res://levels/" + str(args.get("level", "01_route")) + ".json")
	if index < 0 or not game.load_level(index):
		push_error("Unknown level")
		quit(1)
		return
	if args.has("clean"):
		game.set_overlay_visible(false)
	await create_timer(1.5).timeout
	await _save(out, "plain")
	game.toggle_mirror()
	await create_timer(2.5).timeout
	await _save(out, "mirror")
	if args.has("motion"):
		for frame: int in 6:
			await create_timer(0.5).timeout
			await _save(out, "motion%d" % frame)
	if args.has("turns"):
		for name: String in ["turn1", "turn2", "turn3"]:
			game.turn_camera(1)
			await create_timer(1.5).timeout
			await _save(out, name)
	quit(0)

func _save(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
