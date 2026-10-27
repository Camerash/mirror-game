extends SceneTree
## Renders the look pilot diorama in one or more looks, with the game's
## orthographic camera (30 degrees down, four quarter-turn views).
## Needs a display; on Linux run under xvfb-run with the Mobile renderer:
##   godot --path . --rendering-method mobile -s res://art_trial/look_pilot/capture.gd -- --looks greybox,ceramic --out /abs/dir
## Writes <look>_hero.png (1600x1000, view 1, framed as the game frames a
## stage) and <look>_views.png (the four views).

const Diorama := preload("res://art_trial/look_pilot/diorama.gd")
const LOOKS := {
	"greybox": preload("res://art_trial/look_pilot/look.gd"),
}
const LOOK_DIR := "res://art_trial/look_pilot/looks/"
const ELEVATION := PI / 6.0
const HERO := Vector2i(1600, 1000)
const VIEW := Vector2i(800, 500)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var out := str(args.get("out", ProjectSettings.globalize_path("res://test-output/look_pilot")))
	DirAccess.make_dir_recursive_absolute(out)
	for name: String in str(args.get("looks", "greybox")).split(","):
		var script: Script = LOOKS.get(name, null)
		if script == null:
			script = load(LOOK_DIR + name + ".gd")
		if script == null:
			push_error("Unknown look: " + name)
			quit(1)
			return
		var diorama := Diorama.new()
		root.add_child(diorama)
		diorama.build(script.new())
		var framed := diorama.outline()
		var hero := await _render(HERO, PI * 0.25, framed)
		hero.save_png(out.path_join(name + "_hero.png"))
		var sheet := Image.create(VIEW.x * 2, VIEW.y * 2, false, Image.FORMAT_RGBA8)
		for index: int in 4:
			var image := await _render(VIEW, PI * (0.25 + 0.5 * index), framed)
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, VIEW), Vector2i(index % 2, index / 2) * VIEW)
		sheet.save_png(out.path_join(name + "_views.png"))
		diorama.queue_free()
		await process_frame
		print("rendered ", name)
	quit(0)

func _parse(list: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(0, list.size() - 1, 2):
		result[list[index].trim_prefix("--")] = list[index + 1]
	return result

func _render(size: Vector2i, yaw: float, points: PackedVector3Array) -> Image:
	var direction := Vector3(cos(yaw) * cos(ELEVATION), sin(ELEVATION), sin(yaw) * cos(ELEVATION))
	var view := Basis.looking_at(-direction, Vector3.UP)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector3 in points:
		var corner := view.inverse() * point
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	var extent := high - low
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(extent.y, extent.x * float(size.y) / float(size.x)) * 1.1
	camera.far = 200.0
	viewport.add_child(camera)
	root.add_child(viewport)
	var centre := view * Vector3((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, 0.0)
	camera.global_transform = Transform3D(view, centre + direction * 50.0)
	camera.current = true
	for frame: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image
