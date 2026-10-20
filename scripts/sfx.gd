extends Node
## Sound effects. Honks play sfx/honk.mp3; everything else is synthesized.
## Main adds one instance; everything else calls through Sfx.of().

const RATE := 22050.0
const HONK = preload("res://sfx/honk.mp3")
const HONK_VOICES := 12

static var instance: Node

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var buf := PackedFloat32Array()
var pos := 0
var honk_pool: Array[AudioStreamPlayer] = []
var honk_next := 0


static func of() -> Node:
	return instance


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	player.stream = gen
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	for i in HONK_VOICES:
		var hp := AudioStreamPlayer.new()
		hp.stream = HONK
		add_child(hp)
		honk_pool.append(hp)


func _process(_delta: float) -> void:
	if playback == null:
		return
	var n := playback.get_frames_available()
	for i in n:
		var s := 0.0
		if pos < buf.size():
			s = clampf(buf[pos], -1.0, 1.0)
			pos += 1
		playback.push_frame(Vector2(s, s))
	if buf.size() > 0 and pos >= buf.size():
		buf = PackedFloat32Array()
		pos = 0


func _mix(samples: PackedFloat32Array) -> void:
	for i in samples.size():
		var idx := pos + i
		if idx < buf.size():
			buf[idx] += samples[i]
		else:
			buf.append(samples[i])


func honk(p: float = 1.0) -> void:
	# Round-robin through the pool so bursts and choirs of geese overlap instead of cutting off.
	var hp: AudioStreamPlayer = honk_pool[honk_next]
	honk_next = (honk_next + 1) % honk_pool.size()
	hp.pitch_scale = p
	hp.play()


func yelp(p: float = 1.0) -> void:
	var n := int(0.18 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += lerpf(600.0, 1000.0, k) * p / RATE
		out[i] = sin(ph * TAU) * (1.0 - k) * 0.15
	_mix(out)


func bite() -> void:
	var n := int(0.06 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var k := float(i) / n
		out[i] = randf_range(-1.0, 1.0) * pow(1.0 - k, 3.0) * 0.3
	_mix(out)


func flap() -> void:
	var n := int(0.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var k := float(i) / n
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.25)
		var pulse := maxf(0.0, sin(k * PI * 6.0))
		out[i] = prev * pulse * 0.25
	_mix(out)


func alarm() -> void:
	var n := int(1.2 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var f := 700.0 if int(i / (0.2 * RATE)) % 2 == 0 else 900.0
		ph += f / RATE
		out[i] = (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.06
	_mix(out)
