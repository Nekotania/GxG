extends Node2D
## A human, seen from above. Cannot understand geese. Will learn.

const DU = preload("res://scripts/draw_util.gd")
const Sfx = preload("res://scripts/sfx.gd")

var kind := "stranger"
var shirt := Color(0.5, 0.5, 0.55)
var skin := Color(0.96, 0.8, 0.65)
var hair := Color(0.2, 0.2, 0.2)
var shoes := Color(0.2, 0.15, 0.15)
var long_hair := false
var cap := false
var phone := false

var heading := 0.0
var moving := false
var walk_t := 0.0
var scared := 0.0
var flee_t := 0.0
var t := 0.0
var mode := "idle"   # idle, wander, flee
var threat: Node2D
var speed := 120.0
var bounds := Rect2(40, 40, 1200, 640)
var wander_target := Vector2.ZERO
var wander_wait := 0.0
var _auto_moving := false


func _ready() -> void:
	wander_target = position
	match kind:
		"girl":
			shirt = Color(0.88, 0.35, 0.58)
			hair = Color(0.38, 0.2, 0.08)
			long_hair = true
		"derek":
			shirt = Color(0.35, 0.65, 0.92)
			hair = Color(0.85, 0.7, 0.35)
			cap = true
		"stranger2":
			shirt = Color(0.4, 0.6, 0.4)
			hair = Color(0.1, 0.1, 0.1)
			skin = Color(0.62, 0.45, 0.32)


func scare(by: Node2D = null, pitch: float = 1.0) -> void:
	scared = 1.2
	if by:
		threat = by
		flee_t = 2.2
	Sfx.of().yelp(pitch)


func _process(delta: float) -> void:
	t += delta
	scared = maxf(0.0, scared - delta)
	flee_t = maxf(0.0, flee_t - delta)
	var dir := Vector2.ZERO
	var spd := speed
	if (mode == "flee" or flee_t > 0.0) and is_instance_valid(threat):
		var away := position - threat.position
		if away.length() < 320.0:
			dir = away.normalized()
			spd = speed * (1.4 if mode == "flee" else 1.8)
			# Slide along walls instead of getting pinned in corners.
			var m := 70.0
			var push := Vector2.ZERO
			if position.x < bounds.position.x + m: push.x += 1.0
			if position.x > bounds.end.x - m: push.x -= 1.0
			if position.y < bounds.position.y + m: push.y += 1.0
			if position.y > bounds.end.y - m: push.y -= 1.0
			if push != Vector2.ZERO:
				dir = (dir + push * 1.2 + Vector2(-dir.y, dir.x) * 0.8).normalized()
	if dir == Vector2.ZERO and (mode == "wander" or mode == "flee"):
		if wander_wait > 0.0:
			wander_wait -= delta
		else:
			var to := wander_target - position
			if to.length() < 8.0:
				wander_target = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
				wander_wait = randf_range(0.5, 2.0)
			else:
				dir = to.normalized()
				spd = speed * 0.6
	_auto_moving = dir != Vector2.ZERO
	if _auto_moving:
		position += dir * spd * delta
		position = position.clamp(bounds.position, bounds.end)
		heading = lerp_angle(heading, dir.angle(), minf(1.0, delta * 12.0))
	if _auto_moving or moving:
		walk_t += delta * 12.0
	queue_redraw()


func _draw() -> void:
	var anim := _auto_moving or moving
	var sh := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) if scared > 0.0 else Vector2.ZERO
	draw_colored_polygon(DU.ellipse(Vector2(5, 6), 18, 22), Color(0, 0, 0, 0.22))
	draw_set_transform(sh, heading, Vector2.ONE)

	var step := sin(walk_t) * 7.0 if anim else 0.0
	draw_colored_polygon(DU.ellipse(Vector2(step, -7), 7, 4), shoes)
	draw_colored_polygon(DU.ellipse(Vector2(-step, 7), 7, 4), shoes)

	var hand_l := Vector2(-step * 0.8, -19)
	var hand_r := Vector2(step * 0.8, 19)
	if scared > 0.0:
		var w := sin(t * 30.0) * 5.0
		hand_l = Vector2(16 + w, -15)
		hand_r = Vector2(16 - w, 15)
	draw_circle(hand_l, 5, skin)
	draw_circle(hand_r, 5, skin)
	if phone and scared <= 0.0:
		draw_rect(Rect2(hand_l + Vector2(2, -3), Vector2(9, 6)), Color(0.1, 0.1, 0.12))

	draw_colored_polygon(DU.ellipse(Vector2.ZERO, 11, 19), shirt)
	if long_hair:
		draw_colored_polygon(DU.ellipse(Vector2(-9, 0), 12, 10), hair)
	# Skin circle peeks out in front of the hair: that's the face.
	draw_circle(Vector2(2, 0), 11, skin)
	draw_circle(Vector2(-1, 0), 10.5, hair)
	draw_circle(Vector2(12, 0), 2.5, skin.darkened(0.1))
	if cap:
		draw_circle(Vector2(-1, 0), 9.5, Color(0.85, 0.2, 0.2))
		draw_colored_polygon(DU.ellipse(Vector2(-12, 0), 6, 7), Color(0.7, 0.15, 0.15))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if scared > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-6, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.2, 0.2))
