extends RefCounted

const Geometry := preload("res://core/world_geometry.gd")
const WalkGraph := preload("res://core/walk_graph.gd")

static func run(check: Callable) -> void:
	_test_clear_diagonal(check)
	_test_obstacle_detour(check)
	_test_gap(check)
	_test_diagonal_corner(check)
	_test_narrow_corridor(check)

static func _test_clear_diagonal(check: Callable) -> void:
	var world := _world([AABB(Vector3(-3, -1, -3), Vector3(6, 1, 6))])
	var route := _route(world, Vector3(-2, 0, -2), Vector3(2, 0, 2))
	check.call(route.size() == 2 and route[0].is_equal_approx(Vector3(-2, 0, -2)) \
			and route[1].is_equal_approx(Vector3(2, 0, 2)), "Clear diagonal keeps exact endpoints without a grid detour")

static func _test_obstacle_detour(check: Callable) -> void:
	var world := _world([
		AABB(Vector3(-3, -1, -3), Vector3(6, 1, 6)),
		AABB(Vector3(-0.35, 0, -1), Vector3(0.7, 1.5, 2)),
	])
	var route := _route(world, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	check.call(route.size() > 2 and _clear(route, world), "Obstacle detour keeps every route segment clear")

static func _test_gap(check: Callable) -> void:
	var world := _world([
		AABB(Vector3(-3, -1, -1), Vector3(2.5, 1, 2)),
		AABB(Vector3(0.5, -1, -1), Vector3(2.5, 1, 2)),
	])
	check.call(_route(world, Vector3(-2, 0, 0), Vector3(1.5, 0, 0)).is_empty(), "A gap has no walk route")

static func _test_diagonal_corner(check: Callable) -> void:
	var world := _world([
		AABB(Vector3(-1, -1, -1), Vector3(1, 1, 1)),
		AABB(Vector3(0, -1, 0), Vector3(1, 1, 1)),
	])
	check.call(_route(world, Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, 0.5)).is_empty(), "Diagonal-only platform contact has no route")

static func _test_narrow_corridor(check: Callable) -> void:
	var world := _world([
		AABB(Vector3(-3, -1, -3), Vector3(6, 1, 6)),
		AABB(Vector3(-0.35, 0, -3), Vector3(0.7, 1.5, 2.85)),
		AABB(Vector3(-0.35, 0, 0.15), Vector3(0.7, 1.5, 2.85)),
	])
	check.call(_route(world, Vector3(-2, 0, 0), Vector3(2, 0, 0)).is_empty(), "A corridor narrower than the capsule has no route")

static func _route(world: Array[Dictionary], start: Vector3, target: Vector3) -> PackedVector3Array:
	var graph := WalkGraph.new()
	graph.rebuild(world)
	return graph.route(start, target)

static func _world(bounds: Array[AABB]) -> Array[Dictionary]:
	var world: Array[Dictionary] = []
	for box: AABB in bounds:
		world.append({"bounds": box})
	return world

static func _clear(route: PackedVector3Array, world: Array[Dictionary]) -> bool:
	for index: int in range(route.size() - 1):
		if not Geometry.clear_segment(route[index], route[index + 1], world):
			return false
	return true
