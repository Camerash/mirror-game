extends Control
## Drawn in canvas coordinates. World input owns dragging and snapping.

var editing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(56, 56)

func _draw() -> void:
	var ink := Color("a75f45") if editing else Color("46666b")
	draw_circle(Vector2(28, 28), 26, Color("f4eddf"))
	draw_arc(Vector2(28, 28), 25, 0, TAU, 48, ink, 2.0, true)
	draw_line(Vector2(28, 14), Vector2(28, 42), ink, 2.0, true)
	draw_line(Vector2(13, 28), Vector2(23, 28), ink, 2.0, true)
	draw_line(Vector2(33, 28), Vector2(43, 28), ink, 2.0, true)
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(28 + side * 15, 28)
		draw_line(tip, tip + Vector2(-side * 5, -5), ink, 2.0, true)
		draw_line(tip, tip + Vector2(-side * 5, 5), ink, 2.0, true)
