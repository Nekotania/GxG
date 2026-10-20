extends Node2D
## A goose, seen from above. Can only honk, flap, and bite. Like its Father before it.

signal honked
signal flapped
signal bit

const DU = preload("res://scripts/draw_util.gd")
const Sfx = preload("res://scripts/sfx.gd")
const HONK_TIME := 0.3
const BITE_TIME := 0.22

var controllable := false
var npc := false
var moving := false
var fiery := false
var speed := 230.0
## 1.0 is the unaltered honk.mp3, reserved for Father Goose. His children honk higher.
var pitch := 1.4
var tint := Color.WHITE
var bounds := Rect2(40, 40, 1200, 640)
var heading := 0.0
var vel := Vector2.ZERO
var honk_t := 0.0
var flap_t := 0.0
var bite_t := 0.0
var flap_cd := 0.0
var bite_cd := 0.0
var walk_t := 0.0
var grace := 0.0
var t := 0.0
var wander_target := Vector2.ZERO
var wander_wait := 0.0


func _ready() -> void:
	wander_target = position
	t = randf() * 10.0


func set_controllable(v: bool) -> void:
	controllable = v
	grace = 0.15
	vel = Vector2.ZERO


func forward() -> Vector2:
	return Vector2.from_angle(heading)


## Bites sweep from the neck to just past the beak, so point-blank bites still land.
func bite_hits(p: Vector2, radius: float) -> bool:
	var a := position + forward() * 8.0 * scale.x
	var b := position + forward() * 62.0 * scale.x
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= radius


func bite_hits_prop(prop) -> bool:
	for i in 5:
		if prop.hits(position + forward() * lerpf(8.0, 62.0, i / 4.0) * scale.x, 10.0):
			return true
	return false


func _process(delta: float) -> void:
	t += delta
	honk_t = maxf(0.0, honk_t - delta)
	flap_t = maxf(0.0, flap_t - delta)
	bite_t = maxf(0.0, bite_t - delta)
	flap_cd = maxf(0.0, flap_cd - delta)
	bite_cd = maxf(0.0, bite_cd - delta)
	grace -= delta
	vel = Vector2.ZERO
	if controllable:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		vel = dir * speed * (1.7 if flap_t > 0.0 else 1.0)
		if grace <= 0.0:
			if Input.is_action_just_pressed("honk"):
				honk()
			if Input.is_action_just_pressed("flap"):
				flap()
			if Input.is_action_just_pressed("bite"):
				bite()
	elif npc:
		if wander_wait > 0.0:
			wander_wait -= delta
		else:
			var to := wander_target - position
			if to.length() < 8.0:
				wander_target = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
				wander_wait = randf_range(0.4, 2.5)
			else:
				vel = to.normalized() * speed * 0.45
	if vel != Vector2.ZERO:
		position += vel * delta
		position = position.clamp(bounds.position, bounds.end)
		heading = lerp_angle(heading, vel.angle(), minf(1.0, delta * 14.0))
	if vel != Vector2.ZERO or moving:
		walk_t += delta * 14.0
	queue_redraw()


func honk() -> void:
	honk_t = HONK_TIME
	Sfx.of().honk(pitch)
	honked.emit()


func flap() -> void:
	if flap_cd > 0.0:
		return
	flap_t = 0.6
	flap_cd = 0.9
	Sfx.of().flap()
	flapped.emit()


func bite() -> void:
	if bite_cd > 0.0:
		return
	# Snap to the held direction so a bite right after turning goes where you aimed.
	if controllable:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir != Vector2.ZERO:
			heading = dir.angle()
	bite_t = BITE_TIME
	bite_cd = 0.4
	Sfx.of().bite()
	bit.emit()


func _draw() -> void:
	var white := tint
	var shade := tint.darkened(0.18)
	var orange := Color(1.0, 0.55, 0.1)
	if fiery:
		for i in 3:
			var r := 52.0 + i * 12.0 + sin(t * 8.0 + i) * 5.0
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.4 + i * 0.15, 0.1, 0.18))
	draw_colored_polygon(DU.ellipse(Vector2(5, 6), 30, 20), Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, heading, Vector2.ONE)

	# Feet paddle out from under the body when walking.
	var step := sin(walk_t) * 6.0
	draw_colored_polygon(DU.ellipse(Vector2(4 + step, -8), 7, 4), orange)
	draw_colored_polygon(DU.ellipse(Vector2(4 - step, 8), 7, 4), orange)

	draw_colored_polygon(PackedVector2Array([Vector2(-20, -8), Vector2(-36, 0), Vector2(-20, 8)]), shade)
	draw_colored_polygon(DU.ellipse(Vector2.ZERO, 24, 15), white)

	if flap_t > 0.0:
		var a := sin(t * 30.0) * 0.5 + 0.5
		var span := 34.0 + a * 16.0
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(10, 8 * s), Vector2(-4, (span + 6) * s), Vector2(-22, (span - 4) * s), Vector2(-16, 8 * s)
			]), shade)
	else:
		draw_colored_polygon(DU.ellipse(Vector2(-4, -10), 16, 5), shade)
		draw_colored_polygon(DU.ellipse(Vector2(-4, 10), 16, 5), shade)

	var lunge := 0.0
	if bite_t > 0.0:
		lunge = sin((1.0 - bite_t / BITE_TIME) * PI) * 18.0
	var head := Vector2(30 + lunge, 0)
	draw_line(Vector2(12, 0), head, white, 11)
	draw_circle(head, 9.5, white)

	var open := 4.0 if (honk_t > 0.0 or bite_t > 0.0) else 0.0
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -4 - open), head + Vector2(21, -open), head + Vector2(6, 0)]), orange)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, 0), head + Vector2(21, open), head + Vector2(6, 4 + open)]), orange.darkened(0.12))

	draw_circle(head + Vector2(2, -5.5), 2.2, Color.BLACK)
	draw_circle(head + Vector2(2, 5.5), 2.2, Color.BLACK)
	draw_line(head + Vector2(-2, -9), head + Vector2(6, -6), Color.BLACK, 2)
	draw_line(head + Vector2(-2, 9), head + Vector2(6, 6), Color.BLACK, 2)

	if honk_t > 0.0:
		var p := 1.0 - honk_t / HONK_TIME
		for i in 3:
			var rr := 10.0 + p * 30.0 + i * 9.0
			draw_arc(head + Vector2(22, 0), rr, -0.7, 0.7, 10, Color(1, 1, 1, (1.0 - p) * 0.9), 3)
