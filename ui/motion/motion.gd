class_name Motion
extends RefCounted
## The one set of motion verbs. Every tween in the game names a verb here
## instead of choosing its own time and curve, so the whole game moves with
## one rhythm: slower and softer than a tool, and never a cut
## (docs/VISION.md, "Moment-to-moment feel").

## verb: [seconds, transition, ease]
const VERBS := {
	## A touch answered: a small give and return.
	"press": [0.16, Tween.TRANS_BACK, Tween.EASE_OUT],
	## Something arrives: fades in and rises a little.
	"appear": [0.36, Tween.TRANS_CUBIC, Tween.EASE_OUT],
	## Something leaves: quicker than it came.
	"dismiss": [0.24, Tween.TRANS_CUBIC, Tween.EASE_IN],
	## A value comes to rest after a change: a snap, a step, a camera fit.
	"settle": [0.34, Tween.TRANS_QUINT, Tween.EASE_OUT],
	## A change of the world: the mirror rising, a copy blooming, the view turning.
	"reveal": [0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	## A slow idle pulse, one half-cycle.
	"breathe": [1.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	## From one place or screen to the next.
	"transition": [1.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT],
}
## How far an appearing control rises, in logical units.
const RISE := 8.0

## Divides every duration. Tests raise it so motion ends within a frame or
## two; a reduced-motion setting could later raise it too.
static var speed := 1.0


static func duration(verb: String) -> float:
	return float(VERBS[verb][0]) / maxf(speed, 0.001)


## A tween of `property` on `target` to `value`, in the verb's time and curve.
## `host` creates the tween when `target` is not a Node.
static func tween(target: Object, property: NodePath, value: Variant, verb: String, host: Node = null) -> Tween:
	var maker: Node = target as Node if target is Node else host
	var motion := maker.create_tween()
	motion.tween_property(target, property, value, duration(verb)) \
		.set_trans(VERBS[verb][1]).set_ease(VERBS[verb][2])
	return motion


## Calls `step` with a weight from 0 to 1, in the verb's time and curve, on a
## tween made by `host`. For motions that blend whole poses.
static func blend(host: Node, step: Callable, verb: String) -> Tween:
	var motion := host.create_tween()
	motion.tween_method(step, 0.0, 1.0, duration(verb)).set_trans(VERBS[verb][1]).set_ease(VERBS[verb][2])
	return motion


## Fades a laid-out control in or out where it stands: for HUD controls,
## whose position the layout owns. Hiding sets `visible` false at the end.
static func fade(item: Control, shown: bool) -> void:
	var target := 1.0 if shown else 0.0
	var motion: Tween = item.get_meta("fade_motion") if item.has_meta("fade_motion") else null
	var moving := motion != null and motion.is_valid()
	# Already there, or already on its way there.
	if moving and is_equal_approx(float(item.get_meta("fade_target")), target):
		return
	if not moving and item.visible == shown:
		return
	if moving:
		motion.kill()
	if shown and not item.visible:
		item.modulate.a = 0.0
	item.visible = true
	var verb := "appear" if shown else "dismiss"
	motion = item.create_tween()
	motion.tween_property(item, "modulate:a", target, duration(verb)).set_trans(VERBS[verb][1]).set_ease(VERBS[verb][2])
	if not shown:
		motion.tween_callback(func() -> void:
			item.visible = false
			item.modulate.a = 1.0)
	item.set_meta("fade_target", target)
	item.set_meta("fade_motion", motion)


## Fades a control in as it rises into its place.
static func appear(item: Control) -> Tween:
	var rest := item.position
	item.visible = true
	item.modulate.a = 0.0
	item.position = rest + Vector2(0, RISE)
	var motion := item.create_tween().set_parallel()
	motion.tween_property(item, "modulate:a", 1.0, duration("appear")).set_trans(VERBS["appear"][1]).set_ease(VERBS["appear"][2])
	motion.tween_property(item, "position", rest, duration("appear")).set_trans(VERBS["appear"][1]).set_ease(VERBS["appear"][2])
	return motion


## Fades a control out as it sinks a little, then hides it.
static func dismiss(item: Control) -> Tween:
	var rest := item.position
	var motion := item.create_tween().set_parallel()
	motion.tween_property(item, "modulate:a", 0.0, duration("dismiss")).set_trans(VERBS["dismiss"][1]).set_ease(VERBS["dismiss"][2])
	motion.tween_property(item, "position", rest + Vector2(0, RISE * 0.5), duration("dismiss")).set_trans(VERBS["dismiss"][1]).set_ease(VERBS["dismiss"][2])
	motion.chain().tween_callback(func() -> void:
		item.visible = false
		item.position = rest)
	return motion


## A small give and return about the control's centre.
static func press(item: Control) -> Tween:
	item.pivot_offset = item.size * 0.5
	item.scale = Vector2.ONE * 0.93
	return tween(item, "scale", Vector2.ONE, "press")


## A slow pulse of a CanvasItem's alpha between `low` and full, until killed.
static func breathe(item: CanvasItem, low := 0.55) -> Tween:
	var motion := item.create_tween().set_loops()
	motion.tween_property(item, "modulate:a", low, duration("breathe")).set_trans(VERBS["breathe"][1]).set_ease(VERBS["breathe"][2])
	motion.tween_property(item, "modulate:a", 1.0, duration("breathe")).set_trans(VERBS["breathe"][1]).set_ease(VERBS["breathe"][2])
	return motion
