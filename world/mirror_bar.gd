class_name MirrorBar
extends Node3D
## The control of the mirror in the direct controls (owner's design,
## 2026-11-17): a glass bar below the stage. Before the mirror is up, the bar
## is one round mirror button. A press opens it slowly into two knobs: turn
## and lift. The mirror itself moves by a slide on its glass (owner,
## 2026-11-18), so the bar has no move knob. A knob is held, and the finger
## then uses the full screen: the distance from the press gives the amount. A
## round rose button to the right of the bar lowers the mirror, and a round
## Undo button to its left takes the last change back. The bar is glass; each
## button is opaque, as glazed ceramic. Drawn in screen space; the game owns
## the state change. Sizes are in points: one unit is one point (game.gd).
signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const INK := Color(0.20, 0.25, 0.27, 0.9)

class BarOverlay extends Control:
	var bar: MirrorBar
	## The overlay above the dial's glass ball draws the dial's marks.
	var dial := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if bar == null:
			return
		if dial:
			bar._draw_dial(self)
		else:
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
const KNOBS: Array[String] = ["turn", "lift"]
## The knobs are 46 points wide, above Apple's least touch size of 44; Undo
## and remove are 38 and take a press a little past their rims (owner,
## 2026-11-18).
const HALF_HEIGHT := 31.0
const KNOB := 23.0
const SPACING := 56.0
const BUTTON := 26.0
const REMOVE := 19.0
## The space between the bar's end and the Undo or the remove button.
const SIDE_GAP := 12.0
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
## The held turn knob opens into a turntable pad (owner, 2026-11-18): a disc
## of ice centred on the knob. A slide sideways turns the mirror and a slide
## up or down tilts it, both in one hold; a slide on a slant does both. Each
## axis goes one step for each PAD_STEP of travel and keeps its own margin
## (the game's step rule), so a small drift does not change the other axis.
## The thumb pushes the near edge of a turntable: a slide to the right turns
## the mirror anticlockwise on the screen. Up tilts its face to the sky. The
## steps are the same size everywhere, unlike on the sky map before it, whose
## steps came close together near its centre.
const DIAL_RADIUS := 100.0
const PAD_STEP := 40.0
## The most steps of turn in one hold, each way: half a turn.
const PAD_TURNS := 4.0
## The turn gauge: a flat ring in the upper part of the pad, the ground as the
## camera sees it. Its centre and radii are from the pad's centre. Its front,
## the nearest point, is the facing at the press.
const TURN_RING_CENTRE := Vector2(0.0, -48.0)
const TURN_RING_SIZE := Vector2(52.0, 18.0)
## The tilt gauge: an arc on the pad's left rim, away from a right thumb. Its
## top is the sky, its middle upright, and its bottom the ground.
const TILT_RADIUS := 86.0
const TILT_SPAN := PI * 52.0 / 180.0
const DIAL_WIDTH := 2.0
const DIAL_BEAD := 7.0
## A thumb that rests this long after a slide lets the stage show: the disc
## goes to DIAL_REST_ALPHA. A move brings it back.
const DIAL_REST_SECONDS := 0.5
const DIAL_REST_ALPHA := 0.45
## At each step a pale ring spreads from the bead, as on the pond, and fades.
const RIPPLE_SECONDS := 0.45
const RIPPLE_REACH := 0.2
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
## The pad is a shallow dome of frosted ice. The world behind it is soft and
## bends a little near the rim. Its tint goes from the pale sky at the top to
## the water at the bottom, so up reads as the sky. A thin light lies on its
## upper rim and a soft shade inside its lower rim. It has no shadow, only a
## faint halo of water. No line is hard.
const ORB := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 size = vec2(300.0, 300.0);
uniform float radius = 100.0;
uniform float fade = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * size / radius;
	float d = length(p);
	float inside = 1.0 - smoothstep(1.0 - 1.5 / radius, 1.0, d);
	float z = sqrt(max(1.0 - d * d, 0.0));
	vec2 uv = SCREEN_UV - p * (1.0 - z) * 0.16 * radius * SCREEN_PIXEL_SIZE;
	vec3 back = textureLod(screen, uv, 3.0).rgb;
	vec3 tint = mix(vec3(0.95, 0.965, 0.975), vec3(0.64, 0.71, 0.76), smoothstep(-0.7, 1.0, p.y));
	vec3 colour = mix(back, tint, 0.74);
	// A soft light from above to the left gives the dome its depth.
	colour *= 0.95 + 0.07 * clamp(dot(vec3(p, z), normalize(vec3(-0.4, -0.6, 0.7))), 0.0, 1.0);
	float edge = smoothstep(0.84, 1.0, d);
	colour += vec3(0.80, 0.91, 1.0) * edge * clamp(-p.y, 0.0, 1.0) * 0.32;
	colour *= 1.0 - edge * clamp(p.y, 0.0, 1.0) * 0.14;
	float halo = (1.0 - smoothstep(1.0, 1.14, d)) * 0.10 * (1.0 - inside);
	COLOR = vec4(mix(vec3(0.17, 0.22, 0.27), colour, inside), max(inside, halo) * fade);
}
"""
## Set by the game each frame: whether the bar shows, where its centre is,
## and whether the mirror can go up or down now.
var shown := false
## The control that the prompt names (one of `LevelLoader.PROMPT_CONTROLS`,
## or ""). Rings leave it, as ripples on the water, and for a knob a finger
## mark shows the slide. "move" names the mirror's glass.
var hint := ""
## Where the mirror's glass is on the screen. The game sets it each frame.
var glass_point := Vector2.ZERO
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
## 0 is the turn knob, 1 is the full pad. A spring moves it.
var _dial := 0.0
var _dial_velocity := 0.0
var _dial_centre := Vector2.ZERO
## The turn and the tilt of this hold so far, in steps, before the steps
## snap. The gauge that the slide uses is the clear one.
var _dial_lean := Vector2.ZERO
## The seconds the thumb has rested since its last move on the pad.
var _dial_rest := 0.0
## 1 at a step, then down to 0: the ring that spreads from the bead.
var _ripple := 0.0
## 0 is the mirror button, 1 is the open bar.
var _open := 0.0
var _open_velocity := 0.0
## 0 is rest, 1 is a knob held and started. It fades the other controls.
var _hold := 0.0
## The press growth of each button, from 0 to 1.
var _presses := {"mirror": 0.0, "turn": 0.0, "lift": 0.0, "undo": 0.0, "remove": 0.0}
var _pull := Vector2.ZERO
var _pull_velocity := Vector2.ZERO
var _pull_knob := ""
var _tick := 0.0
## A slide that was made and released while the last change still settled.
var _queued: Dictionary = {}
var _glass := ColorRect.new()
var _glass_material := ShaderMaterial.new()
## The pad's ice, over the bar, and the pad's marks over the ice.
var _orb := ColorRect.new()
var _orb_material := ShaderMaterial.new()
var _dial_overlay := BarOverlay.new()

func _ready() -> void:
	_canvas.layer = 2
	add_child(_canvas)
	_shade(_glass, _glass_material, GLASS)
	_shade(_orb, _orb_material, ORB)
	_canvas.add_child(_glass)
	_overlay.bar = self
	_canvas.add_child(_overlay)
	_canvas.add_child(_orb)
	_dial_overlay.bar = self
	_dial_overlay.dial = true
	_canvas.add_child(_dial_overlay)

func _shade(rect: ColorRect, material: ShaderMaterial, code: String) -> void:
	var shader := Shader.new()
	shader.code = code
	material.shader = shader
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false

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
	_dial_rest = 0.0
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
	return lerpf(BUTTON + 5.0, SPACING * 0.5 + KNOB + 8.0, open)

## A knob's distance from the bar's centre: the two sit either side of it.
func _knob_x(index: int, open: float) -> float:
	return (index - 0.5) * SPACING * open

func _remove_point() -> Vector2:
	return centre + Vector2(_half_width(1.0) + SIDE_GAP + REMOVE, 0.0)

## The Undo button keeps its distance from the bar's left end while the bar
## opens and closes.
func _undo_point() -> Vector2:
	return centre - Vector2(_half_width(_eased()) + SIDE_GAP + REMOVE, 0.0)

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
	return KNOBS[0 if point.x < centre.x else 1]

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
	if _grip == "turn":
		# The pad opens on the knob and stays on the screen.
		_dial_lean = Vector2.ZERO
		_dial_rest = 0.0
		var room := get_viewport().get_visible_rect().grow(-8.0 - DIAL_RADIUS)
		_dial_centre = _grip_press.clamp(room.position, room.end)
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
	_dial_lean = (_grip_point - _grip_press) / PAD_STEP
	action_requested.emit("grip_aim", {
		"yaw": _grip_yaw + clampf(_dial_lean.x, -PAD_TURNS, PAD_TURNS) * AIM_STEP,
		"pitch": _grip_pitch + _dial_lean.y * AIM_STEP})

## The thumb's travel on the pad for a turn and a tilt, in radians. A positive
## turn (anticlockwise on the screen) is to the right; a positive tilt (toward
## the ground) is down.
static func pad_travel(turn: float, tilt: float) -> Vector2:
	return Vector2(turn, tilt) / AIM_STEP * PAD_STEP

## The point of the turn gauge for a turn from the facing at the press. That
## facing is the ring's front; a positive turn goes to the right from there,
## anticlockwise round the ring, as the mirror turns.
func _ring_point(at: Vector2, scale: float, turn: float) -> Vector2:
	return at + (TURN_RING_CENTRE + Vector2.from_angle(PI * 0.5 - turn) * TURN_RING_SIZE) * scale

## The point of the tilt gauge for a tilt: the sky at the top, the ground at
## the bottom.
func _tilt_point(at: Vector2, scale: float, pitch: float) -> Vector2:
	return at + Vector2.from_angle(PI - clampf(pitch, -PI * 0.5, PI * 0.5) * TILT_SPAN / (PI * 0.5)) * TILT_RADIUS * scale

## The mirror went to its next step: the held knob answers.
func tick() -> void:
	_tick = 1.0
	_ripple = 1.0
	Input.vibrate_handheld(10)

func _process(delta: float) -> void:
	var drawn := shown and _camera != null
	_glass.visible = drawn
	if not drawn:
		_orb.visible = false
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
	_ripple = move_toward(_ripple, 0.0, delta / RIPPLE_SECONDS)
	if _ripple > 0.0:
		moving = true
	# The rest counts only after the first move, so a new player can read the
	# pad at the start of a hold.
	if _grip == "turn" and _started and not _grip_point.is_equal_approx(_grip_press):
		var rest_before := _dial_rest
		_dial_rest += delta
		if rest_before < DIAL_REST_SECONDS + 0.3:
			moving = true
	var undo_before := _undo_shown
	spring = _spring(_undo_shown, _undo_velocity, 1.0 if can_undo else 0.0, delta)
	_undo_shown = spring.x
	_undo_velocity = spring.y
	if not is_equal_approx(undo_before, _undo_shown) or _undo_velocity != 0.0:
		moving = true
	var dial_before := _dial
	spring = _spring(_dial, _dial_velocity, 1.0 if _grip == "turn" and _started else 0.0, delta)
	_dial = spring.x
	_dial_velocity = spring.y
	if _dial != dial_before or _dial_velocity != 0.0:
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
	_glass_material.set_shader_parameter("fade", lerpf(1.0, HOLD_GLASS_ALPHA, smoothstep(0.0, 1.0, _hold)) * (1.0 - smoothstep(0.0, 0.6, _dial)))
	_orb.visible = _dialling()
	if _orb.visible:
		var radius := _dial_radius()
		_orb.size = Vector2.ONE * radius * 2.4
		_orb.position = _dial_at() - _orb.size * 0.5
		_orb_material.set_shader_parameter("size", _orb.size)
		_orb_material.set_shader_parameter("radius", radius)
		_orb_material.set_shader_parameter("fade", smoothstep(0.0, 0.3, _dial) * _dial_opacity())
	if moving:
		_overlay.queue_redraw()
		_dial_overlay.queue_redraw()

func _draw_bar(canvas: Control) -> void:
	if not shown or _camera == null:
		return
	var open := _eased()
	var middle := centre + _pull * 0.15
	# The pad lies over the bar: the other controls go while it shows.
	var dim := lerpf(1.0, HOLD_OTHERS_ALPHA, smoothstep(0.0, 1.0, _hold)) * (1.0 - smoothstep(0.0, 0.6, _dial))
	for index: int in [1, 0]:
		var kind := KNOBS[index]
		# The mirror button opens into the turn knob; the lift knob comes in.
		var morph := kind == "turn"
		var alpha := 1.0 if morph else smoothstep(0.1, 0.7, open)
		# The turn knob opens into the pad: it fades as the pad grows.
		if morph:
			alpha *= 1.0 - smoothstep(0.0, 0.4, _dial)
		if alpha <= 0.01:
			continue
		if _grip != kind:
			alpha *= dim
		var held := _grip == kind or (morph and _grip == "mirror")
		var press: float = maxf(_presses[kind], _presses["mirror"]) if morph else _presses[kind]
		var radius := lerpf(BUTTON, KNOB, open) if morph else KNOB
		_set_ceramic(canvas, middle + Vector2(_knob_x(index, open), 0.0), radius, CERAMIC, alpha,
			_pull if _pull_knob == kind else Vector2.ZERO, press, _tick if held else 0.0)
		if morph and open < 0.5:
			_draw_mark(canvas, "mirror", radius, Color(INK, (1.0 - smoothstep(0.0, 0.45, open)) * alpha))
		else:
			_draw_mark(canvas, kind, radius, Color(INK, alpha * (smoothstep(0.55, 1.0, open) if morph else 1.0)))
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

## Whether the pad shows: the turn knob is held, or its pad still grows or
## shrinks.
func _dialling() -> bool:
	return _dial != 0.0 or _dial_velocity != 0.0

## How far the pad is open, from 0 to 1. The game fades the prompt with it.
func dial_amount() -> float:
	return clampf(_dial, 0.0, 1.0)

## The pad's radius and centre now. It grows from the turn knob.
func _dial_radius() -> float:
	return lerpf(KNOB, DIAL_RADIUS, maxf(_dial, 0.0))

func _dial_at() -> Vector2:
	return (centre + _pull * 0.15).lerp(_dial_centre, clampf(_dial, 0.0, 1.0))

## How clear the pad is: it lets the stage show while the thumb rests after a
## slide.
func _dial_opacity() -> float:
	if _grip != "turn":
		return 1.0
	return lerpf(1.0, DIAL_REST_ALPHA, smoothstep(DIAL_REST_SECONDS, DIAL_REST_SECONDS + 0.3, _dial_rest))

## The marks on the pad. They keep the rule of the bar's marks: the dark part
## is the mirror, and the pale part is where it can go. Two gauges, each with
## a pale dot at each step and one dark bead, the mirror:
## - the turn: a flat ring in the upper part, the ground as the camera sees
##   it. The bead goes round it as the mirror turns.
## - the tilt: an arc on the left rim. The bead goes up to the sky and down to
##   the ground.
## The gauge that the slide uses is clear, the other faint. A hollow ring on
## each marks where the hold began: a release there changes nothing. At each
## step a ring spreads from the bead of the gauge in use.
func _draw_dial(canvas: Control) -> void:
	if not _dialling() or not shown or _camera == null:
		return
	var at := _dial_at()
	var scale := _dial_radius() / DIAL_RADIUS
	var clear := smoothstep(0.3, 0.9, _dial) * _dial_opacity()
	if clear <= 0.01:
		return
	var focus := clampf(0.5 + absf(_dial_lean.x) - absf(_dial_lean.y), 0.0, 1.0)
	var turn_ink := Color(INK, clear * lerpf(0.2, 0.55, focus))
	var tilt_ink := Color(INK, clear * lerpf(0.2, 0.55, 1.0 - focus))
	var ring := at + TURN_RING_CENTRE * scale
	# The far half of the ring is fainter than the near half.
	canvas.draw_polyline(UiIcons._arc(ring, scale, TURN_RING_SIZE, 180.0, 360.0), Color(turn_ink, turn_ink.a * 0.5), DIAL_WIDTH * 0.75, true)
	canvas.draw_polyline(UiIcons._arc(ring, scale, TURN_RING_SIZE, 0.0, 180.0), turn_ink, DIAL_WIDTH, true)
	for index: int in roundi(TAU / AIM_STEP):
		canvas.draw_circle(_ring_point(at, scale, index * AIM_STEP), 2.6, turn_ink, true, -1.0, true)
	var tilt_from := rad_to_deg(PI - TILT_SPAN)
	canvas.draw_polyline(UiIcons._arc(at, TILT_RADIUS * scale, Vector2.ONE, tilt_from, tilt_from + rad_to_deg(TILT_SPAN) * 2.0), tilt_ink, DIAL_WIDTH, true)
	for step: int in range(-2, 3):
		canvas.draw_circle(_tilt_point(at, scale, step * AIM_STEP), 2.6, tilt_ink, true, -1.0, true)
	if _grip == "turn":
		var start := Color(INK, clear * 0.35)
		canvas.draw_arc(_ring_point(at, scale, 0.0), DIAL_BEAD + 3.5, 0.0, TAU, 40, start, 1.5, true)
		canvas.draw_arc(_tilt_point(at, scale, _grip_pitch), DIAL_BEAD + 3.5, 0.0, TAU, 40, start, 1.5, true)
	var turn_bead := _ring_point(at, scale, wrapf(_yaw() - _grip_yaw, -PI, PI))
	var tilt_bead := _tilt_point(at, scale, _pitch())
	if _ripple > 0.0:
		var bead := turn_bead if focus >= 0.5 else tilt_bead
		canvas.draw_arc(bead, lerpf(DIAL_BEAD, DIAL_RADIUS * RIPPLE_REACH, 1.0 - _ripple), 0.0, TAU, 40, Color(INK, clear * 0.45 * _ripple * _ripple), 1.5, true)
	canvas.draw_circle(turn_bead, DIAL_BEAD, Color(INK, clear), true, -1.0, true)
	canvas.draw_circle(tilt_bead, DIAL_BEAD, Color(INK, clear), true, -1.0, true)

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
	elif hint == "move":
		# A slide on the mirror's glass moves it.
		at = glass_point
		radius = 18.0
	else:
		at = centre + Vector2(_knob_x(KNOBS.find(hint), 1.0), 0.0)
	# Two rings, half a period apart, each grows and fades in 2.4 s.
	for offset: float in [0.0, 0.5]:
		var phase := fposmod(_hint_time / 2.4 + offset, 1.0)
		canvas.draw_arc(at, radius + 3.0 + phase * 16.0, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.7 * (1.0 - phase) * (1.0 - phase)), 1.6, true)
	if hint not in KNOBS and hint != "move":
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
		"turn":
			UiIcons._stroke(canvas, UiIcons._arc(Vector2.ZERO, 8.6 * unit, Vector2.ONE, -60.0, 240.0), pale, width)
		"lift":
			UiIcons._stroke(canvas, [Vector2(0.0, -10.0) * unit, Vector2(0.0, 10.0) * unit], pale, width)
		"undo":
			# One open arc that turns back over the top (owner, 2026-11-18). Its
			# head is a short, wide chevron with round ends and a round point,
			# in the same stroke as the arc.
			var arc := UiIcons._arc(Vector2(0.5, 2.0) * unit, 7.2 * unit, Vector2.ONE, 15.0, -196.0)
			UiIcons._stroke(canvas, arc, ink, width)
			var tip: Vector2 = arc[arc.size() - 1]
			var way: Vector2 = (tip - arc[arc.size() - 2]).normalized()
			UiIcons._stroke(canvas, [tip + way.rotated(PI - 0.9) * 3.6 * unit, tip, tip + way.rotated(PI + 0.9) * 3.6 * unit], ink, width)
	if kind in KNOBS:
		canvas.draw_circle(Vector2.ZERO, 2.7 * unit, ink, true, -1.0, true)
