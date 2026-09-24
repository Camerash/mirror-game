class_name SafeArea
extends RefCounted
## The usable part of a control's viewport, inset for a device's safe area
## (a notch, a home indicator). Desktop windows have no such inset, so this
## is a no-op there. Shared by `ui/mirror_hud.gd` and `app.gd`, so the title
## and end-card overlays clear a notch exactly like the play HUD does.

static func rect(control: Control) -> Rect2:
	var visible := control.get_viewport_rect()
	if OS.get_name() not in ["iOS", "Android"]:
		return visible
	var area := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	if area.size.x <= 0 or area.size.y <= 0 or window.x <= 0 or window.y <= 0:
		return visible
	var result := Rect2(Vector2(area.position) * visible.size / Vector2(window), Vector2(area.size) * visible.size / Vector2(window)).intersection(visible)
	return result if result.size.x > 0 and result.size.y > 0 else visible
