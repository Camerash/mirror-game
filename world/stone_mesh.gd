class_name StoneMesh
extends ArrayMesh
## The shape of a whole garden stone: a box with worn corners and a rounded
## foot, under a cover (snow, or moss on a copy) that rolls out over its edge.
## The top stays flat, at the box's height and inside its outline, so the
## walkable edge is where the grid says. The roll overhangs by `OVERHANG`.
##
## `CUSTOM0` carries the direction of the box face each vertex belongs to, so
## `stone.gdshader` paints a rounded stone by the same rules as a plain box.

## The radius of the stone's worn corners and foot, and of the cover's.
const WORN := 0.06
const COVER_WORN := 0.035
## How far the cover rolls out past the box, and how far down it hangs.
const OVERHANG := 0.045
const LIP := 0.06
const TURN_STEPS := 4

static var _made := {}

## The box this stone fills: the same box as its collision shape.
var size := Vector3.ONE

## Only a box with room for the worn corners gets the shape.
static func fits(box: Vector3) -> bool:
	return minf(box.x, minf(box.y, box.z)) >= 0.4

## The shared mesh for a box of this size.
static func of(box: Vector3) -> StoneMesh:
	var key := box.snappedf(0.001)
	if not _made.has(key):
		_made[key] = _make(box)
	return _made[key]

static func _make(box: Vector3) -> StoneMesh:
	var half := box * 0.5
	# Each row is one ring round the stone, from the top edge to the foot:
	# how far it stands out from the box, its height, its corner radius, its
	# normal (outward part, upward part), and the box face it is painted as.
	var rows := [
		[0.0, half.y, COVER_WORN, 0.0, 1.0, true],
		[OVERHANG * 0.7, half.y - 0.012, COVER_WORN, 0.6, 0.8, false],
		[OVERHANG, half.y - 0.035, COVER_WORN, 1.0, 0.1, false],
		[OVERHANG, half.y - LIP, COVER_WORN, 1.0, 0.0, false],
		[0.0, half.y - LIP - 0.022, WORN, 0.45, -0.9, false],
		[0.0, half.y - LIP - 0.023, WORN, 1.0, 0.0, false],
		[0.0, -half.y + WORN, WORN, 1.0, 0.0, false],
		[-WORN * 0.29, -half.y + WORN * 0.29, WORN, 0.707, -0.707, false],
		[-WORN, -half.y, WORN, 0.0, -1.0, false],
	]
	var around := 4 * (TURN_STEPS + 1)
	var points: Array = []
	for row: Array in rows:
		var ring: Array = []
		for index: int in around:
			var corner := index / (TURN_STEPS + 1)
			var angle := (float(corner) + float(index % (TURN_STEPS + 1)) / TURN_STEPS) * PI * 0.5
			var out := Vector3(cos(angle), 0.0, sin(angle))
			var radius: float = row[2]
			var centre := Vector3((half.x - radius) * (1.0 if corner in [0, 3] else -1.0), 0.0, (half.z - radius) * (1.0 if corner < 2 else -1.0))
			var face := Vector3.UP
			if not row[5]:
				face = Vector3(signf(out.x), 0.0, 0.0) if absf(out.x) >= absf(out.z) else Vector3(0.0, 0.0, signf(out.z))
			ring.append([centre + out * (radius + float(row[0])) + Vector3.UP * float(row[1]),
				(out * float(row[3]) + Vector3.UP * float(row[4])).normalized(), face])
		points.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
	for index: int in around:
		var next := (index + 1) % around
		_corner(tool, [[Vector3.UP * half.y, Vector3.UP, Vector3.UP], points[0][next], points[0][index]])
		_corner(tool, [[Vector3.DOWN * half.y, Vector3.DOWN, Vector3.DOWN], points[-1][index], points[-1][next]])
		for row: int in rows.size() - 1:
			_corner(tool, [points[row][index], points[row][next], points[row + 1][next]])
			_corner(tool, [points[row][index], points[row + 1][next], points[row + 1][index]])
	var mesh := StoneMesh.new()
	mesh.size = box
	tool.commit(mesh)
	return mesh

## Adds one triangle, wound so that it faces the way its normals point.
static func _corner(tool: SurfaceTool, triangle: Array) -> void:
	var a: Vector3 = triangle[0][0]
	var b: Vector3 = triangle[1][0]
	var c: Vector3 = triangle[2][0]
	var outward: Vector3 = triangle[0][1] + triangle[1][1] + triangle[2][1]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		triangle = [triangle[0], triangle[2], triangle[1]]
	for point: Array in triangle:
		tool.set_normal(point[1])
		tool.set_custom(0, Color(point[2].x, point[2].y, point[2].z))
		tool.add_vertex(point[0])
