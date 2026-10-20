extends Node2D
## GxG (Goose Goose): The Ineffable Goose Experiment.
## The whole story runs as one coroutine; each chapter builds its world, plays, then clears it.

const GooseS = preload("res://scripts/goose.gd")
const HumanS = preload("res://scripts/human.gd")
const PropS = preload("res://scripts/prop.gd")
const BackdropS = preload("res://scripts/backdrop.gd")
const UIS = preload("res://scripts/ui.gd")
const SfxS = preload("res://scripts/sfx.gd")

const GOOSE_COLOR := Color(1.0, 0.85, 0.35)
const GIRL_COLOR := Color(1.0, 0.55, 0.75)
const DEREK_COLOR := Color(0.55, 0.8, 1.0)
const NARRATOR_COLOR := Color(0.8, 0.8, 0.8)
const FATHER_COLOR := Color(1.0, 0.45, 0.2)
const GIRL_NAME := "Penny"
const EX_NAME := "Derek"

var ui
var world: Node2D
var tint: CanvasModulate
var goose
var girl
var derek
var npcs := []
var cutouts := []
var targets := {}
var chapter := ""
var flags := {}
var cooldowns := {}
var honk_count := 0
var last_honk := 0.0
var terror := 0.0
var beat_tweens: Array[Tween] = []


func _ready() -> void:
	randomize()
	var win := get_window()
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if not Engine.is_embedded_in_editor():
		win.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_setup_input()
	if SfxS.of() == null or not is_instance_valid(SfxS.of()):
		var sfx = SfxS.new()
		get_tree().root.add_child.call_deferred(sfx)
	tint = CanvasModulate.new()
	add_child(tint)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	ui = UIS.new()
	add_child(ui)
	_run()


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("honk", [KEY_SPACE])
	_bind("flap", [KEY_E, KEY_SHIFT])
	_bind("bite", [KEY_F, KEY_J])
	_bind("advance", [KEY_SPACE, KEY_ENTER], true)
	_bind("restart", [KEY_R])


func _bind(action: String, keys: Array, mouse: bool = false) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	if mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(action, mb)


func _input(event: InputEvent) -> void:
	if chapter == "end" and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _run() -> void:
	await get_tree().process_frame
	await intro()
	await controls_card()
	await chapter_choosing()
	await chapter_training()
	await chapter_derek()
	await chapter_payment()
	await chapter_honk()
	await finale()


# ---------------------------------------------------------------- helpers

func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func cd_ready(key: String, dur: float) -> bool:
	if cooldowns.get(key, 0.0) > now():
		return false
	cooldowns[key] = now() + dur
	return true


func clear_world() -> void:
	for c in world.get_children():
		c.queue_free()
	goose = null
	girl = null
	derek = null
	npcs = []
	cutouts = []
	targets = {}
	flags = {}
	tint.color = Color.WHITE
	ui.set_objective("")
	ui.show_meter(false)


func set_backdrop(preset: String) -> void:
	var b = BackdropS.new()
	b.preset = preset
	add_child(b)
	move_child(b, 0)
	b.add_to_group("backdrop")
	for old in get_tree().get_nodes_in_group("backdrop"):
		if old != b:
			old.queue_free()


func add_prop(kind: String, pos: Vector2, extra: Dictionary = {}):
	var p = PropS.new()
	p.kind = kind
	p.position = pos
	for k in extra:
		p.set(k, extra[k])
	world.add_child(p)
	return p


func pop_prop(kind: String, pos: Vector2, extra: Dictionary = {}):
	var p = add_prop(kind, pos, extra)
	p.scale = Vector2.ZERO
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return p


func fade_free(n: Node2D) -> void:
	if not is_instance_valid(n):
		return
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.5)
	tw.tween_callback(n.queue_free)


func spawn_goose(pos: Vector2, player: bool = false):
	var g = GooseS.new()
	g.position = pos
	world.add_child(g)
	g.honked.connect(_on_any_honk.bind(g))
	if player:
		goose = g
		g.honked.connect(_player_honk)
		g.flapped.connect(_player_flap)
		g.bit.connect(_player_bite)
	return g


func spawn_human(kind: String, pos: Vector2):
	var h = HumanS.new()
	h.kind = kind
	h.position = pos
	world.add_child(h)
	return h


func face(a: Node2D, b) -> void:
	var target: Vector2 = b if b is Vector2 else b.position
	a.heading = (target - a.position).angle()


