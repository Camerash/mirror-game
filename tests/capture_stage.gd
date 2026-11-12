extends SceneTree
## Captures one stage for art review. Not a test: it asserts nothing.
##   godot --path . --rendering-method mobile -s res://tests/capture_stage.gd -- --level 01_route --out /abs/dir
## Options: `--clean 1` hides the interface, `--turns 1` adds the three
## quarter turns, `--motion 1` adds six frames half a second apart,
## `--nudge 0.5` then slides the mirror that far along X and writes cut.png,
## `--rise 0.9` writes rise.png that many seconds after the mirror is raised,
## `--sink 0.4` lowers the mirror at the end and writes sink.png that many
## seconds later, `--size 1600x1000`. In the cloud container, run it under
## `xvfb-run -a`.
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
	if args.has("rise"):
		await create_timer(float(args["rise"])).timeout
		await _save(out, "rise")
	await create_timer(2.5).timeout
	if not game.mirror.get("enabled", false):
		# A slow first frame can refuse the first raise.
		game.toggle_mirror()
		await create_timer(2.5).timeout
	await _save(out, "mirror")
	if args.has("nudge"):
		# A half step along X leaves the mirror through the middle of a block.
		game.nudge_mirror(0, float(args["nudge"]))
		await create_timer(2.5).timeout
		await _save(out, "cut")
	if args.has("motion"):
		for frame: int in 6:
			await create_timer(0.5).timeout
			await _save(out, "motion%d" % frame)
	if args.has("turns"):
		for name: String in ["turn1", "turn2", "turn3"]:
			game.turn_camera(1)
			await create_timer(1.5).timeout
			await _save(out, name)
	if args.has("sink"):
		game.toggle_mirror()
		await create_timer(float(args["sink"])).timeout
		await _save(out, "sink")
	quit(0)

func _save(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
