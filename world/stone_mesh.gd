class_name StoneMesh
extends ArrayMesh
## The shape of a whole garden stone: a pedestal (a plinth, a rounder shaft
## and a cap slab) under a cover (snow, or moss on a copy) that rolls out over its edge.
## The top stays flat, at the box's height and inside its outline, so the
## walkable edge is where the grid says. The roll overhangs by `OVERHANG`.
##
## `CUSTOM0` carries the direction of the box face each vertex belongs to, so
## `stone.gdshader` paints a rounded stone by the same rules as a plain box.

## The corner radius of the snow or moss cover, and how far it rolls out past
## the box and hangs down.
const COVER_WORN := 0.07
const OVERHANG := 0.06
const LIP := 0.075
## The cap slab and the plinth are as wide as the box, with this corner
## radius; the cap is this high and the plinth's top is this far above the
## foot.
const CAP_WORN := 0.06
const CAP := 0.085
const PLINTH := 0.17
const FOOT_WORN := 0.05
## The shaft stands in this far from the box, with this corner radius.
const WAIST := 0.075
const SHAFT_WORN := 0.22
## An absolute's bronze band lies between these depths below the top
## (`stone.gdshader` paints and raises it).
const BAND: Array[float] = [0.34, 0.50]
const TURN_STEPS := 4
## The sides have a vertex about this often, for the dressing of the faces.
const GRAIN := 0.1

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
	# normal (outward part, upward part), and whether it is the flat top.
	var rows := [
		[0.0, half.y, COVER_WORN, 0.0, 1.0, true],
		[OVERHANG * 0.7, half.y - 0.012, COVER_WORN, 0.6, 0.8, false],
		[OVERHANG, half.y - 0.035, COVER_WORN, 1.0, 0.1, false],
		[OVERHANG, half.y - LIP, COVER_WORN, 1.0, 0.0, false],
	]
	var under_cover := half.y - LIP - 0.022
	var foot := -half.y + FOOT_WORN
	if box.y >= 0.8:
		# A tall stone is a pedestal: a cap slab as wide as the box, a
		# rounder shaft that stands in from it, and a plinth as wide as the
		# box. The shaft has rows and columns enough for `stone.gdshader` to
		# dress each face and to raise the band of an absolute (see its
		# `vertex`).
		var cap_foot := under_cover - CAP
		var plinth_top := -half.y + PLINTH
		rows.append([0.0, under_cover, CAP_WORN, 0.45, -0.9, false])
		rows.append([0.0, under_cover - 0.001, CAP_WORN, 1.0, 0.0, false])
		rows.append([0.0, cap_foot, CAP_WORN, 1.0, 0.0, false])
		rows.append([-WAIST * 0.6, cap_foot - 0.012, SHAFT_WORN, 0.5, -0.85, false])
		var heights: Array[float] = []
		var shaft_top := cap_foot - 0.035
		var shaft_foot := plinth_top + 0.035
		var shaft_rows := ceili((shaft_top - shaft_foot) / GRAIN)
		for index: int in shaft_rows + 1:
			heights.append(lerpf(shaft_top, shaft_foot, float(index) / shaft_rows))
		# The band of an absolute needs a row at each of its edges.
		for edge: float in BAND:
			for side: float in [-0.004, 0.004]:
				heights.append(half.y - edge + side)
		heights.sort()
		heights.reverse()
		for height: float in heights:
			if height <= shaft_top and height >= shaft_foot:
				rows.append([-WAIST, height, SHAFT_WORN, 1.0, 0.0, false])
		rows.append([-WAIST * 0.6, plinth_top + 0.012, SHAFT_WORN, 0.6, 0.8, false])
		rows.append([0.0, plinth_top, CAP_WORN, 0.3, 0.95, false])
		rows.append([0.0, plinth_top - 0.001, CAP_WORN, 1.0, 0.0, false])
	else:
		rows.append([0.0, under_cover, CAP_WORN, 0.45, -0.9, false])
		rows.append([0.0, under_cover - 0.001, CAP_WORN, 1.0, 0.0, false])
	rows.append([0.0, foot, CAP_WORN, 1.0, 0.0, false])
	rows.append([-FOOT_WORN * 0.29, -half.y + FOOT_WORN * 0.29, CAP_WORN, 0.707, -0.707, false])
	rows.append([-FOOT_WORN, -half.y, CAP_WORN, 0.0, -1.0, false])
	# The path round the stone: a quarter turn at each corner, then the
	# straight side to the next corner. Each point is a corner, an angle on
	# it, and how far along the side to the next corner it lies.
	var path: Array = []
	for corner: int in 4:
		for step: int in TURN_STEPS + 1:
			path.append([corner, (float(corner) + float(step) / TURN_STEPS) * PI * 0.5, 0.0])
		var side_length := (box.x if corner % 2 == 0 else box.z) - 2.0 * CAP_WORN
		var columns := ceili(side_length / GRAIN)
		for step: int in range(1, columns):
			path.append([corner, float(corner + 1) * PI * 0.5, float(step) / columns])
	var around := path.size()
	var points: Array = []
	for row: Array in rows:
		var ring: Array = []
		for spot: Array in path:
			var out := Vector3(cos(spot[1]), 0.0, sin(spot[1]))
			var place := _corner_centre(half, spot[0], row[2]) + out * (float(row[2]) + float(row[0]))
			if spot[2] > 0.0:
				place = place.lerp(_corner_centre(half, (int(spot[0]) + 1) % 4, row[2]) + out * (float(row[2]) + float(row[0])), spot[2])
			var face := Vector3.UP
			if not row[5]:
				face = Vector3(signf(out.x), 0.0, 0.0) if absf(out.x) >= absf(out.z) else Vector3(0.0, 0.0, signf(out.z))
			ring.append([place + Vector3.UP * float(row[1]), (out * float(row[3]) + Vector3.UP * float(row[4])).normalized(), face])
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

static func _corner_centre(half: Vector3, corner: int, radius: float) -> Vector3:
	return Vector3((half.x - radius) * (1.0 if corner in [0, 3] else -1.0), 0.0, (half.z - radius) * (1.0 if corner < 2 else -1.0))

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