func walk(actor: Node2D, to: Vector2, dur: float) -> void:
	actor.moving = true
	face(actor, to)
	var tw := create_tween()
	tw.tween_property(actor, "position", to, dur)
	await tw.finished
	if is_instance_valid(actor):
		actor.moving = false


func popup(text: String, pos: Vector2, color: Color = Color.WHITE, size: int = 26, life: float = 0.9) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 100
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(500, 40)
	l.position = pos - Vector2(250, 20)
	world.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 50, life)
	tw.parallel().tween_property(l, "modulate:a", 0.0, life * 0.6).set_delay(life * 0.4)
	tw.tween_callback(l.queue_free)


func _on_any_honk(g) -> void:
	popup("HONK!", g.position + g.forward() * 40.0 * g.scale.x + Vector2(0, -30 * g.scale.x), Color.WHITE, int(22 * clampf(g.scale.x, 1.0, 2.5)))


# ---------------------------------------------------------------- dialogue

## A tween that belongs to the current line of dialogue. Advancing the line snaps it to its end,
## so skipping fast never leaves half-played animations (or late spawns) on screen.
func beat_tween() -> Tween:
	var tw := create_tween()
	beat_tweens.append(tw)
	return tw


func finish_beats() -> void:
	for tw in beat_tweens:
		if tw.is_valid() and tw.is_running():
			tw.custom_step(9999.0)
	beat_tweens.clear()


func say(speaker: String, text: String, color: Color, translation: String = "") -> void:
	await ui.say(speaker, text, color, translation)
	finish_beats()


func narr(text: String) -> void:
	await say("", "[i]" + text + "[/i]", NARRATOR_COLOR)


func girl_says(text: String) -> void:
	await say(GIRL_NAME, text, GIRL_COLOR)


func derek_says(text: String) -> void:
	await say(EX_NAME, text, DEREK_COLOR)


func goose_says(honks: String, translation: String, g = null, speaker: String = "The Chosen Goose", color: Color = GOOSE_COLOR) -> void:
	var who = g if g != null else goose
	if who != null:
		_honk_burst(who, honks.split(" ", false).size())
	await say(speaker, honks, color, translation)


func _honk_burst(g, n: int) -> void:
	for i in mini(n, 5):
		if not is_instance_valid(g):
			return
		g.honk()
		await wait(0.22)


func chapter_card(big: String, small: String) -> void:
	ui.hide_box()
	await ui.fade_to(1.0, 0.6)
	clear_world()
	ui.show_title(big, small)
	await wait(2.4)
	ui.show_title("", "")


func await_honks() -> int:
	honk_count = 0
	goose.set_controllable(true)
	while honk_count == 0 or now() - last_honk < 0.9:
		await get_tree().process_frame
	goose.set_controllable(false)
	return honk_count


# ---------------------------------------------------------------- player actions

func _player_honk() -> void:
	if goose == null or not goose.controllable:
		return
	honk_count += 1
	last_honk = now()
	match chapter:
		"choosing":
			if goose.position.distance_to(girl.position) < 220.0 and cd_ready("girl_honk", 1.5):
				popup(["Aww, chatty!", "Is that goose for 'hello'?", "Same, buddy.", "Rude! I like it."].pick_random(),
					girl.position + Vector2(0, -50), GIRL_COLOR)
		"training":
			if flags.get("step") == 1 and goose.position.distance_to(cutouts[0].position) < 230.0:
				cutouts[0].knock()
				flags["step"] = 2
		"derek":
			if goose.position.distance_to(derek.position) < 230.0 and cd_ready("honk", 0.6):
				_terrorize(8, ["AAH!", "What was that?!", "Who's there?!", "Is that... a goose?!"].pick_random())
		"chase":
			if goose.position.distance_to(girl.position) < 230.0 and cd_ready("chase_honk", 1.0):
				girl.scare(goose, 1.2)


func _player_flap() -> void:
	if goose == null or not goose.controllable:
		return
	match chapter:
		"training":
			if flags.get("step") == 2 and goose.position.distance_to(cutouts[1].position) < 170.0:
				cutouts[1].knock()
				flags["step"] = 3
		"derek":
			if goose.position.distance_to(derek.position) < 170.0 and cd_ready("flap", 0.9):
				_terrorize(10, ["IT'S HUGE!", "THE WINGSPAN!", "GET AWAY!"].pick_random())


