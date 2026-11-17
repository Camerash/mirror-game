class_name MirrorBar
extends Node3D
## The control of the mirror in the direct controls (owner's design,
## 2026-11-17): a glass bar below the stage. Before the mirror is up, the bar
## is one round mirror button. A press opens it slowly into three knobs: move,
## turn, lift. A knob is held, and the finger then uses the full screen: the
## distance from the press gives the amount. A round rose button beside the
## bar lowers the mirror. The bar is glass; each button is opaque white, as
## glazed ceramic. Drawn in screen space; the game owns the state change.
signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const INK := Color(0.20, 0.25, 0.27, 0.9)

class BarOverlay extends Control:
	var bar: MirrorBar
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if bar != null:
			bar._draw_bar(self)

var _state: Dictionary = {}
var _available := false
var _busy := false
var _camera: Camera3D
var _active := false
var _pointer := -2
var _canvas := CanvasLayer.new()
var _overlay := BarOverlay.new()

## One step of a turn or a tilt.
const AIM_STEP := PI * 0.25
const KNOBS: Array[String] = ["move", "turn", "lift"]
const HALF_HEIGHT := 39.0
const KNOB := 29.0
const SPACING := 70.0
const BUTTON := 33.0
const REMOVE := 23.0
const OPEN_SECONDS := 0.85
## How far a held knob moves toward the drag, and the drag that takes it to
## about two thirds of that: the resistance grows near the limit.
const PULL_LIMIT := 6.0
const PULL_SOFTNESS := 90.0
## The slide that turns or tilts the mirror one step of 45 degrees.
const TURN_PIXELS := 96.0
const CERAMIC := Color(0.985, 0.98, 0.965)
const ROSE := Color(0.94, 0.72, 0.70)
const ROSE_INK := Color(0.45, 0.24, 0.24)
const GLASS := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 size = vec2(200.0, 100.0);
uniform vec2 half_size = vec2(80.0, 30.0);

