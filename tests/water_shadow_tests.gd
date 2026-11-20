extends SceneTree
## The shadow on the water: each stone and each copy has one soft shadow
## straight below it. The tests check the rules, not the look.

const Game := preload("res://game.gd")
const Geometry := preload("res://core/world_geometry.gd")
const WaterShadow := preload("res://world/water_shadow.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func square(corner: Vector2, clockwise: bool) -> PackedVector2Array:
	var points := PackedVector2Array([corner, corner + Vector2(1, 0), corner + Vector2(1, 1), corner + Vector2(0, 1)])
	if clockwise:
		points.reverse()
	return points


func bounds_of(outline: PackedVector2Array) -> Rect2:
	var rect := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		rect = rect.expand(point)
	return rect


func run() -> void:
	root.size = Vector2i(1152, 800)
	check_reach()
	check_layers()
	for path: String in Game.PUZZLE_PATHS:
		await check_place(path)
	print("Water shadow tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_reach() -> void:
	check(is_equal_approx(WaterShadow.reach(0.1), 0.05), "A low stone has the least reach")
	check(is_equal_approx(WaterShadow.reach(2.0), 0.3), "A stone 2 units high has a reach of 0.3")
	check(is_equal_approx(WaterShadow.reach(10.0), 0.45), "A high stone has the greatest reach")


func check_layers() -> void:
	for clockwise: bool in [false, true]:
		var corner := Vector2.ZERO
		var result := WaterShadow.layers([{"outline": square(corner, clockwise), "height": 2.0}] as Array[Dictionary])
		check(not result.is_empty(), "A stone gives layers")
		if result.is_empty():
			continue
		check(is_equal_approx(result[-1]["shade"], 1.0), "The last layer is the footprint")
		check(bounds_of(result[-1]["outline"]).size.is_equal_approx(Vector2.ONE), "The darkest layer is the footprint")
		for index: int in range(1, result.size()):
			check(result[index]["shade"] >= result[index - 1]["shade"], "The shades never go down in draw order")
		for layer: Dictionary in result:
			check(float(layer["shade"]) > 0.0, "A layer with no shade is not drawn")
			for point: Vector2 in square(corner, false):
				check(Geometry2D.is_point_in_polygon(point.lerp(Vector2(0.5, 0.5), 0.001), layer["outline"]), "A grown outline holds the footprint")
		var lightest := bounds_of(result[0]["outline"])
		for edge: float in [-lightest.position.x, -lightest.position.y, lightest.end.x - 1.0, lightest.end.y - 1.0]:
			check(edge > 0.2 and edge <= 0.3, "The lightest layer is wider by 0.2 to 0.3 on each side (%.3f)" % edge)
	var flat := WaterShadow.layers([{"outline": square(Vector2.ZERO, false), "height": 0.0}] as Array[Dictionary])
	check(flat.is_empty(), "A shape at the water gives no layer")
	var two := WaterShadow.layers([
		{"outline": square(Vector2.ZERO, false), "height": 1.0},
		{"outline": square(Vector2(5, 0), false), "height": 3.0},
	] as Array[Dictionary])
	var ordered := true
	for index: int in range(1, two.size()):
		ordered = ordered and two[index]["shade"] >= two[index - 1]["shade"]
	check(ordered and two.size() > 2, "Layers of two shapes are in order of shade across both")


func check_place(path: String) -> void:
	var game := Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	for index: int in 2:
		await process_frame
	check(game.load_level(Game.LEVEL_PATHS.find(path)), "Loads " + path)
	for index: int in 200:
		await process_frame
	var floor_height: float = game.trial_lighting.floor_height
	var lowest := Geometry.total_bounds(game.world.drawn_solids).position.y
	check(is_equal_approx(floor_height, lowest - 2.0), "%s: the stage floats 2 units over the water (%.2f, %.2f)" % [path, floor_height, lowest])
	check(float(game.level["kill_y"]) < floor_height, "%s: a fall ends below the water" % path)
	var plane := game.world.water_shadow.get_child(-1) as MeshInstance3D
	check(plane != null and plane.visible, "%s: the water shadow is shown" % path)
	if plane != null:
		check(is_equal_approx(plane.position.y, floor_height + WaterShadow.LIFT), "%s: the water shadow lies on the water" % path)
	game.queue_free()
	await process_frame