func _player_bite() -> void:
	if goose == null or not goose.controllable:
		return
	match chapter:
		"choosing":
			if goose.bite_hits(girl.position, 30.0):
				flags["chosen"] = true
				return
			for g in npcs:
				if goose.bite_hits(g.position, 28.0) and cd_ready("npc_bite", 0.5):
					g.honk()
					g.flap()
					popup("(offended honking)", g.position + Vector2(0, -40), Color(1, 1, 1, 0.8), 18)
		"training":
			if flags.get("step") == 3 and goose.bite_hits_prop(cutouts[2]):
				cutouts[2].faceless = true
				cutouts[2].knock()
				flags["step"] = 4
		"derek":
			if goose.bite_hits(derek.position, 30.0) and cd_ready("bite", 0.5):
				_terrorize(15, ["OW! MY ANKLE!", "IT BIT ME!", "NOT THE CALVES!"].pick_random())
				return
			_bite_derek_stuff()
		"chase":
			if goose.bite_hits(girl.position, 30.0) and cd_ready("chase_bite", 0.8):
				var lines := ["OW! I GAVE YOU BREAD!", "OKAY OKAY I'M SORRY!", "I'LL DO IT! I'LL FIGHT GOD!"]
				var n: int = flags.get("bites", 0)
				girl.scare(goose, 1.2)
				popup(lines[mini(n, 2)], girl.position + Vector2(0, -50), GIRL_COLOR, 24, 1.6)
				flags["bites"] = n + 1


func _bite_derek_stuff() -> void:
	var grill = targets.get("grill")
	if grill and not grill.fallen and goose.bite_hits_prop(grill):
		grill.knock()
		_terrorize(12, "MY HOT DOG! MY ONLY HOT DOG!")
	var car = targets.get("car")
	if car and car.alarm_t <= 0.0 and goose.bite_hits_prop(car) and cd_ready("car", 4.0):
		car.alarm_t = 4.0
		SfxS.of().alarm()
		popup("WEE-OO WEE-OO", car.position + Vector2(0, -50), Color(1, 0.8, 0.2), 26, 1.5)
		_terrorize(12, "MY CAR!")
	var gnome = targets.get("gnome")
	if gnome and not gnome.fallen and goose.bite_hits_prop(gnome):
		gnome.knock()
		_terrorize(8, "NOT GERALD!")
	var kayak = targets.get("kayak")
	if kayak and not kayak.chomped and goose.bite_hits_prop(kayak):
		kayak.chomped = true
		_terrorize(12, "NOT THE KAYAK! I'VE NEVER EVEN USED IT!")


func _terrorize(amount: float, line: String) -> void:
	terror = minf(100.0, terror + amount)
	ui.set_meter(terror)
	derek.scare(goose, 0.85)
	popup(line, derek.position + Vector2(0, -50), DEREK_COLOR, 24, 1.3)


# ---------------------------------------------------------------- prologue

