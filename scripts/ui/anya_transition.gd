extends Control
signal finished
const ROOT := "res://assets/graphics/battle/anya/"
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ART := preload("res://scripts/data/battle_art.gd")
const AUDIO := preload("res://scripts/ui/battle_generated_audio.gd")
var kind := "enter"
var elapsed := 0.0
var real_elapsed := 0.0
var duration := 4.8
var minimum_seconds := 0.0
var completed := false
var video: VideoStreamPlayer
var plate: TextureRect
var veil: ColorRect
var title_group: Control
var wings: AnimatedSprite2D
var video_running := false
var audio_mixer: Node
var voice_key := ""

func _ready() -> void:
	name = "AnyaTransformation_" + kind
	size = Vector2(1920, 1080)
	z_index = 160
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.size = size
	black.color = Color("060b18")
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var returning := kind != "enter"
	plate = V.icon(self, load(ROOT + ("cg_return.webp" if returning else "cg_enter.webp")), Rect2(-40, -20, 2000, 1125))
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.modulate.a = 0
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("091128"), Color(0.035, 0.05, 0.1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	V.icon(self, texture, Rect2(0, 0, 1400, 1080)).stretch_mode = TextureRect.STRETCH_SCALE
	wings = AnimatedSprite2D.new()
	wings.sprite_frames = ART.effect_frames("anya_phoenix")
	wings.position = Vector2(1270, 465)
	wings.scale = Vector2.ONE * 2.8
	wings.modulate.a = 0
	add_child(wings)
	title_group = Control.new()
	title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_group.modulate.a = 0
	add_child(title_group)
	V.text(title_group, "幻羽涅槃  /  李安雅", Rect2(118, 450, 750, 35), 23, Color("dbbd8b"))
	V.text(title_group, "这一次，\n我们在一起！" if returning else "找到我，\n然后拯救我", Rect2(110, 510, 1000, 240), 74, Color("fff0d1"))
	V.text(title_group, "羽光散去，归来的人仍在彼此身旁。" if returning else "微薄的声音，也值得被世界听见。", Rect2(120, 787, 1000, 42), 24, Color("ced7ee"))
	for y in [0, 1008]:
		var bar := ColorRect.new()
		bar.position = Vector2(0, y)
		bar.size = Vector2(1920, 72)
		bar.color = Color("060b18")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	V.text(self, "涅槃·幻羽" if not returning else "被困之羽", Rect2(120, 24, 780, 30), 21, Color("d5bb93"))
	var skip_hint := V.text(self, "点击 / Esc 跳过", Rect2(1550, 1032, 280, 25), 16, Color("b2b9cc"), true)
	veil = ColorRect.new()
	veil.size = size
	veil.color = Color(1, 0.91, 0.73, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	audio_mixer = AUDIO.of(self)
	voice_key = "hero_anya_enter" if not returning else "hero_anya_defeated" if kind == "defeated" else "hero_anya_return"
	minimum_seconds = audio_mixer.play_voice(voice_key, 3, "li_anya")
	duration = maxf(duration, minimum_seconds)
	var movie_path := "res://assets/video/anya/" + ("enter.ogv" if not returning else "return.ogv")
	if ResourceLoader.exists(movie_path):
		video = VideoStreamPlayer.new()
		video.name = "TransformationVideo"
		video.size = size
		video.expand = true
		# The replacement MP3 supplies all cut-in audio, including for future videos.
		video.audio_track = -1
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		video.stream = load(movie_path)
		add_child(video)
		video.finished.connect(_end_video, CONNECT_ONE_SHOT)
		video.play()
		video_running = true
		move_child(skip_hint, get_child_count() - 1)
	else: _start_cg()

func _start_cg() -> void:
	elapsed = 0
	plate.modulate.a = 1
	title_group.modulate.a = 0

func _end_video() -> void:
	if not video_running: return
	video_running = false
	if is_instance_valid(video):
		video.stop()
		video.queue_free()
	_start_cg()

func _process(delta: float) -> void:
	if completed: return
	real_elapsed += delta
	if video_running:
		if real_elapsed > 16: _end_video()
		return
	elapsed += delta * minf(Settings.battle_effect_speed(), 1.5)
	var t := elapsed
	plate.position = Vector2(-40 + 18 * sin(minf(t, 4.8) * 0.5), -20)
	plate.modulate = Color(1, 1, 1, clampf(t / 0.5, 0, 1))
	title_group.position.x = -45 * (1 - smoothstep(1.0, 1.8, t))
	title_group.modulate.a = smoothstep(1.0, 1.8, t)
	if t > 0.72 and not wings.is_playing() and wings.frame == 0:
		wings.speed_scale = 0.30
		wings.modulate.a = 0.7
		wings.play()
	veil.color.a = maxf(0, 1.0 - absf(t - 1.18) / 0.14) * 0.36
	queue_redraw()
	if t >= duration and real_elapsed >= maxf(3.0, minimum_seconds): _finish()

func _draw() -> void:
	if video_running: return
	var fade := smoothstep(0.3, 1.5, elapsed) * (1 - smoothstep(duration - 0.6, duration, elapsed))
	for i in 55:
		var x := fmod(float(i * 173) + elapsed * (17 + i % 9), 1920)
		var y := fmod(float(i * 97) - elapsed * (24 + i % 17) + 2200, 1080)
		var opacity := fade * (0.2 + 0.5 * pow(sin(elapsed + i), 2))
		draw_line(Vector2(x, y), Vector2(x + 6, y - 12), Color("ffe1ac", opacity), 2, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _finish()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if completed: return
	completed = true
	if is_instance_valid(video): video.stop()
	_stop_audio()
	finished.emit()
	queue_free()

func _stop_audio() -> void:
	var keys: Array[String] = [voice_key]
	if is_instance_valid(audio_mixer): audio_mixer.stop_cues(keys)

func _exit_tree() -> void:
	_stop_audio()
