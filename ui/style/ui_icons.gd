class_name UiIcons
extends RefCounted
## The one icon set: drawn strokes of one weight with round ends, on a 24-unit
## grid, in one colour. Icons replace words in the interface.

const NAMES: Array[String] = ["mirror", "mirror_raised", "undo", "turn_left", "turn_right",
	"settings", "help", "restart", "close"]
## Stroke width in grid units.
const WEIGHT := 1.9


## A round icon button in the style's frost, drawing `icon` with UiStyle.INK.
## `primary` makes it the larger main action.
static func button(icon: String, tooltip := "", primary := false) -> Button:
	var item := Button.new()
	item.theme_type_variation = "PrimaryButton" if primary else "IconButton"
	var extent := UiStyle.PRIMARY if primary else UiStyle.TOUCH
	item.custom_minimum_size = Vector2(extent, extent)
	item.tooltip_text = tooltip
	item.focus_mode = Control.FOCUS_NONE
	item.set_meta("icon", icon)
	item.draw.connect(func() -> void:
		var side := minf(item.size.x, item.size.y) * 0.5
		var ink := Color(UiStyle.INK, 0.4 if item.disabled else 1.0)
		draw(item, str(item.get_meta("icon")), Rect2(item.size * 0.5 - Vector2.ONE * side * 0.5, Vector2.ONE * side), ink))
	return item


## Draws `icon` into `rect` on `canvas`.
static func draw(canvas: CanvasItem, icon: String, rect: Rect2, color: Color) -> void:
	var scale := rect.size.x / 24.0
	var at := func(x: float, y: float) -> Vector2: return rect.position + Vector2(x, y) * scale
	var width := WEIGHT * scale
	match icon:
		"mirror", "mirror_raised":
			var glass := Rect2(at.call(7.0, 3.0), Vector2(10, 16) * scale)
			if icon == "mirror_raised":
				canvas.draw_rect(glass, Color(color, 0.16), true)
				_stroke(canvas, [at.call(9.5, 14.0), at.call(14.5, 7.0)], color, width * 0.8)
			_stroke(canvas, _rounded(glass, 2.0 * scale), color, width)
			_stroke(canvas, [at.call(4.0, 21.5), at.call(20.0, 21.5)], color, width)
		"undo":
			# The usual undo hook: an arrow back to the left, its tail curling down.
			var hook := PackedVector2Array([at.call(5.0, 9.0), at.call(14.0, 9.0)])
			hook.append_array(_arc(at.call(14.0, 13.5), 4.5 * scale, Vector2(1, 1), -90.0, 90.0))
			hook.append(at.call(9.0, 18.0))
			_stroke(canvas, hook, color, width)
			_stroke(canvas, [at.call(9.0, 5.0), at.call(5.0, 9.0), at.call(9.0, 13.0)], color, width)
		"turn_left", "turn_right":
			var direction := -1.0 if icon == "turn_left" else 1.0
			var orbit := PackedVector2Array()
			for step: int in 33:
				var angle := deg_to_rad(lerpf(25.0, -265.0, step / 32.0))
				orbit.append(at.call(12.0 + cos(angle) * 9.0 * direction, 12.0 + sin(angle) * 4.5))
			_stroke(canvas, orbit, color, width)
			var base := orbit[orbit.size() - 1]
			canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(direction * 4.0, 0) * scale,
				base + Vector2(0, -3.0) * scale, base + Vector2(0, 3.0) * scale]), color)
		"settings":
			for row: int in 3:
				var y := 6.0 + row * 6.0
				_stroke(canvas, [at.call(4.0, y), at.call(20.0, y)], color, width)
				var knob: Vector2 = at.call([15.0, 8.0, 13.0][row], y)
				canvas.draw_circle(knob, 2.6 * scale, color)
		"help":
			var hook := _arc(at.call(12.0, 9.0), 4.0 * scale, Vector2(1, 1), 190.0, 405.0)
			hook.append(at.call(12.0, 15.0))
			_stroke(canvas, hook, color, width)
			canvas.draw_circle(at.call(12.0, 19.5), width * 0.75, color)
		"restart":
			# Back to the start: a bar and a path running back to it.
			_stroke(canvas, [at.call(5.5, 5.0), at.call(5.5, 19.0)], color, width)
			_stroke(canvas, [at.call(19.0, 12.0), at.call(9.5, 12.0)], color, width)
			_stroke(canvas, [at.call(13.5, 7.5), at.call(9.0, 12.0), at.call(13.5, 16.5)], color, width)
		"close":
			_stroke(canvas, [at.call(6.0, 6.0), at.call(18.0, 18.0)], color, width)
			_stroke(canvas, [at.call(18.0, 6.0), at.call(6.0, 18.0)], color, width)


## A polyline with round joins and ends.
static func _stroke(canvas: CanvasItem, points: Variant, color: Color, width: float) -> void:
	var line := PackedVector2Array(points)
	canvas.draw_polyline(line, color, width, true)
	for point: Vector2 in line:
		canvas.draw_circle(point, width * 0.5, color)


static func _arc(centre: Vector2, radius: float, squash: Vector2, from_degrees: float, to_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(8, ceili(absf(to_degrees - from_degrees) / 8.0))
	for step: int in steps + 1:
		var angle := deg_to_rad(lerpf(from_degrees, to_degrees, float(step) / steps))
		points.append(centre + Vector2(cos(angle) * squash.x, sin(angle) * squash.y) * radius)
	return points


static func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for index: int in 4:
		for step: int in 5:
			var angle := deg_to_rad(180.0 + index * 90.0 + step * 22.5)
			points.append(corners[index] + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])
	return points
