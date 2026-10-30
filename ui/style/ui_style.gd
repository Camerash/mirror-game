class_name UiStyle
extends RefCounted
## The one UI style: colour, type, spacing and the Godot theme built from
## them. Every screen takes its look from here; no per-control overrides.
## Draft tokens for the owner's look test (docs/VISION.md, "The UI and motion
## system"): a winter garden after rain.

## Wet slate: text and icon ink on light surfaces.
const INK := Color("2c3539")
## Snow: surfaces and ink on dark ground.
const SNOW := Color("f2f0ea")
## Mist: quiet secondary ink, dividers, disabled.
const MIST := Color("a9b8bf")
## Light after rain: the one warm accent, for focus and the goal.
const LIGHT := Color("e9c98f")
## Moss: the garden, for "on" states.
const MOSS := Color("8a9d78")
## Ember: a refusal, used sparingly.
const EMBER := Color("c98a72")

## The smallest touch target, and the main action's size.
const TOUCH := 48.0
const PRIMARY := 56.0
const GAP := 12.0
const RADIUS := 14

## The type scale: [size, weight, letter spacing].
const TYPE := {
	"title": [60, 300, 6],
	"chapter": [30, 300, 3],
	"body": [20, 400, 0],
	"small": [16, 400, 1],
}

## The typeface, Spectral (SIL Open Font License), by weight.
const FONT_FILES := {
	300: preload("res://assets/fonts/Spectral-Light.ttf"),
	400: preload("res://assets/fonts/Spectral-Regular.ttf"),
	500: preload("res://assets/fonts/Spectral-Medium.ttf"),
}

static var _fonts := {}
static var _theme: Theme


## The one typeface at a weight, with optional letter spacing.
static func font(weight := 400, spacing := 0) -> FontVariation:
	var key := "%d/%d" % [weight, spacing]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = FONT_FILES.get(weight, FONT_FILES[400])
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]


## A label in one step of the type scale.
static func label(text: String, step := "body", color := INK) -> Label:
	var item := Label.new()
	item.text = text
	var type: Array = TYPE[step]
	item.add_theme_font_override("font", font(type[1], type[2]))
	item.add_theme_font_size_override("font_size", type[0])
	item.add_theme_color_override("font_color", color)
	return item


## Frosted glass: the one surface for buttons and panels.
static func frost(alpha := 0.84, radius := RADIUS, shadow := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(SNOW, alpha)
	box.border_color = Color(1, 1, 1, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	if shadow:
		box.shadow_color = Color(INK, 0.16)
		box.shadow_size = 10
		box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## The theme every Control tree uses. Built once.
static func theme() -> Theme:
	if _theme:
		return _theme
	var built := Theme.new()
	built.default_font = font(400)
	built.default_font_size = TYPE["body"][0]
	var normal := frost()
	var hover := frost(0.94)
	hover.border_color = Color(LIGHT, 0.9)
	var pressed := frost(1.0, RADIUS, false)
	pressed.bg_color = SNOW.darkened(0.06)
	var disabled := frost(0.45, RADIUS, false)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = LIGHT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(RADIUS + 2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	for type: String in ["Button", "CheckButton"]:
		built.set_stylebox("normal", type, normal)
		built.set_stylebox("hover", type, hover)
		built.set_stylebox("pressed", type, pressed)
		built.set_stylebox("hover_pressed", type, pressed)
		built.set_stylebox("disabled", type, disabled)
		built.set_stylebox("focus", type, focus)
		built.set_color("font_color", type, INK)
		built.set_color("font_hover_color", type, INK)
		built.set_color("font_pressed_color", type, INK)
		built.set_color("font_hover_pressed_color", type, INK)
		built.set_color("font_focus_color", type, INK)
		built.set_color("font_disabled_color", type, Color(INK, 0.4))
	# Round icon buttons: the same frost, a full circle, no text. A radius
	# over half the side draws a seam, so each size has its own variation.
	for variation: Array in [["IconButton", TOUCH], ["PrimaryButton", PRIMARY]]:
		built.set_type_variation(variation[0], "Button")
		var radius := int(float(variation[1]) * 0.5)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var round := (built.get_stylebox(state, "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
			round.set_corner_radius_all(radius)
			# A full-circle box with a border draws a seam down its middle.
			round.set_border_width_all(0)
			round.corner_detail = 16
			if state == "hover":
				# Without a border, hover shows as a warm glow.
				round.shadow_color = Color(LIGHT, 0.75)
				round.shadow_size = 7
				round.shadow_offset = Vector2.ZERO
			round.content_margin_left = 0
			round.content_margin_right = 0
			built.set_stylebox(state, variation[0], round)
		var focus_round := focus.duplicate() as StyleBoxFlat
		focus_round.set_corner_radius_all(radius + 3)
		built.set_stylebox("focus", variation[0], focus_round)
	var panel := frost(0.9, RADIUS + 6)
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	built.set_stylebox("panel", "PanelContainer", panel)
	built.set_color("font_color", "Label", INK)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(MIST, 0.6)
	track.set_corner_radius_all(3)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = INK
	built.set_stylebox("slider", "HSlider", track)
	built.set_stylebox("grabber_area", "HSlider", fill)
	built.set_stylebox("grabber_area_highlight", "HSlider", fill)
	built.set_icon("grabber", "HSlider", _dot(18, INK))
	built.set_icon("grabber_highlight", "HSlider", _dot(20, INK))
	built.set_icon("checked", "CheckButton", _switch(true))
	built.set_icon("unchecked", "CheckButton", _switch(false))
	_theme = built
	return built


static func _dot(size: int, color: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size, size) * 0.5
	for y: int in size:
		for x: int in size:
			var distance := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(centre)
			image.set_pixel(x, y, Color(color, clampf(size * 0.5 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func _switch(on: bool) -> ImageTexture:
	var size := Vector2i(44, 24)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var track := MOSS if on else Color(MIST, 0.8)
	var knob_x := size.x - 12.0 if on else 12.0
	for y: int in size.y:
		for x: int in size.x:
			var point := Vector2(x, y) + Vector2(0.5, 0.5)
			var along := clampf(point.x, 12.0, size.x - 12.0)
			var inside := clampf(12.0 - point.distance_to(Vector2(along, 12.0)), 0.0, 1.0)
			var knob := clampf(9.0 - point.distance_to(Vector2(knob_x, 12.0)), 0.0, 1.0)
			var color := Color(track, inside).blend(Color(SNOW, knob))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
