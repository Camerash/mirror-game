extends SceneTree

const HUD := preload("res://ui/mirror_hud.gd")
const Style := preload("res://core/constellation_style.gd")

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(390, 844)
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	var actions: Array[Dictionary] = []
	hud.action_requested.connect(func(action: String, value: Variant) -> void: actions.append({"action": action, "value": value}))
	for key: String in Style.DEFAULTS:
		_check(is_equal_approx((hud._guide_sliders[key] as HSlider).value, float(Style.DEFAULTS[key])), "%s starts at its style default" % key)
	hud.display_state({"guide_style": {"brightness": 4.0, "glow": -1.0}, "guide_preview": true, "guide_preview_available": false})
	_check(actions.is_empty(), "State synchronization emits no actions")
	for key: String in Style.DEFAULTS:
		var slider := hud._guide_sliders[key] as HSlider
		var limits: Vector3 = Style.LIMITS[key]
		_check(is_equal_approx(slider.min_value, limits.x) and is_equal_approx(slider.max_value, limits.y) and is_equal_approx(slider.step, limits.z), "%s uses style limits" % key)
		_check(slider.custom_minimum_size.y >= 48.0, "%s has a 48-unit touch region" % key)
	_check(is_equal_approx((hud._guide_sliders["brightness"] as HSlider).value, 1.0), "Style synchronization clamps brightness")
	_check(is_equal_approx((hud._guide_sliders["glow"] as HSlider).value, 0.0), "Style synchronization clamps glow")
	_check(hud._guide_preview.disabled, "Guide preview disables when unavailable")
	hud.set_guide_state({}, false, true)
	_check(actions.is_empty() and not hud._guide_preview.disabled and not hud._guide_preview.button_pressed, "Dedicated guide synchronization emits no actions")
	(hud._guide_sliders["halo"] as HSlider).value_changed.emit(6.5)
	_check(actions.size() == 1 and actions[0]["action"] == "guide_style" and actions[0]["value"] == {"key": "halo", "value": 6.5}, "Slider emits the guide style action")
	hud._guide_defaults.pressed.emit()
	_check(actions.size() == 2 and actions[1]["action"] == "guide_defaults" and actions[1]["value"] == null, "Reset emits defaults action")
	hud._gear.pressed.emit()
	await process_frame
	_check(hud.is_debug_visible() and actions.size() == 3 and actions[2]["action"] == "debug_visibility" and actions[2]["value"] == true, "Gear reports visible debug state")
	_check(hud._debug_panel.size.x <= 260.0 and hud._debug_panel.size.y <= 220.0, "Portrait debug panel stays below 220 units")
	_check(hud._guide_preview.get_global_rect().position.y < (hud._guide_sliders["brightness"] as HSlider).get_global_rect().position.y, "Preview toggle stays at the top of the panel")
	for key: String in Style.DEFAULTS:
		_check((hud._guide_sliders[key] as HSlider).is_visible_in_tree(), "%s slider is included in the portrait panel" % key)
	hud.queue_free()
	quit(1 if _failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)
