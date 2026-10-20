extends Node2D
## Every non-goose, non-human object, drawn top-down from primitives.

const DU = preload("res://scripts/draw_util.gd")

var kind := "sign"
var label := ""
var color := Color.WHITE
var radius := 60.0
var fallen := false
var faceless := false
var chomped := false
var alarm_t := 0.0
var t := 0.0


func _ready() -> void:
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	alarm_t = maxf(0.0, alarm_t - delta)
	queue_redraw()


func knock() -> void:
	if fallen:
		return
	fallen = true
	var tw := create_tween()
	tw.tween_property(self, "rotation", rotation + PI * 0.5 * (1.0 if randf() < 0.5 else -1.0), 0.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Local-space hit box, so rotated props still hit correctly.
func hit_rect() -> Rect2:
	match kind:
		"car": return Rect2(-60, -32, 120, 64)
		"grill": return Rect2(-28, -28, 56, 56)
		"cutout": return Rect2(-32, -14, 64, 28)
		"gnome": return Rect2(-14, -14, 28, 28)
		"kayak": return Rect2(-90, -16, 180, 32)
	return Rect2(-24, -24, 48, 48)


func hits(p: Vector2, pad: float) -> bool:
	return hit_rect().grow(pad).has_point(to_local(p))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var shadow := Color(0, 0, 0, 0.22)
	match kind:
		"sign":
			draw_rect(Rect2(-84, -40, 180, 90), shadow)
			draw_rect(Rect2(-90, -46, 180, 90), Color(0.95, 0.9, 0.75))
			draw_rect(Rect2(-90, -46, 180, 90), Color(0.4, 0.25, 0.1), false, 4)
			var lines := label.split("\n")
			for i in lines.size():
				draw_string(font, Vector2(-90, -18 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 180, 20, Color(0.6, 0.1, 0.1))
		"cutout":
			var board := Color(0.75, 0.58, 0.38) if not fallen else Color(0.6, 0.46, 0.3)
			draw_rect(Rect2(-28, -10, 64, 34), shadow)
			draw_rect(Rect2(-32, -14, 64, 28), board)
			draw_rect(Rect2(-32, -14, 64, 28), Color(0.5, 0.35, 0.2), false, 3)
			# The face is painted on top so you can read it from above. Cardboard logic.
			if faceless:
				draw_circle(Vector2(0, -34), 18, Color(0.35, 0.25, 0.12))
			else:
				draw_circle(Vector2(0, -34), 18, Color(0.85, 0.7, 0.35))
				draw_circle(Vector2(0, -30), 15, Color(0.95, 0.78, 0.62))
				draw_circle(Vector2(-5, -32), 2, Color.BLACK)
				draw_circle(Vector2(5, -32), 2, Color.BLACK)
				draw_arc(Vector2(0, -27), 7, 0.3, PI - 0.3, 8, Color.BLACK, 2)
			draw_string(font, Vector2(-32, 7), "DEREK", HORIZONTAL_ALIGNMENT_CENTER, 64, 14, Color.BLACK)
		"grill":
			draw_circle(Vector2(5, 6), 30, shadow)
			if fallen:
				draw_colored_polygon(DU.ellipse(Vector2.ZERO, 30, 20), Color(0.12, 0.12, 0.12))
				for i in 7:
					draw_circle(Vector2(30 + i * 9, sin(i * 2.0) * 16), 4, Color(1.0, 0.45, 0.1))
				draw_rect(Rect2(60, 20, 26, 8), Color(0.7, 0.3, 0.2))
			else:
				draw_circle(Vector2.ZERO, 28, Color(0.12, 0.12, 0.12))
				for i in range(-2, 3):
					draw_line(Vector2(-22, i * 9), Vector2(22, i * 9), Color(0.45, 0.45, 0.45), 2)
				draw_rect(Rect2(-12, -4, 24, 8), Color(0.7, 0.3, 0.2))
				for i in 3:
					var k := fmod(t * 0.5 + i * 0.33, 1.0)
					draw_circle(Vector2(sin(t + i) * 8, -10 - k * 50), 6 + k * 10, Color(0.8, 0.8, 0.8, 0.35 * (1.0 - k)))
		"car":
			draw_rect(Rect2(-56, -26, 124, 64), shadow)
			for w in [Vector2(-38, -32), Vector2(38, -32), Vector2(-38, 26), Vector2(38, 26)]:
				draw_rect(Rect2(w - Vector2(12, 0), Vector2(24, 7)), Color(0.08, 0.08, 0.08))
			draw_rect(Rect2(-60, -30, 120, 60), Color(0.82, 0.15, 0.15))
			draw_rect(Rect2(-24, -24, 50, 48), Color(0.65, 0.1, 0.1))
			draw_rect(Rect2(26, -22, 12, 44), Color(0.6, 0.85, 1.0))
			draw_rect(Rect2(-36, -22, 10, 44), Color(0.6, 0.85, 1.0))
			var lights := Color(1, 1, 0.6)
			if alarm_t > 0.0 and int(t * 6.0) % 2 == 0:
				lights = Color(1, 0.6, 0.0)
				draw_circle(Vector2(60, -20), 22, Color(1, 0.8, 0.2, 0.35))
				draw_circle(Vector2(60, 20), 22, Color(1, 0.8, 0.2, 0.35))
			draw_circle(Vector2(58, -20), 5, lights)
			draw_circle(Vector2(58, 20), 5, lights)
		"gnome":
			if fallen:
				draw_colored_polygon(DU.ellipse(Vector2.ZERO, 22, 10), Color(0.2, 0.4, 0.8))
				draw_colored_polygon(PackedVector2Array([Vector2(14, -8), Vector2(38, 0), Vector2(14, 8)]), Color(0.85, 0.15, 0.15))
				draw_circle(Vector2(-20, 0), 8, Color.WHITE)
			else:
				draw_circle(Vector2(4, 5), 15, shadow)
				draw_circle(Vector2.ZERO, 14, Color(0.2, 0.4, 0.8))
				draw_colored_polygon(DU.ellipse(Vector2(0, 8), 9, 6), Color.WHITE)
				draw_circle(Vector2.ZERO, 9, Color(0.85, 0.15, 0.15))
				draw_circle(Vector2.ZERO, 4, Color(0.65, 0.1, 0.1))
			draw_string(font, Vector2(-30, 30), "GERALD", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1, 1, 1, 0.8))
		"kayak":
			draw_colored_polygon(DU.ellipse(Vector2(5, 6), 90, 16), shadow)
			draw_colored_polygon(DU.ellipse(Vector2.ZERO, 90, 16), Color(1.0, 0.82, 0.1))
			draw_colored_polygon(DU.ellipse(Vector2(-6, 0), 22, 9), Color(0.2, 0.2, 0.2))
			draw_string(font, Vector2(20, 5), "UNUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.35, 0))
			if chomped:
				for i in 4:
					draw_circle(Vector2(60 + i * 6, -14 + (i % 2) * 4), 5, Color(0.3, 0.5, 0.25))
		"bench":
			draw_rect(Rect2(-76, -16, 160, 40), shadow)
			for i in 3:
				draw_rect(Rect2(-80, -20 + i * 13, 160, 10), Color(0.55, 0.35, 0.18))
		"tree":
			draw_circle(Vector2(14, 16), 62, Color(0, 0, 0, 0.18))
			draw_circle(Vector2.ZERO, 58, Color(0.18, 0.45, 0.2))
			draw_circle(Vector2(-18, -14), 34, Color(0.24, 0.55, 0.26))
			draw_circle(Vector2(20, 10), 26, Color(0.22, 0.5, 0.24))
		"bush":
			for c in [[Vector2(-26, 4), 30.0], [Vector2(10, -10), 34.0], [Vector2(36, 10), 26.0], [Vector2(0, 22), 28.0]]:
				draw_circle(c[0], c[1], Color(0.16, 0.42, 0.18))
			draw_circle(Vector2(8, -14), 16, Color(0.22, 0.52, 0.24))
		"mailbox":
			draw_rect(Rect2(-14, -10, 34, 26), shadow)
			draw_rect(Rect2(-18, -14, 34, 24), Color(0.3, 0.3, 0.35))
			draw_string(font, Vector2(-40, 30), "DEREK", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
		"couch":
			draw_rect(Rect2(-124, -40, 260, 90), shadow)
			draw_rect(Rect2(-130, -46, 260, 90), Color(0.45, 0.3, 0.55))
			draw_rect(Rect2(-130, 24, 260, 20), Color(0.35, 0.22, 0.45))
			draw_rect(Rect2(-130, -46, 22, 90), Color(0.35, 0.22, 0.45))
			draw_rect(Rect2(108, -46, 22, 90), Color(0.35, 0.22, 0.45))
			draw_line(Vector2(0, -40), Vector2(0, 22), Color(0.35, 0.22, 0.45), 2)
		"tv":
			var glow := 0.15 + 0.08 * sin(t * 7.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-80, 6), Vector2(80, 6), Vector2(170, 220), Vector2(-170, 220)]), Color(0.5, 0.7, 1.0, glow))
			draw_rect(Rect2(-90, -10, 180, 16), Color(0.08, 0.08, 0.1))
		"god":
			for i in 12:
				var a := t * 0.6 + TAU * i / 12.0
				draw_line(Vector2.from_angle(a) * 46.0, Vector2.from_angle(a) * 72.0, Color(1, 0.95, 0.6, 0.7), 4)
			for i in 4:
				draw_circle(Vector2.ZERO, 46.0 - i * 5.0, Color(1, 0.95, 0.6, 0.2 + i * 0.15))
			draw_circle(Vector2.ZERO, 30, Color(1, 1, 0.88))
			draw_circle(Vector2(-9, -4), 3, Color(0.3, 0.25, 0.1))
			draw_circle(Vector2(9, -4), 3, Color(0.3, 0.25, 0.1))
			draw_line(Vector2(-14, -12), Vector2(-5, -9), Color(0.3, 0.25, 0.1), 2)
			draw_line(Vector2(14, -12), Vector2(5, -9), Color(0.3, 0.25, 0.1), 2)
			draw_circle(Vector2(0, 10), 4, Color(0.3, 0.25, 0.1))
			draw_circle(Vector2(25, -14 + fmod(t * 20.0, 12.0)), 4, Color(0.5, 0.75, 1.0))
		"angel":
			var bob := sin(t * 3.0) * 4.0
			draw_colored_polygon(DU.ellipse(Vector2(-20, bob), 16, 8), Color(0.85, 0.85, 0.95))
			draw_colored_polygon(DU.ellipse(Vector2(20, bob), 16, 8), Color(0.85, 0.85, 0.95))
			draw_circle(Vector2(0, bob), 15, Color.WHITE)
			draw_arc(Vector2(0, bob), 20, 0, TAU, 24, Color(1, 0.85, 0.3), 3)
		"devil":
			draw_line(Vector2(-10, 10), Vector2(-34, 30), Color(0.6, 0.05, 0.05), 3)
			draw_colored_polygon(PackedVector2Array([Vector2(-34, 30), Vector2(-44, 26), Vector2(-38, 38)]), Color(0.6, 0.05, 0.05))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -14), Vector2(-20, -34), Vector2(-4, -20)]), Color(0.3, 0.05, 0.05))
			draw_colored_polygon(PackedVector2Array([Vector2(14, -14), Vector2(20, -34), Vector2(4, -20)]), Color(0.3, 0.05, 0.05))
			draw_circle(Vector2.ZERO, 22, Color(0.85, 0.1, 0.1))
			draw_circle(Vector2(-7, -4), 3, Color.YELLOW)
			draw_circle(Vector2(7, -4), 3, Color.YELLOW)
			draw_arc(Vector2(0, 3), 10, 0.2, PI - 0.2, 10, Color.BLACK, 2)
		"apple":
			draw_circle(Vector2.ZERO, 14, Color(0.85, 0.1, 0.15))
			draw_line(Vector2(0, -12), Vector2(2, -20), Color(0.4, 0.25, 0.1), 3)
			draw_colored_polygon(DU.ellipse(Vector2(8, -18), 7, 3), Color(0.2, 0.7, 0.2))
		"universe":
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.15))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, color, 3)
			for i in 5:
				draw_circle(Vector2.from_angle(i * 2.4 + t * 0.3) * radius * (0.3 + i * 0.1), 2.5, Color.WHITE)
		"earth":
			draw_circle(Vector2.ZERO, radius + 14, Color(0.4, 0.7, 1.0, 0.25))
			draw_circle(Vector2.ZERO, radius, Color(0.2, 0.45, 0.85))
			draw_colored_polygon(DU.ellipse(Vector2(-60, -30), radius * 0.55, radius * 0.4), Color(0.3, 0.65, 0.3))
			draw_colored_polygon(DU.ellipse(Vector2(110, 80), radius * 0.35, radius * 0.25), Color(0.3, 0.65, 0.3))
			draw_colored_polygon(DU.ellipse(Vector2(80, -150), radius * 0.2, radius * 0.1), Color(0.95, 0.95, 1.0))
		"bread":
			draw_colored_polygon(DU.ellipse(Vector2(3, 4), 20, 13), shadow)
			draw_colored_polygon(DU.ellipse(Vector2.ZERO, 20, 13), Color(0.85, 0.62, 0.3))
			draw_colored_polygon(DU.ellipse(Vector2(0, -2), 14, 8), Color(0.95, 0.8, 0.5))
		"keys":
			draw_arc(Vector2(-8, 0), 7, 0, TAU, 16, Color(0.95, 0.8, 0.2), 3)
			draw_line(Vector2(-1, 0), Vector2(18, 0), Color(0.95, 0.8, 0.2), 3)
			draw_line(Vector2(12, 0), Vector2(12, 6), Color(0.95, 0.8, 0.2), 3)
			draw_line(Vector2(17, 0), Vector2(17, 5), Color(0.95, 0.8, 0.2), 3)
		"flame":
			for i in 3:
				draw_circle(Vector2(0, -i * 8), 14.0 - i * 4.0 + sin(t * 20.0 + i) * 2.0, Color(1, 0.3 + i * 0.3, 0.1, 0.8))
