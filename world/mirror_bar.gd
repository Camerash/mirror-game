class_name MirrorBar
extends Node3D
## The control of the mirror in the direct controls (owner's design,
## 2026-11-17): a glass bar below the stage. Before the mirror is up, the bar
## is one round mirror button. A press opens it slowly into three knobs: move,
## turn, lift. A knob is held, and the finger then uses the full screen: the
## distance from the press gives the amount. A round rose button to the right
## of the bar lowers the mirror, and a round Undo button to its left takes the
## last change back. The bar is glass; each button is opaque, as glazed
## ceramic. Drawn in screen space; the game owns the state change.
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
## A damped spring moves the open amount and the Undo button. Damping ratio
## 0.7 and natural frequency 12 rad/s give an overshoot of about 4.6 percent.
const SPRING_STIFFNESS := 144.0
const SPRING_DAMPING := 16.8
const SPRING_STEP := 1.0 / 120.0
## The spring is at rest when the distance and the speed are below these.
const SPRING_REST_DISTANCE := 0.003
const SPRING_REST_SPEED := 0.03
## The seconds for a press to grow and to go back, and for the hold amount to
## rise and to fall.
const PRESS_IN_SECONDS := 0.12
const PRESS_OUT_SECONDS := 0.2
const HOLD_IN_SECONDS := 0.18
const HOLD_OUT_SECONDS := 0.25
## The opacity that the other controls and the glass keep while a knob is held.
const HOLD_OTHERS_ALPHA := 0.2
const HOLD_GLASS_ALPHA := 0.3
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
uniform float fade = 1.0;

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
	COLOR = vec4(mix(vec3(0.10, 0.13, 0.16), colour, inside), max(inside, shadow) * fade);
}
"""
## Set by the game each frame: whether the bar shows, where its centre is,
## and whether the mirror can go up or down now.
var shown := false
## The control that the prompt names (one of `LevelLoader.PROMPT_CONTROLS`,
## or ""). Rings leave it, as ripples on the water, and for a knob a finger
## mark shows the slide.
var hint := ""
var _hint_time := 0.0
## Whether there is a change to take back. The game sets it each frame.
var can_undo := false
var _undo_shown := 0.0
var _undo_velocity := 0.0
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
var _open_velocity := 0.0
## 0 is rest, 1 is a knob held and started. It fades the other controls.
var _hold := 0.0
## The press growth of each button, from 0 to 1.
var _presses := {"mirror": 0.0, "move": 0.0, "turn": 0.0, "lift": 0.0, "undo": 0.0, "remove": 0.0}
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
	if not _available and _active and _grip in KNOBS:
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
		action_requested.emit("undo" if kind == "undo" else "mirror_toggle", null)
	_overlay.queue_redraw()

func _yaw() -> float:
	return float(Rules.normalized(_state)["yaw"])

func _pitch() -> float:
	return float(Rules.normalized(_state)["pitch"])

## The open amount that the drawing uses. It can pass 1 or 0 a little.
func _eased() -> float:
	return _open

## One step of a damped spring. Returns the new value and speed. It snaps to
## the target when both are very small.
func _spring(value: float, velocity: float, target: float, delta: float) -> Vector2:
	var steps := ceili(minf(delta, 0.1) / SPRING_STEP)
	for step: int in steps:
		velocity += (SPRING_STIFFNESS * (target - value) - SPRING_DAMPING * velocity) * delta / steps
		value += velocity * delta / steps
	if absf(target - value) < SPRING_REST_DISTANCE and absf(velocity) < SPRING_REST_SPEED:
		return Vector2(target, 0.0)
	return Vector2(value, velocity)

func _half_width(open: float) -> float:
	return lerpf(BUTTON + 6.0, SPACING + KNOB + 10.0, open)

func _remove_point() -> Vector2:
	return centre + Vector2(_half_width(1.0) + 15.0 + REMOVE, 0.0)

## The Undo button keeps its distance from the bar's left end while the bar
## opens and closes.
func _undo_point() -> Vector2:
	return centre - Vector2(_half_width(_eased()) + 15.0 + REMOVE, 0.0)

func _on_undo(point: Vector2) -> bool:
	return _undo_shown > 0.5 and point.distance_to(_undo_point()) <= REMOVE + 8.0

## Whether the bar is below the point. The bar takes each press on it, so a
## press there never walks.
func _on_bar(point: Vector2) -> bool:
	if not shown or _camera == null:
		return false
	var local := point - centre
	if absf(local.y) <= HALF_HEIGHT + 6.0 and absf(local.x) <= _half_width(_eased()) + 6.0:
		return true
	return _on_undo(point) or (_open > 0.5 and point.distance_to(_remove_point()) <= REMOVE + 8.0)

## The control below the point: a knob, the mirror button, the remove button
## or the Undo button. Empty while the bar opens or closes.
func _grip_at(point: Vector2) -> String:
	if not _on_bar(point):
		return ""
	if _on_undo(point):
		return "undo"
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
	if kind.is_empty() or (kind == "undo" and (_busy or not can_undo)) or (kind in ["mirror", "remove"] and not can_toggle):
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
	var spring := _spring(_open, _open_velocity, 1.0 if _available else 0.0, delta)
	_open = spring.x
	_open_velocity = spring.y
	if not _queued.is_empty():
		_run_queued()
	elif _grip in KNOBS and not _started:
		_start_knob()
	var moving := not is_equal_approx(before, _open) or _open_velocity != 0.0 or _tick > 0.0
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
	var undo_before := _undo_shown
	spring = _spring(_undo_shown, _undo_velocity, 1.0 if can_undo else 0.0, delta)
	_undo_shown = spring.x
	_undo_velocity = spring.y
	if not is_equal_approx(undo_before, _undo_shown) or _undo_velocity != 0.0:
		moving = true
	var hold_before := _hold
	var holding := _grip in KNOBS and _started
	_hold = move_toward(_hold, 1.0 if holding else 0.0, delta / (HOLD_IN_SECONDS if holding else HOLD_OUT_SECONDS))
	if _hold != hold_before:
		moving = true
	for kind: String in _presses:
		var pressed := _grip == kind
		var press_before: float = _presses[kind]
		_presses[kind] = move_toward(press_before, 1.0 if pressed else 0.0, delta / (PRESS_IN_SECONDS if pressed else PRESS_OUT_SECONDS))
		if _presses[kind] != press_before:
			moving = true
	if not hint.is_empty():
		_hint_time += delta
		moving = true
	# The pill may pass its two ends a little, but never gets narrower than round.
	var half := Vector2(maxf(_half_width(_eased()), HALF_HEIGHT), HALF_HEIGHT)
	_glass.size = (half + Vector2(30.0, 30.0)) * 2.0
	_glass.position = centre + _pull * 0.15 - _glass.size * 0.5
	_glass_material.set_shader_parameter("size", _glass.size)
	_glass_material.set_shader_parameter("half_size", half)
	_glass_material.set_shader_parameter("fade", lerpf(1.0, HOLD_GLASS_ALPHA, smoothstep(0.0, 1.0, _hold)))
	if moving:
		_overlay.queue_redraw()

func _draw_bar(canvas: Control) -> void:
	if not shown or _camera == null:
		return
	var open := _eased()
	var middle := centre + _pull * 0.15
	var dim := lerpf(1.0, HOLD_OTHERS_ALPHA, smoothstep(0.0, 1.0, _hold))
	for index: int in [0, 2, 1]:
		var kind := KNOBS[index]
		var alpha := 1.0 if index == 1 else smoothstep(0.1, 0.7, open)
		if alpha <= 0.01:
			continue
		if _grip != kind:
			alpha *= dim
		var held := _grip == kind or (index == 1 and _grip == "mirror")
		var press: float = maxf(_presses[kind], _presses["mirror"]) if index == 1 else _presses[kind]
		var radius := lerpf(BUTTON, KNOB, open) if index == 1 else KNOB
		_set_ceramic(canvas, middle + Vector2((index - 1) * SPACING * open, 0.0), radius, CERAMIC, alpha,
			_pull if _pull_knob == kind else Vector2.ZERO, press, _tick if held else 0.0)
		if index == 1 and open < 0.5:
			_draw_mark(canvas, "mirror", radius, Color(INK, (1.0 - smoothstep(0.0, 0.45, open)) * alpha))
		else:
			_draw_mark(canvas, kind, radius, Color(INK, alpha * (smoothstep(0.55, 1.0, open) if index == 1 else 1.0)))
	# The remove button comes out of the bar's right end with the spring. It is
	# clear while it starts, so it does not pop.
	var out := clampf(smoothstep(0.4, 0.9, open), 0.0, 1.0) * dim
	if out > 0.01:
		var from := centre + Vector2(_half_width(open) - REMOVE, 0.0)
		var slide := maxf((open - 0.4) / 0.6, 0.0)
		_set_ceramic(canvas, from.lerp(_remove_point(), slide), REMOVE, ROSE, out, Vector2.ZERO, _presses["remove"], 0.0)
		_draw_mark(canvas, "remove", REMOVE, Color(ROSE_INK, out))
	var undo_alpha := clampf(_undo_shown, 0.0, 1.0) * dim
	if undo_alpha > 0.01:
		# The Undo button grows in with the spring and may pass its size a little.
		var undo_radius := REMOVE * maxf(lerpf(0.7, 1.0, _undo_shown), 0.0)
		_set_ceramic(canvas, _undo_point(), undo_radius, CERAMIC, undo_alpha, Vector2.ZERO, _presses["undo"], 0.0)
		_draw_mark(canvas, "undo", undo_radius, Color(INK, undo_alpha))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hint(canvas, open)

## The ripples and the finger mark of the control that the prompt names.
func _draw_hint(canvas: Control, open: float) -> void:
	if hint.is_empty() or _active:
		return
	var at := centre
	var radius := KNOB
	if hint == "mirror":
		if open > 0.05:
			return
		radius = BUTTON
	elif open < 0.95:
		return
	elif hint == "remove":
		at = _remove_point()
		radius = REMOVE
	else:
		at = centre + Vector2((KNOBS.find(hint) - 1) * SPACING, 0.0)
	# Two rings, half a period apart, each grows and fades in 2.4 s.
	for offset: float in [0.0, 0.5]:
		var phase := fposmod(_hint_time / 2.4 + offset, 1.0)
		canvas.draw_arc(at, radius + 3.0 + phase * 16.0, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.7 * (1.0 - phase) * (1.0 - phase)), 1.6, true)
	if hint not in KNOBS:
		return
	# The slide: a finger mark comes down on the knob, goes its way and fades.
	# A pause follows. Its dark ring shows on a white knob, its light ring on
	# the water.
	var way := Vector2.RIGHT
	if hint == "lift":
		way = Vector2.DOWN
	elif hint == "move":
		# Along the ground axis that goes up and to the right on the screen,
		# away from the Undo button.
		for axis: Vector2 in _ground_axes():
			var up := axis if axis.y < 0.0 else -axis
			if up.x >= 0.0:
				way = up
	var time := fposmod(_hint_time, 3.6)
	var travel := clampf((time - 0.5) / 1.5, 0.0, 1.0)
	var eased := travel * travel * (3.0 - 2.0 * travel)
	var fade := smoothstep(0.0, 0.3, time) * (1.0 - smoothstep(1.7, 2.3, time))
	var finger := at + way * eased * 84.0
	var size := lerpf(22.0, 17.0, smoothstep(0.0, 0.4, time))
	canvas.draw_circle(finger, size, Color(1.0, 1.0, 1.0, 0.22 * fade), true, -1.0, true)
	canvas.draw_arc(finger, size, 0.0, TAU, 48, Color(INK, 0.5 * fade), 2.0, true)
	canvas.draw_arc(finger, size + 2.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.4, true)

## Draws one opaque round button, as glazed ceramic, and leaves the canvas
## in the button's frame for its mark. `pull` moves the button toward a drag
## and makes it longer that way.
func _set_ceramic(canvas: Control, at: Vector2, radius: float, colour: Color, alpha: float, pull: Vector2, press: float, pulse: float) -> void:
	var amount := clampf(pull.length() / PULL_LIMIT, 0.0, 1.0)
	var angle := pull.angle() if amount > 0.001 else 0.0
	var grow := 1.0 + 0.03 * smoothstep(0.0, 1.0, press) + 0.04 * pulse
	var matrix := Transform2D(angle, Vector2.ZERO) * Transform2D.IDENTITY.scaled(Vector2(1.0 + 0.06 * amount, 1.0 - 0.025 * amount) * grow) * Transform2D(-angle, Vector2.ZERO)
	matrix.origin = at + pull
	canvas.draw_set_transform_matrix(matrix)
	for layer: int in 4:
		canvas.draw_circle(Vector2(0.0, 2.0 + layer * 1.2), radius + layer * 1.3, Color(0.10, 0.13, 0.16, 0.055 * alpha), true, -1.0, true)
	var lift := smoothstep(0.0, 1.0, press)
	var body := colour.lerp(Color(1.0, 1.0, 1.0), lift) if colour == CERAMIC else colour.lightened(0.08 * lift)
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
	# Each mark has one dark part, the mirror, and one pale part: where the
	# mirror can go, or the light on its glass (owner, 2026-11-18).
	var unit := radius / 23.0
	var width := 1.8 * unit
	var pale := Color(Color(ink, 1.0).lerp(ROSE if kind == "remove" else CERAMIC, 0.62), ink.a)
	match kind:
		"mirror", "remove":
			# The mirror to raise is an empty frame. The mirror that stands has
			# glass in it: two lines of light.
			var frame := Rect2(Vector2(-4.5, -7.5) * unit, Vector2(9.0, 15.0) * unit)
			if kind == "remove":
				for lift: float in [-2.6, 2.6]:
					UiIcons._stroke(canvas, [Vector2(-1.7, lift + 2.0) * unit, Vector2(1.7, lift - 2.0) * unit], pale, width)
			UiIcons._stroke(canvas, UiIcons._rounded(frame, 2.0 * unit), ink, width)
		"move":
			# The two ways of the ground as this view shows them.
			for axis: Vector2 in _ground_axes():
				UiIcons._stroke(canvas, [-axis * 10.0 * unit, axis * 10.0 * unit], pale, width)
		"turn":
			UiIcons._stroke(canvas, UiIcons._arc(Vector2.ZERO, 8.6 * unit, Vector2.ONE, -60.0, 240.0), pale, width)
		"lift":
			UiIcons._stroke(canvas, [Vector2(0.0, -10.0) * unit, Vector2(0.0, 10.0) * unit], pale, width)
		"undo":
			# The usual hook back to the left, with a soft, round head.
			var hook := PackedVector2Array([Vector2(-5.0, -3.0) * unit, Vector2(2.5, -3.0) * unit])
			hook.append_array(UiIcons._arc(Vector2(2.5, 1.5) * unit, 4.5 * unit, Vector2.ONE, -90.0, 90.0))
			hook.append(Vector2(-3.0, 6.0) * unit)
			UiIcons._stroke(canvas, hook, ink, width)
			var head := PackedVector2Array([Vector2(-8.6, -3.0) * unit, Vector2(-4.8, -6.2) * unit, Vector2(-4.8, 0.2) * unit])
			canvas.draw_colored_polygon(head, ink)
			UiIcons._stroke(canvas, [head[0], head[1], head[2], head[0]], ink, width)
	if kind in KNOBS:
		canvas.draw_circle(Vector2.ZERO, 2.7 * unit, ink, true, -1.0, true)