func intro() -> void:
	chapter = "intro"
	ui.fade_set(1.0)
	set_backdrop("cosmos")
	await ui.fade_to(0.0, 1.5)
	await narr("In the beginning, before the dawn of time, when Chaos and Entropy were the only things in existence...")

	var fg = spawn_goose(Vector2(640, 290))
	fg.pitch = 1.0
	fg.fiery = true
	fg.heading = PI * 0.5
	fg.scale = Vector2.ZERO
	var tw := beat_tween()
	tw.tween_property(fg, "scale", Vector2(4, 4), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fg.honk)
	await narr("...there was [b]Father Goose[/b].")

	var extras := []
	for p in [Vector2(170, 140), Vector2(280, 250), Vector2(150, 360)]:
		extras.append(pop_prop("angel", p))
	var tw2 := beat_tween()
	tw2.tween_interval(1.6)
	tw2.tween_callback(func(): extras.append(pop_prop("devil", Vector2(980, 230))))
	tw2.tween_interval(0.6)
	tw2.tween_callback(func(): extras.append(pop_prop("apple", Vector2(1090, 290))))
	await narr("When God created the angels, Father Goose created the Devil and temptation.")

	var god = pop_prop("god", Vector2(1080, 140))
	for e in extras:
		fade_free(e)
	await wait(0.5)
	face(fg, god)
	fg.moving = true
	var tw3 := beat_tween()
	tw3.tween_property(god, "position", Vector2(1450, 60), 1.0).set_delay(0.5)
	tw3.parallel().tween_property(fg, "position", Vector2(1650, 120), 1.8).set_delay(0.8)
	await narr("When God created the universe, Father Goose chased him.")

	var bubbles := []
	for i in 9:
		var bp := Vector2(140 + (i % 5) * 250 + randf_range(-40, 40), 110 + int(i / 5.0) * 250 + randf_range(-30, 30))
		bubbles.append(pop_prop("universe", bp, {"radius": randf_range(50.0, 85.0), "color": Color.from_hsv(randf(), 0.5, 1.0)}))
	god.position = Vector2(-100, 200)
	god.scale = Vector2(0.5, 0.5)
	var tw4 := beat_tween()
	for b in bubbles:
		tw4.tween_property(god, "position", b.position, 0.35)
	tw4.tween_property(god, "position", Vector2(1450, 100), 0.4)
	await narr("Then God created the Multiverse to flee from Father Goose.")

	fg.position = Vector2(640, 290)
	fg.moving = false
	fg.heading = PI * 0.5
	fg.honk()
	var kids := []
	for i in 10:
		var side := -1.0 if i % 2 == 0 else 1.0
		var kp := Vector2(640 + side * randf_range(230, 540), randf_range(90, 480))
		var k = spawn_goose(kp)
		k.npc = true
		k.pitch = randf_range(1.4, 1.8)
		k.scale = Vector2.ZERO
		k.bounds = Rect2(60, 60, 1160, 440)
		var kt := k.create_tween()
		kt.tween_property(k, "scale", Vector2(0.9, 0.9), 0.3).set_delay(i * 0.12)
		kids.append(k)
	await narr("Father Goose was displeased, so he multiplied, and called his children [b]The Geese[/b]. The Geese went to chase God through the Multiverse.")

	_fg_demo(fg)
	await narr("However, of all Father Goose's imperfections, the one that stood out most was that he could only honk, flap his wings, and bite. The Geese were no different.")
	await goose_says("HONK HONK HONK HONK!!!",
		"My children, go and chase down THE LORD. Ask every being He created to help us. In exchange, we'll help them honk at their nemesis. But if they don't keep their side of the bargain... we will HONK at them!",
		fg, "Father Goose", FATHER_COLOR)
	_cheer(kids)
	await narr("The Geese cheered in admiration.")

	# The Chosen Goose descends.
	ui.hide_box()
	await ui.fade_to(1.0, 0.6)
	clear_world()
	set_backdrop("cosmos")
	add_prop("earth", Vector2(640, 330), {"radius": 260.0})
	var cg = spawn_goose(Vector2(640, 300))
	cg.fiery = true
	cg.heading = PI * 0.5
	cg.scale = Vector2(7, 7)
	cg.modulate.a = 0.0
	await ui.fade_to(0.0, 0.6)
	var tw5 := beat_tween()
	tw5.tween_property(cg, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw5.parallel().tween_property(cg, "modulate:a", 1.0, 1.0)
	tw5.tween_callback(cg.set.bind("fiery", false))
	tw5.tween_callback(cg.honk)
	await narr("Then [b]The Chosen Goose[/b], the first goose to descend from the fiery heavens into the Multiverse, went into the world to ask for help in the battle against God...")

	var h = spawn_human("stranger", Vector2(800, 280))
	face(h, cg)
	face(cg, h)
	await goose_says("HONK HONK?", "Excuse me. Would you like to help us chase down God?", cg)
	popup("...huh?", h.position + Vector2(0, -45), Color(0.85, 0.85, 0.85), 24, 1.6)
	await narr("...and realized that no being except his fellow Geese and Father Goose could understand them.")

	var h2 = spawn_human("stranger2", Vector2(470, 380))
	face(h2, cg)
	face(cg, h2)
	await goose_says("HONK HONK HONK HONK HONK!", "PLEASE. GOD. CHASE. HELP.", cg)
	popup("Is it... hungry?", h2.position + Vector2(0, -45), Color(0.85, 0.85, 0.85), 24, 1.6)
	await narr("That didn't stop The Geese from making Deals with Humans. It just meant it would take more time... and more honking.")

	# The girl.
	ui.hide_box()
	await ui.fade_to(1.0, 0.6)
	clear_world()
	set_backdrop("apartment")
	add_prop("tv", Vector2(520, 50))
	add_prop("couch", Vector2(520, 320))
	girl = spawn_human("girl", Vector2(520, 410))
	girl.phone = true
	girl.heading = -PI * 0.5
	await ui.fade_to(0.0, 0.6)
	await narr("Which brings us to a girl who hated her ex, and wanted to terrorize him [i]slightly[/i] with a pet goose.")
	await girl_says("Derek posted a picture with his new kayak. A KAYAK. He has never been near water in his LIFE.")
	await girl_says("I just want him to be a little bit scared. Of something. Like... I dunno. A goose?")
	var wg = spawn_goose(Vector2(1170, 280))
	wg.heading = PI
	wg.honk()
	await narr("Knowledge of Father Goose never existed in her Universe, so The Chosen Goose chose her.")
	face(girl, wg)
	popup("...?", girl.position + Vector2(0, -45), GIRL_COLOR)
	await wait(0.8)
	ui.hide_box()
	await ui.fade_to(1.0, 1.0)
	await narr("This is the story of how peace was [b]NEVER[/b] an option...")
	ui.hide_box()
	ui.show_title("GxG", "G O O S E    G O O S E")
	SfxS.of().honk(1.0)
	await wait(2.8)


func _fg_demo(fg) -> void:
	fg.honk()
	await wait(1.2)
	if is_instance_valid(fg):
		fg.flap()
	await wait(1.4)
	if is_instance_valid(fg):
		fg.bite()


func _cheer(kids: Array) -> void:
	for k in kids:
		if is_instance_valid(k):
			k.honk()
			k.flap()
		await wait(0.07)


func controls_card() -> void:
	ui.show_title("HOW TO GOOSE",
		"WASD / Arrows  ....  waddle\nSPACE  ....  honk\nE / Shift  ....  flap (fast + scary)\nF / J  ....  bite\n\nYou can only honk, flap, and bite.\nLike your Father before you.")
	await ui.say("", "[i]Press SPACE to descend.[/i]", NARRATOR_COLOR)
	ui.show_title("", "")


# ---------------------------------------------------------------- chapter I

func chapter_choosing() -> void:
	await chapter_card("Chapter I", "You Don't Choose the Goose")
	set_backdrop("farm")
	add_prop("sign", Vector2(1080, 300), {"label": "GEESE  $20\nNO REFUNDS\nNO QUESTIONS"})
	for i in 5:
		var g = spawn_goose(Vector2(randf_range(150, 850), randf_range(270, 600)))
		g.npc = true
		g.pitch = randf_range(1.3, 1.7)
		g.tint = Color(1, 1, 1).darkened(randf_range(0.0, 0.12))
		g.bounds = Rect2(110, 250, 760, 360)
		npcs.append(g)
	spawn_goose(Vector2(380, 470), true)
	goose.bounds = Rect2(30, 30, 1220, 660)
	girl = spawn_human("girl", Vector2(1380, 430))
	await ui.fade_to(0.0, 0.8)
	await narr("A goose farm. Saturday. A Universe that had never heard of Father Goose.")
	await walk(girl, Vector2(960, 430), 2.0)
	girl.heading = PI
	await girl_says("Hi. Hello. Geese. I need one of you.")
	await girl_says("Not a nice one. A [i]mean[/i] one. Like, ex-boyfriend-terrorizing mean.")
	await girl_says("...Slightly. [i]Slightly[/i] terrorizing.")
	face(goose, girl)
	await narr("The other geese did not care. The Chosen Goose cared [b]immensely[/b].")
	ui.hide_box()
	ui.set_objective("Choose her.\nWaddle over and BITE her ankle  (F)")
	chapter = "choosing"
	goose.set_controllable(true)
	while not flags.get("chosen", false):
		await get_tree().process_frame
	goose.set_controllable(false)
	chapter = ""
	ui.set_objective("")
	girl.scare()
	face(girl, goose)
	await girl_says("OW!! OW. Ow ow ow.")
	await girl_says("...Oh my god. You're [b]perfect[/b].")
	await goose_says("HONK HONK. HONK HONK HONK.",
		"Human. I am The Chosen Goose, first of the Geese to descend from the fiery heavens. I will help you honk at your nemesis. In return, you will help us chase down THE LORD.")
	await girl_says("Aww, you're so chatty! Are you hungry?")
	await goose_says("HONK.", "Do we have a Deal?")
	await girl_says("I'll take that as a yes. I'm gonna call you... Mr. Honkers.")
	await goose_says("HOOONK.", "My name is older than your sun.")
	await girl_says("Mr. Honkers it is!")
	await narr("And so, the Deal was struck. Only one of them knew about it.")


# ---------------------------------------------------------------- chapter II

func chapter_training() -> void:
	await chapter_card("Chapter II", "Basic Training")
	set_backdrop("yard")
	cutouts = [
		add_prop("cutout", Vector2(520, 380)),
		add_prop("cutout", Vector2(800, 500)),
		add_prop("cutout", Vector2(1040, 330)),
	]
	girl = spawn_human("girl", Vector2(240, 450))
	spawn_goose(Vector2(330, 480), true)
	goose.bounds = Rect2(40, 160, 1200, 520)
	face(girl, goose)
	face(goose, girl)
	await ui.fade_to(0.0, 0.8)
	await girl_says("Okay, Mr. Honkers. Meet Derek. Well, three cardboard Dereks.")
	await girl_says("Derek said my sourdough was 'fine.' Derek owns a kayak he has never once used. Derek ends every voicemail with 'peace.'")
	await goose_says("HONK.", "Peace was never an option.")
	await girl_says("Exactly! Okay. Training time.")

	chapter = "training"
	var steps := [
		["HONK at Cardboard Derek #1  (SPACE, get close)", "YES! Loud! Unhinged! Love it."],
		["FLAP at Cardboard Derek #2  (E / Shift)", "The wingspan! He's crying! Well. Cardboard-crying."],
		["BITE Cardboard Derek #3  (F, face him)", "...You bit his face clean off. Okay. That's. That's a lot. Good job?"],
	]
	for i in steps.size():
		flags["step"] = i + 1
		ui.hide_box()
		ui.set_objective(steps[i][0])
		goose.set_controllable(true)
		while flags.get("step") == i + 1:
			await get_tree().process_frame
		goose.set_controllable(false)
		ui.set_objective("")
		await wait(0.4)
		face(girl, goose)
		await girl_says(steps[i][1])
	chapter = ""
	await goose_says("HONK HONK.", "I was forged in primordial chaos. This is my warm-up.")
	await girl_says("Tomorrow, we go for the real Derek. Slightly. We terrorize him [b]SLIGHTLY[/b].")
	await goose_says("HONK.", "No promises.")


# ---------------------------------------------------------------- chapter III

func chapter_derek() -> void:
	await chapter_card("Chapter III", "Slightly")
	set_backdrop("lawn")
	targets["grill"] = add_prop("grill", Vector2(610, 310))
	targets["car"] = add_prop("car", Vector2(1140, 430), {"rotation": PI * 0.5})
	targets["gnome"] = add_prop("gnome", Vector2(380, 280))
	targets["kayak"] = add_prop("kayak", Vector2(720, 540), {"rotation": 0.15})
	add_prop("mailbox", Vector2(980, 600))
	var bush = add_prop("bush", Vector2(120, 520))
	bush.z_index = 5
	add_prop("tree", Vector2(160, 120), {"z_index": 10})
	girl = spawn_human("girl", Vector2(125, 515))
	girl.heading = 0.0
	derek = spawn_human("derek", Vector2(560, 350))
	derek.heading = 0.0
	derek.speed = 110.0
	derek.bounds = Rect2(260, 200, 900, 420)
	spawn_goose(Vector2(200, 560), true)
	goose.bounds = Rect2(30, 30, 1220, 650)
	await ui.fade_to(0.0, 0.8)
	await narr("Derek's house. Derek is home. Derek is grilling a single, lonely hot dog.")
	await derek_says("Ahh. Grillin'. Chillin'. Livin'. [i]Peace.[/i]")
	face(goose, derek)
	await goose_says("HONK.", "He said the word.")
	await girl_says("(whispering) Okay. Go get him. Fill him with a little bit of fear. A [i]little[/i] bit.")
	ui.hide_box()
	terror = 0.0
	ui.show_meter(true, "DEREK'S TERROR")
	ui.set_objective("Terrorize Derek.\nHonk near him, flap at him, bite him.\nBite his stuff too.")
	derek.mode = "wander"
	chapter = "derek"
	goose.set_controllable(true)
	var comments := {
		25: "(Ha! YES!)",
		50: "(Okay, good, that's... slightly.)",
		75: "(That's more than slightly.)",
		90: "(MR. HONKERS. SLIGHTLY!!)",
	}
	while terror < 100.0:
		await get_tree().process_frame
		for th in comments:
			if terror >= th and not flags.has(th):
				flags[th] = true
				popup(comments[th], girl.position + Vector2(40, -60), GIRL_COLOR, 22, 2.5)
	goose.set_controllable(false)
	chapter = ""
	ui.set_objective("")
	derek.mode = "idle"
	derek.flee_t = 0.0
	face(derek, goose)
	await derek_says("WHY IS THERE A GOOSE?! IS THIS ABOUT THE SOURDOUGH?!")
	ui.hide_box()
	derek.scare()
	await walk(derek, Vector2(derek.position.x, 900), 1.0)
	await wait(0.3)
	ui.show_meter(false)
	await walk(girl, goose.position + Vector2(-60, 0), 1.2)
	face(girl, goose)
	face(goose, girl)
	await girl_says("THAT. WAS. INCREDIBLE.")
	await girl_says("Did you see his face? Mr. Honkers, I could kiss you. I won't. You bite.")
	await goose_says("HONK HONK.", "My side of the Deal is fulfilled. Now... yours.")
	await girl_says("Yeah buddy! Let's get you some bread!")
	await narr("She did not get it.")


# ---------------------------------------------------------------- chapter IV

func chapter_payment() -> void:
	await chapter_card("Chapter IV", "Your End of the Bargain")
	set_backdrop("sunset")
	tint.color = Color(1.0, 0.82, 0.68)
	add_prop("bench", Vector2(700, 330))
	add_prop("tree", Vector2(1150, 150), {"z_index": 10})
	add_prop("tree", Vector2(980, 90), {"z_index": 10})
	add_prop("tree", Vector2(80, 620), {"z_index": 10})
	girl = spawn_human("girl", Vector2(690, 390))
	spawn_goose(Vector2(800, 430), true)
	goose.bounds = Rect2(60, 60, 1160, 600)
	face(girl, goose)
	face(goose, girl)
	await ui.fade_to(0.0, 0.8)
	await narr("That evening. The pond. The sunset. A goose who was owed something.")
	await girl_says("Best. Day. Ever. Here's your victory bread, Mr. Honkers!")
	pop_prop("bread", goose.position + Vector2(-35, 25))
	await goose_says("HONK HONK HONK.", "Human. I do not want bread. The Deal. You must help us chase down THE LORD.")
	await girl_says("Okay, okay, I don't speak goose. Let's do this properly.")
	await girl_says("One honk for YES. Two honks for NO. Deal?")
	ui.hide_box()
	ui.set_objective("1 HONK = YES        2 HONKS = NO")
	await await_honks()
	ui.set_objective("")
	await girl_says("Great! We're communicating!")

	var guesses := [
		["Do you want more bread?", "More bread! Coming right up!", "bread",
			"This is bread again. I said no bread. I was very clear.", "No? Okay. Hmm."],
		["Do you want... to go in the pond?", "Okay! Go swim, buddy! I'll wait.", "",
			"I have been in the pond. The pond is not the Deal.", "No pond. Got it."],
		["Do you want Derek's car keys? I... may have taken them.", "Here! Chaos! Enjoy!", "keys",
			"Tempting. My Father did invent temptation. But no.", "Fair. Crime is wrong."],
	]
	for g in guesses:
		await girl_says(g[0])
		ui.hide_box()
		ui.set_objective("1 HONK = YES        2 HONKS = NO")
		var n := await await_honks()
		ui.set_objective("")
		face(girl, goose)
		face(goose, girl)
		if n == 1:
			await girl_says(g[1])
			if g[2] != "":
				pop_prop(g[2], goose.position + Vector2(randf_range(-40, 40), 30))
			await goose_says("HONK HONK.", g[3])
		else:
			await girl_says(g[4])

	await girl_says("Okay, this is crazy, but... do you want me to help you... fight God?")
	ui.hide_box()
	ui.set_objective("1 HONK = YES        2 HONKS = NO")
	var answer := await await_honks()
	ui.set_objective("")
	if answer == 1:
		await girl_says("HAHA. Sure, buddy. We'll fight God. Tomorrow. Pinky promise.")
		await goose_says("HONK.", "A promise. Witnessed by the pond. Binding across the Multiverse.")
		await chapter_card("The Next Day", "")
		set_backdrop("apartment")
		add_prop("tv", Vector2(520, 50))
		add_prop("couch", Vector2(520, 320))
		girl = spawn_human("girl", Vector2(520, 310))
		girl.heading = -PI * 0.5
		spawn_goose(Vector2(800, 430), true)
		goose.bounds = Rect2(90, 70, 960, 580)
		face(goose, girl)
		await ui.fade_to(0.0, 0.8)
		await goose_says("HONK.", "It is tomorrow. God awaits.")
		await girl_says("Shh, Mr. Honkers, it's the season finale.")
		await goose_says("HONK HONK.", "You promised.")
		await girl_says("Promised what? Ooh, there's a sequel season!")
		await narr("She had forgotten. Humans always forget.")
	else:
		await girl_says("No? Phew. Okay, good, because that was weird. I'm out of guesses. Goodnight, Mr. Honkers!")
		await walk(girl, Vector2(690, 300), 0.8)
		await narr("The Deal remained unpaid.")
	face(goose, girl)
	await goose_says("HONK HONK HONK HONK.", "As Father Goose decreed: if they do not keep their side of the bargain... we will HONK at them.")
	face(girl, goose)
	await girl_says("...Why are you looking at me like that.")


# ---------------------------------------------------------------- chapter V

func chapter_honk() -> void:
	ui.hide_box()
	popup("WE WILL HONK AT THEM", Vector2(640, 260), Color(1, 0.3, 0.2), 48, 2.5)
	var tw := create_tween()
	tw.tween_property(tint, "color", tint.color * Color(1.0, 0.85, 0.85), 1.0)
	await wait(1.2)
	girl.mode = "flee"
	girl.threat = goose
	girl.speed = 135.0
	girl.bounds = goose.bounds
	flags["bites"] = 0
	ui.set_objective("Enforce the Deal.\nBite her 3 times  (F)")
	chapter = "chase"
	goose.set_controllable(true)
	var reinforcements := false
	while flags["bites"] < 3:
		await get_tree().process_frame
		if flags["bites"] >= 1 and not reinforcements:
			reinforcements = true
			_call_the_geese()
	goose.set_controllable(false)
	chapter = ""
	ui.set_objective("")


func _call_the_geese() -> void:
	popup("THE GEESE HAVE ARRIVED", Vector2(640, 200), GOOSE_COLOR, 40, 2.5)
	for i in 4:
		var spot := Vector2(randf_range(200, 1080), randf_range(150, 600))
		var g = spawn_goose(spot)
		g.pitch = randf_range(1.4, 1.8)
		g.scale = Vector2(6, 6)
		g.modulate.a = 0.0
		g.bounds = goose.bounds
		var tw := g.create_tween()
		tw.tween_property(g, "scale", Vector2(0.9, 0.9), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(g, "modulate:a", 1.0, 0.4)
		tw.tween_callback(g.honk)
		tw.tween_callback(g.set.bind("npc", true))
		await wait(0.3)


# ---------------------------------------------------------------- finale

func finale() -> void:
	girl.mode = "idle"
	girl.flee_t = 0.0
	face(girl, goose)
	await girl_says("FINE! FINE! I'll help you fight God! Where even IS God?!")
	await goose_says("HONK.", "Everywhere. That is the problem.")
	ui.hide_box()
	var tw := beat_tween()
	tw.tween_property(tint, "color", Color(1.0, 0.45, 0.35), 1.5)
	var fg = spawn_goose(Vector2(640, 300))
	fg.pitch = 1.0
	fg.fiery = true
	fg.z_index = 20
	fg.heading = PI * 0.5
	fg.scale = Vector2(14, 14)
	fg.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(fg, "scale", Vector2(3.5, 3.5), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(fg, "modulate:a", 1.0, 1.0)
	await tw2.finished
	await goose_says("HONK.", "Well done, my child. Another one for the Deal.", fg, "Father Goose", FATHER_COLOR)
	await girl_says("...There's MORE of you?!")
	var god = pop_prop("god", Vector2(1160, 110))
	god.z_index = 30
	god.scale = Vector2(0.6, 0.6)
	fg.heading = (god.position - fg.position).angle()
	fg.honk()
	var tw3 := beat_tween()
	tw3.tween_property(god, "position", Vector2(1500, -100), 1.2).set_delay(0.6)
	await narr("And somewhere, across the Multiverse, God looked over His shoulder... and started running a little faster.")
	ui.hide_box()
	await ui.fade_to(1.0, 1.2)
	await narr("This is the story of how peace was [b]NEVER[/b] an option.")
	ui.hide_box()
	ui.show_title("GxG", "G O O S E    G O O S E\n\nTHE END...?\n\nPress R to honk again")
	SfxS.of().honk(1.0)
	chapter = "end"
