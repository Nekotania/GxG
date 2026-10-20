extends Node2D
## Top-down ground for each location. 1280x720.

const DU = preload("res://scripts/draw_util.gd")
const W := 1280.0
const H := 720.0

var preset := "cosmos"
var stars := []
var t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 180:
		stars.append([Vector2(rng.randf() * W, rng.randf() * H), rng.randf_range(0.8, 2.4), rng.randf() * TAU])
	z_index = -100


func _process(delta: float) -> void:
	t += delta
	if preset == "cosmos" or preset == "sunset":
		queue_redraw()


func _grass(c: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 260:
		var p := Vector2(rng.randf() * W, rng.randf() * H)
		draw_line(p, p + Vector2(rng.randf_range(-3, 3), -7), c.darkened(0.15), 2)


func _roof(r: Rect2, c: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.25))
	draw_rect(r, c)
	var mid := r.position.y + r.size.y * 0.5
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.5), c.lightened(0.08))
	draw_line(Vector2(r.position.x, mid), Vector2(r.end.x, mid), c.darkened(0.3), 4)


func _draw() -> void:
	match preset:
		"cosmos":
			draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.02, 0.09))
			draw_circle(Vector2(300, 200), 280, Color(0.35, 0.05, 0.45, 0.12))
			draw_circle(Vector2(1000, 520), 320, Color(0.05, 0.2, 0.45, 0.12))
			draw_circle(Vector2(700, 100), 200, Color(0.5, 0.15, 0.05, 0.1))
			for s in stars:
				draw_circle(s[0], s[1], Color(1, 1, 1, 0.5 + 0.5 * sin(t * 2.0 + s[2])))
		"farm":
			_grass(Color(0.45, 0.72, 0.35))
			draw_rect(Rect2(900, 380, 380, 110), Color(0.72, 0.6, 0.4))
			_roof(Rect2(30, 20, 300, 170), Color(0.72, 0.15, 0.12))
			var pen := Rect2(80, 220, 820, 420)
			draw_rect(pen, Color(0.5, 0.65, 0.3))
			var fence := Color(0.5, 0.33, 0.15)
			draw_line(pen.position, Vector2(pen.end.x, pen.position.y), fence, 5)
			draw_line(pen.position, Vector2(pen.position.x, pen.end.y), fence, 5)
			draw_line(Vector2(pen.position.x, pen.end.y), pen.end, fence, 5)
			draw_line(Vector2(pen.end.x, pen.position.y), Vector2(pen.end.x, 380), fence, 5)
			draw_line(Vector2(pen.end.x, 490), pen.end, fence, 5)
			for x in range(int(pen.position.x), int(pen.end.x) + 1, 60):
				draw_circle(Vector2(x, pen.position.y), 6, fence.darkened(0.2))
				draw_circle(Vector2(x, pen.end.y), 6, fence.darkened(0.2))
			draw_colored_polygon(DU.ellipse(Vector2(700, 330), 110, 55), Color(0.3, 0.55, 0.85))
			for p in [Vector2(1080, 120), Vector2(1150, 160), Vector2(1100, 600)]:
				draw_circle(p + Vector2(4, 5), 26, Color(0, 0, 0, 0.2))
				draw_circle(p, 26, Color(0.9, 0.78, 0.35))
				draw_arc(p, 16, 0, TAU, 16, Color(0.75, 0.62, 0.25), 2)
		"yard":
			_grass(Color(0.42, 0.7, 0.36))
			_roof(Rect2(0, -20, W, 150), Color(0.45, 0.4, 0.42))
			for i in 6:
				draw_rect(Rect2(500 + (i % 3) * 95, 140 + int(i / 3.0) * 45, 88, 40), Color(0.75, 0.72, 0.68))
			var fence := Color(0.6, 0.45, 0.28)
			draw_rect(Rect2(0, 130, 14, H), fence)
			draw_rect(Rect2(W - 14, 130, 14, H), fence)
			draw_rect(Rect2(0, H - 14, W, 14), fence)
			for p in [Vector2(120, 220), Vector2(160, 250), Vector2(1150, 640), Vector2(1190, 600)]:
				draw_circle(p, 10, Color(0.95, 0.4, 0.6))
				draw_circle(p, 4, Color(1, 0.9, 0.3))
		"lawn":
			_grass(Color(0.4, 0.68, 0.33))
			_roof(Rect2(760, -10, 440, 230), Color(0.35, 0.45, 0.62))
			draw_rect(Rect2(1060, 220, 160, 420), Color(0.55, 0.55, 0.58))
			draw_rect(Rect2(500, 230, 230, 160), Color(0.7, 0.65, 0.6))
			draw_rect(Rect2(0, 640, W, 80), Color(0.3, 0.3, 0.33))
			draw_rect(Rect2(0, 630, W, 12), Color(0.75, 0.75, 0.72))
			for x in range(0, int(W), 80):
				draw_rect(Rect2(x + 10, 678, 40, 6), Color(0.95, 0.85, 0.3))
			draw_string(ThemeDB.fallback_font, Vector2(820, 120), "DEREK'S HOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.5))
		"sunset":
			_grass(Color(0.4, 0.66, 0.34))
			var path := PackedVector2Array()
			for i in 30:
				var x := i * 46.0
				path.append(Vector2(x, 520 + sin(x * 0.006) * 70.0))
			draw_polyline(path, Color(0.82, 0.72, 0.5), 54)
			draw_colored_polygon(DU.ellipse(Vector2(330, 260), 240, 140), Color(0.25, 0.5, 0.8))
			draw_colored_polygon(DU.ellipse(Vector2(330, 260), 200, 110), Color(0.3, 0.58, 0.88))
			for i in 5:
				var lp := Vector2(220 + i * 55, 220 + sin(i * 1.7) * 60)
				draw_circle(lp, 12, Color(0.3, 0.65, 0.3))
			for i in 4:
				var rp := Vector2(330, 260) + Vector2.from_angle(t * 0.4 + i * 1.6) * 120.0
				draw_arc(rp, 8 + fmod(t * 6.0 + i * 4.0, 20.0), 0, TAU, 16, Color(1, 1, 1, 0.25), 2)
		"apartment":
			draw_rect(Rect2(0, 0, W, H), Color(0.4, 0.66, 0.35))
			var room := Rect2(60, 40, 1020, 640)
			draw_rect(room, Color(0.62, 0.44, 0.28))
			for y in range(int(room.position.y), int(room.end.y), 40):
				draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y), Color(0.52, 0.36, 0.22), 2)
			draw_colored_polygon(DU.ellipse(Vector2(520, 420), 240, 120), Color(0.75, 0.55, 0.45))
			var wall := Color(0.92, 0.9, 0.85)
			draw_rect(Rect2(40, 20, 1060, 20), wall)
			draw_rect(Rect2(40, 680, 1060, 20), wall)
			draw_rect(Rect2(40, 20, 20, 680), wall)
			draw_rect(Rect2(1080, 20, 20, 200), wall)
			draw_rect(Rect2(1080, 340, 20, 360), wall)
			draw_rect(Rect2(1084, 220, 12, 120), Color(0.6, 0.85, 1.0, 0.7))
			draw_rect(Rect2(900, 640, 120, 40), Color(0.5, 0.3, 0.3))
			draw_string(ThemeDB.fallback_font, Vector2(905, 666), "PEACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