float capsule(vec2 p, out vec2 normal) {
	float r = half_size.y;
	vec2 q = vec2(max(abs(p.x) - (half_size.x - r), 0.0), p.y);
	float l = length(q);
	normal = l > 0.001 ? vec2(sign(p.x) * q.x, q.y) / l : vec2(0.0);
	return l - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 n;
	float d = capsule(p, n);
	float inside = 1.0 - smoothstep(-1.0, 0.4, d);
	// The rim bends the world behind it, as a thick glass edge does.
	float rim = smoothstep(-half_size.y * 0.8, 0.0, d);
	float bend = rim * rim * rim;
	vec2 uv = SCREEN_UV - n * bend * 22.0 * SCREEN_PIXEL_SIZE;
	vec3 back = textureLod(screen, uv, 2.4).rgb;
	vec3 colour = mix(back, vec3(1.0), 0.13 + 0.12 * bend - 0.04 * p.y / half_size.y);
	// A bright line on the upper edge and a fainter one on the lower edge.
	float edge = smoothstep(-2.6, -0.6, d);
	colour += vec3(1.0) * edge * (0.50 * clamp(-n.y, 0.0, 1.0) + 0.20 * clamp(n.y, 0.0, 1.0) + 0.07);
	// A soft shadow below the bar.
	vec2 unused;
	float below = capsule(p - vec2(0.0, 6.0), unused);
	float shadow = (1.0 - smoothstep(-8.0, 18.0, below)) * 0.20 * (1.0 - inside);
	COLOR = vec4(mix(vec3(0.10, 0.13, 0.16), colour, inside), max(inside, shadow));
}
"""
## Set by the game each frame: whether the bar shows, where its centre is,
## and whether the mirror can go up or down now.
var shown := false
var centre := Vector2.ZERO
var can_toggle := false
var _grip := ""
var _started := false
var _cancelled := false
var _grip_press := Vector2.ZERO
var _grip_point := Vector2.ZERO
var _grip_yaw := 0.0
var _grip_pitch := 0.0
var _tilt_sign := 1.0
## 0 is the mirror button, 1 is the open bar.
var _open := 0.0
var _pull := Vector2.ZERO
var _pull_velocity := Vector2.ZERO
var _pull_knob := ""
var _tick := 0.0
## A slide that was made and released while the last change still settled.
var _queued: Dictionary = {}
var _glass := ColorRect.new()
var _glass_material := ShaderMaterial.new()

func _ready() -> void:
	_canvas.layer = 2
	add_child(_canvas)
	var shader := Shader.new()
	shader.code = GLASS
	_glass_material.shader = shader
	_glass.material = _glass_material
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.visible = false
	_canvas.add_child(_glass)
	_overlay.bar = self
	_canvas.add_child(_overlay)

func set_state(state: Dictionary, available: bool, busy: bool) -> void:
	_state = state
	_available = available and state.has("pivot") and bool(state.get("enabled", false))
	_busy = busy
	if not _available and _active and _grip not in ["mirror", "remove"]:
		cancel()
	_overlay.queue_redraw()

func update_view(camera: Camera3D) -> void:
	_camera = camera
	_overlay.queue_redraw()

## Hides the bar's own 2D layer. `visible` on this Node3D would not do it:
## a CanvasLayer renders on its own, independent of a 3D ancestor.
func set_overlay_visible(value: bool) -> void:
	_canvas.visible = value

func is_active() -> bool:
	return _active

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func blocks_point(point: Vector2) -> bool:
	return _on_bar(point)

func pointer(point: Vector2, pressed: bool, index: int) -> bool:
	if not pressed:
		if owns_pointer(index):
			_finish()
			return true
		return false
	return _press(point, index)

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	_grip_point = point
	if _started:
		_move_grip()
	_overlay.queue_redraw()
	return true

func cancel(keep_waiting := false) -> void:
	if keep_waiting and _grip in KNOBS and not _started:
		return
	if _active:
		_cancelled = true
		_finish()
		_cancelled = false

func _finish() -> void:
	_active = false
	_pointer = -2
	var kind := _grip
	var started := _started
	_grip = ""
	_started = false
	if kind in KNOBS:
		if started:
			action_requested.emit("grip_end", kind)
		elif not _cancelled and _grip_point.distance_to(_grip_press) > 4.0:
			_queued = {"kind": kind, "press": _grip_press, "point": _grip_point}
	elif not _cancelled and _grip_at(_grip_point) == kind:
		action_requested.emit("mirror_toggle", null)
	_overlay.queue_redraw()

func _yaw() -> float:
	return float(Rules.normalized(_state)["yaw"])

func _pitch() -> float:
	return float(Rules.normalized(_state)["pitch"])

func _eased() -> float:
	# Slow at each end, so the button opens and closes quietly.
	return _open * _open * _open * (_open * (_open * 6.0 - 15.0) + 10.0)

func _half_width(open: float) -> float:
	return lerpf(BUTTON + 6.0, SPACING + KNOB + 10.0, open)

func _remove_point() -> Vector2:
	return centre + Vector2(_half_width(1.0) + 15.0 + REMOVE, 0.0)

## Whether the bar is below the point. The bar takes each press on it, so a
## press there never walks.
func _on_bar(point: Vector2) -> bool:
	if not shown or _camera == null:
		return false
	var local := point - centre
	if absf(local.y) <= HALF_HEIGHT + 6.0 and absf(local.x) <= _half_width(_eased()) + 6.0:
		return true
	return _open > 0.5 and point.distance_to(_remove_point()) <= REMOVE + 8.0

## The control below the point: a knob, the mirror button or the remove
## button. Empty while the bar opens or closes.
func _grip_at(point: Vector2) -> String:
	if not _on_bar(point):
		return ""
	if not _available:
		return "mirror" if _open < 0.5 else ""
	if _open < 0.7:
		return ""
	if point.distance_to(_remove_point()) <= REMOVE + 8.0:
		return "remove"
	return KNOBS[clampi(roundi((point.x - centre.x) / SPACING), -1, 1) + 1]

func _press(point: Vector2, index: int) -> bool:
	if _active or not _on_bar(point):
		return false
	var kind := _grip_at(point)
	if kind.is_empty() or (kind not in KNOBS and not can_toggle):
		return true
	_active = true
	_pointer = index
	_grip = kind
	_grip_press = point
	_grip_point = point
	_started = false
	if kind in KNOBS:
		_pull_knob = kind
		_start_knob()
	_overlay.queue_redraw()
	return true

## The held knob starts its change. A knob pressed while the last change
## still settles waits here, so a fast second drag is not lost.
func _start_knob() -> void:
	if _busy:
		return
	_started = true
	_grip_yaw = _yaw()
	_grip_pitch = _pitch()
	# A slide up moves the top edge away from the viewer. Seen edge-on, the
	# top edge goes to the right.
	var away := Basis(Vector3.UP, _grip_yaw).z
	var forward := -_camera.global_basis.z
	var depth := away.dot(Vector3(forward.x, 0.0, forward.z).normalized())
	_tilt_sign = signf(depth) if absf(depth) > 0.1 else (1.0 if away.dot(_camera.global_basis.x) >= 0.0 else -1.0)
	action_requested.emit("grip_begin", {"kind": _grip, "point": _grip_press})
	# The slide made while the knob waited counts from the press.
	if not _grip_point.is_equal_approx(_grip_press):
		_move_grip()

## Makes the slide that waited, as one complete change.
func _run_queued() -> void:
	if _busy or not _available:
		return
	var held := {"kind": _grip, "press": _grip_press, "point": _grip_point, "started": _started}
	_grip = _queued["kind"]
	_grip_press = _queued["press"]
	_grip_point = _queued["point"]
	_queued = {}
	_started = false
	_start_knob()
	action_requested.emit("grip_end", _grip)
	_grip = held["kind"]
	_grip_press = held["press"]
	_grip_point = held["point"]
	_started = false
	# The game is busy from this change now; the next frame's state says so.
	_busy = true

func _move_grip() -> void:
	if _grip != "turn":
		action_requested.emit("grip_drag", _grip_point)
		return
	var drag := _grip_point - _grip_press
	action_requested.emit("grip_aim", {
		"yaw": _grip_yaw + drag.x / TURN_PIXELS * AIM_STEP,
		"pitch": clampf(_grip_pitch - drag.y / TURN_PIXELS * AIM_STEP * _tilt_sign, -PI * 0.5, PI * 0.5)})

## The mirror went to its next step: the held knob answers.
func tick() -> void:
	_tick = 1.0
	Input.vibrate_handheld(10)

func _process(delta: float) -> void:
	var drawn := shown and _camera != null
	_glass.visible = drawn
	if not drawn:
		return
	var before := _open
	_open = move_toward(_open, 1.0 if _available else 0.0, delta / OPEN_SECONDS)
	if not _queued.is_empty():
		_run_queued()
	elif _grip in KNOBS and not _started:
		_start_knob()
	var moving := not is_equal_approx(before, _open) or _tick > 0.0
	if _grip in KNOBS:
		var drag := _grip_point - _grip_press
		var target := Vector2.ZERO
		if drag.length() > 0.5:
			target = drag.normalized() * PULL_LIMIT * (1.0 - exp(-drag.length() / PULL_SOFTNESS))
		_pull = _pull.lerp(target, 1.0 - exp(-delta * 28.0))
		_pull_velocity = Vector2.ZERO
		moving = true
	elif _pull.length() > 0.02 or _pull_velocity.length() > 0.5:
		# The knob springs back to its place.
		_pull_velocity += (-_pull * 420.0 - _pull_velocity * 36.0) * delta
		_pull += _pull_velocity * delta
		moving = true
	else:
		_pull = Vector2.ZERO
	_tick = move_toward(_tick, 0.0, delta / 0.2)
	var half := Vector2(_half_width(_eased()), HALF_HEIGHT)
	_glass.size = (half + Vector2(30.0, 30.0)) * 2.0
	_glass.position = centre + _pull * 0.15 - _glass.size * 0.5
	_glass_material.set_shader_parameter("size", _glass.size)
	_glass_material.set_shader_parameter("half_size", half)
	if moving:
		_overlay.queue_redraw()

func _draw_bar(canvas: Control) -> void:
	if not shown or _camera == null:
		return
	var open := _eased()
	var middle := centre + _pull * 0.15
	var holding := _grip in KNOBS
	for index: int in [0, 2, 1]:
		var kind := KNOBS[index]
		var alpha := 1.0 if index == 1 else smoothstep(0.1, 0.7, open)
		if alpha <= 0.01:
			continue
		if holding and _grip != kind:
			alpha *= 0.78
		var held := _grip == kind or (index == 1 and _grip == "mirror")
		var radius := lerpf(BUTTON, KNOB, open) if index == 1 else KNOB
		_set_ceramic(canvas, middle + Vector2((index - 1) * SPACING * open, 0.0), radius, CERAMIC, alpha,
			_pull if _pull_knob == kind else Vector2.ZERO, held, _tick if held else 0.0)
		if index == 1 and open < 0.5:
			_draw_mark(canvas, "mirror", radius, Color(INK, 1.0 - smoothstep(0.0, 0.45, open)))
		else:
			_draw_mark(canvas, kind, radius, Color(INK, alpha * (smoothstep(0.55, 1.0, open) if index == 1 else 1.0)))
	var out := smoothstep(0.55, 1.0, open)
	if out > 0.01:
		var from := centre + Vector2(_half_width(open) - REMOVE, 0.0)
		_set_ceramic(canvas, from.lerp(_remove_point(), out), REMOVE, ROSE, out * (0.78 if holding else 1.0), Vector2.ZERO, _grip == "remove", 0.0)
		_draw_mark(canvas, "remove", REMOVE, Color(ROSE_INK, out))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

## Draws one opaque round button, as glazed ceramic, and leaves the canvas
## in the button's frame for its mark. `pull` moves the button toward a drag
## and makes it longer that way.
func _set_ceramic(canvas: Control, at: Vector2, radius: float, colour: Color, alpha: float, pull: Vector2, pressed: bool, pulse: float) -> void:
	var amount := clampf(pull.length() / PULL_LIMIT, 0.0, 1.0)
	var angle := pull.angle() if amount > 0.001 else 0.0
	var grow := 1.0 + (0.03 if pressed else 0.0) + 0.04 * pulse
	var matrix := Transform2D(angle, Vector2.ZERO) * Transform2D.IDENTITY.scaled(Vector2(1.0 + 0.06 * amount, 1.0 - 0.025 * amount) * grow) * Transform2D(-angle, Vector2.ZERO)
	matrix.origin = at + pull
	canvas.draw_set_transform_matrix(matrix)
	for layer: int in 4:
		canvas.draw_circle(Vector2(0.0, 2.0 + layer * 1.2), radius + layer * 1.3, Color(0.10, 0.13, 0.16, 0.055 * alpha), true, -1.0, true)
	var body := Color(1.0, 1.0, 1.0) if pressed and colour == CERAMIC else (colour.lightened(0.08) if pressed else colour)
	canvas.draw_circle(Vector2.ZERO, radius, Color(body.darkened(0.08), alpha), true, -1.0, true)
	canvas.draw_circle(Vector2(0.0, -radius * 0.07), radius * 0.94, Color(body, alpha), true, -1.0, true)
	canvas.draw_circle(Vector2(-radius * 0.28, -radius * 0.44), radius * 0.2, Color(1.0, 1.0, 1.0, 0.5 * alpha), true, -1.0, true)
	canvas.draw_arc(Vector2.ZERO, radius - 0.4, 0.0, TAU, 48, Color(0.30, 0.36, 0.40, 0.16 * alpha), 1.0, true)

## The screen directions of the two ground axes in this view.
func _ground_axes() -> Array[Vector2]:
	var origin := _camera.unproject_position(Vector3.ZERO)
	return [(_camera.unproject_position(Vector3.RIGHT) - origin).normalized(), (_camera.unproject_position(Vector3.BACK) - origin).normalized()]

func _draw_mark(canvas: Control, kind: String, radius: float, ink: Color) -> void:
	if ink.a <= 0.01:
		return
	var unit := radius / 23.0
	var width := 1.9 * unit
	match kind:
		"mirror":
			UiIcons.draw(canvas, "mirror", Rect2(-Vector2.ONE * radius * 0.5, Vector2.ONE * radius), ink)
		"move":
			# A ground tile as this view shows it, with a head to each side:
			# the mirror moves on the ground.
			var axes := _ground_axes()
			var along := axes[0] * 5.6 * unit
			var across := axes[1] * 5.6 * unit
			UiIcons._stroke(canvas, [along + across, along - across, -along - across, -along + across, along + across], ink, width)
			for side: float in [-1.0, 1.0]:
				var tip := Vector2(13.0 * unit * side, 0.0)
				var back := Vector2(-3.4 * unit * side, 0.0)
				UiIcons._stroke(canvas, [tip + back + back.orthogonal(), tip, tip + back - back.orthogonal()], ink, width)
		"lift":
			_draw_arrows(canvas, Vector2.UP, 9.5 * unit, ink, width)
		"turn":
			var arc := UiIcons._arc(Vector2.ZERO, 8.0 * unit, Vector2.ONE, -215.0, 35.0)
			UiIcons._stroke(canvas, arc, ink, width)
			var end: Vector2 = arc[arc.size() - 1]
			var back := Vector2.from_angle(deg_to_rad(35.0)).orthogonal()
			UiIcons._stroke(canvas, [end + back.rotated(0.75) * 4.6 * unit, end, end + back.rotated(-0.75) * 4.6 * unit], ink, width)
		"remove":
			# The pane goes down into the ground.
			UiIcons._stroke(canvas, [Vector2(-4.5, 7.0) * unit, Vector2(-4.5, 1.5) * unit, Vector2(4.5, 1.5) * unit, Vector2(4.5, 7.0) * unit], ink, width)
			UiIcons._stroke(canvas, [Vector2(-9.0, 7.0) * unit, Vector2(9.0, 7.0) * unit], ink, width)
			UiIcons._stroke(canvas, [Vector2(-3.6, -8.5) * unit, Vector2(0.0, -4.9) * unit, Vector2(3.6, -8.5) * unit], ink, width)

## A line with a head at each end.
func _draw_arrows(canvas: Control, direction: Vector2, reach: float, ink: Color, width: float) -> void:
	UiIcons._stroke(canvas, [-direction * reach, direction * reach], ink, width)
	for end: float in [-1.0, 1.0]:
		var tip := direction * reach * end
		var back := -direction * end * reach * 0.42
		UiIcons._stroke(canvas, [tip + back.rotated(0.65), tip, tip + back.rotated(-0.65)], ink, width)
