extends Node
## 背景音乐系统（自动加载单例 Music）
##
## 设计目标（对应需求 2）：通用、可在任意场景随时切换 / 播放 / 关闭，跨场景不中断。
## 实现方式：两个 AudioStreamPlayer 交叉淡入淡出，按"曲目 ID"播放，而不是按文件路径，
## 这样以后换素材只改 TRACKS 表，调用处（Music.play("menu")）完全不用动。

## 曲目表：track_id -> { path, title, loop }
## 各曲目来源和授权状态见 docs/THIRD_PARTY_ASSETS.md，改素材只改本表。
const TRACKS := {
	"tower_book": {"path":"res://assets/audio/bgm/tower/book.ogg", "title":"书海 · Dark Shrine Loop（qubodup / yd，CC0）", "gain_db":-3.0, "loop":true},
	"tower_ranking": {"path":"res://assets/audio/bgm/tower/ranking.ogg", "title":"成绩单 · Marionettes Piano（Bobjt，CC0）", "gain_db":-3.0, "loop":true},
	"tower_magician": {"path":"res://assets/audio/bgm/tower/magician.ogg", "title":"魔术舞台 · Ring Master Black Build III（Bobjt，CC0）", "gain_db":-3.0, "loop":true},
	"tower_infirmary": {"path":"res://assets/audio/bgm/tower/infirmary.ogg", "title":"医务室 · Insistent（yd，CC0）", "gain_db":-3.0, "loop":true},
	"tower_claustrophobia": {"path":"res://assets/audio/bgm/tower/claustrophobia.ogg", "title":"幽闭 · Pressure（yd，CC0）", "gain_db":-3.0, "loop":true},
	"tower_perfect": {"path":"res://assets/audio/bgm/tower/perfect.ogg", "title":"满分执念 · The Rush（tebruno99，CC0）", "gain_db":-3.0, "loop":true},
	"tower_thunder": {"path":"res://assets/audio/bgm/tower/thunder.ogg", "title":"雷霆训诫 · Epic Boss Battle（Juhani Junkala，CC0）", "gain_db":-3.0, "loop":true},
	"tower_math": {"path":"res://assets/audio/bgm/tower/math.ogg", "title":"数学考场 · Fighting Is Not an Option（Cleyton Kauffman，CC0）", "gain_db":-3.0, "loop":true},
	"tower_phantom": {"path":"res://assets/audio/bgm/tower/phantom.ogg", "title":"苦痛幻灵 · Vampire's Piano（TAD，CC0）", "gain_db":-3.0, "loop":true},
	"tower_panic": {"path":"res://assets/audio/bgm/tower/panic.ogg", "title":"无声扼喉 · Dark Intro（Nikke，CC0）", "gain_db":-3.0, "loop":true},
	"tower_injury": {"path":"res://assets/audio/bgm/tower/injury.ogg", "title":"旧伤回响 · Evil Approach（nene，CC0）", "gain_db":-3.0, "loop":true},
	"tower_training": {"path":"res://assets/audio/bgm/tower/training.ogg", "title":"阴雨低压 · Unchained Destiny（nene，CC0）", "gain_db":-3.0, "loop":true},
	"tower_mirror": {"path":"res://assets/audio/bgm/tower/mirror.ogg", "title":"破限镜像 · Fight for Better Future（nene，CC0）", "gain_db":-3.0, "loop":true},
	"battle_victory": {"path":"res://assets/audio/bgm/results/battle_victory.ogg", "title":"胜利 · Win Jingle（Fupi，CC0）", "gain_db":-3.0, "loop":false},
	"battle_defeat": {"path":"res://assets/audio/bgm/results/battle_defeat.ogg", "title":"失利 · No Hope（Cleyton Kauffman，CC0）", "gain_db":-3.0, "loop":false},
	"finale_descent": {"path":"res://assets/audio/bgm/finale/descent.ogg", "title":"终末回响 I · The Final Battle", "gain_db":-3.0, "loop":true},
	"finale_resistance": {"path":"res://assets/audio/bgm/finale/resistance.ogg", "title":"终末回响 II · Boss Battle Theme", "gain_db":-3.0, "loop":true},
	"finale_dawn": {"path":"res://assets/audio/bgm/finale/dawn.ogg", "title":"终末回响 III · Hope", "gain_db":-3.0, "loop":true},
	"school_gymnastics": {"path": "res://assets/audio/bgm/school_gymnastics.ogg", "title": "全国中学生广播体操 · 放飞理想（口令）", "loop": true, "gain_db": -10.0},
	"school_running": {"path": "res://assets/audio/bgm/school_running.mp3", "title": "阳光体育 · 运动员进行曲", "loop": true, "gain_db": -9.0},
	"spirit_memory": {
		"path": "res://assets/audio/bgm/spirit_first_light_loop.ogg",
		"title": "灵域 · 初光微粒（First Light Particles，CC0）",
		"gain_db": -2.0,
		"loop": true,
	},
	"spirit_depth": {
		"path": "res://assets/audio/bgm/spirit_consciousness_loop.ogg",
		"title": "灵域 · 意识萌芽（The Budding of Consciousness，CC0）",
		"gain_db": -2.0,
		"loop": true,
	},
	"menu": {
		"path": "res://assets/audio/bgm/title_theme_loop.mp3",
		"title": "标题画面 · Title Theme",
		"gain_db": -3.0,
		"loop": true,
	},
	"campus_day": {
		"path": "res://assets/audio/bgm/campus_day.ogg",
		"title": "校园 · 白天（慵懒大学生活）",
		"loop": true,
	},
	"campus_sunset": {
		"path": "res://assets/audio/bgm/campus_sunset.ogg",
		"title": "校园 · 夕阳（放学后的暖色时光）",
		"loop": true,
	},
	"campus_night": {
		"path": "res://assets/audio/bgm/campus_night.wav",
		"title": "校园 · 夜间（安静的校园灯光）",
		"loop": true,
	},
	"highschool_day": {
		"path": "res://assets/audio/bgm/highschool_day.ogg",
		"title": "高中校园 · 白天（Sunflower Valley）",
		"loop": true,
	},
	"highschool_sunset": {
		"path": "res://assets/audio/bgm/highschool_sunset.ogg",
		"title": "高中校园 · 夕阳（Etirwer）",
		"loop": true,
	},
	"highschool_night": {
		"path": "res://assets/audio/bgm/highschool_night.ogg",
		"title": "高中校园 · 夜间（Nighttime Solitude）",
		"loop": true,
	},
	"dorm_calm": {
		"path": "res://assets/audio/bgm/dorm_calm.ogg",
		"title": "宿舍 · 安静日常",
		"loop": true,
	},
	"highschool_dorm_room": {
		"path": "res://assets/audio/bgm/dorm_calm.ogg",
		"title": "高中宿舍 · Forget Me Not（Kistol，CC0）",
		"loop": true,
	},
	"highschool_dorm_corridor": {
		"path": "res://assets/audio/bgm/highschool_dorm_corridor.ogg",
		"title": "高中宿舍走廊 / 洗漱间 · Hot Springs Town（Kistol，CC0）",
		"loop": true,
	},
	"morning_birds": {
		"path": "res://assets/audio/bgm/morning_birds.ogg",
		"title": "翌日清晨 · 鸟鸣（Ambient Bird Sounds，CC0）",
		"loop": true,
	},
	"canteen_upbeat": {
		"path": "res://assets/audio/bgm/canteen_upbeat.ogg",
		"title": "食堂 · 欢快忙碌",
		"loop": true,
	},
	"teaching_bright": {
		"path": "res://assets/audio/bgm/teaching_bright.wav",
		"title": "教学楼 · 阳光校园",
		"loop": true,
	},
	"opening_underwater": {
		"path": "res://assets/audio/bgm/opening_underwater.wav",
		"title": "开场 CG · 水下坠落气泡（CC0）",
		"loop": true,
	},
	"opening_ethereal": {
		# 旧 ID 保留兼容；开场场景现在使用 opening_underwater。
		"path": "res://assets/audio/bgm/opening_underwater.wav",
		"title": "开场 CG · 水下坠落气泡（兼容 ID）",
		"loop": true,
	},
	"alyina_cg_playful": {
		"path": "res://assets/audio/bgm/alyina_cg_fairies_talking.ogg",
		"title": "艾莉娜登场 CG · 轻声奇幻（Fairies Talking，CC0）",
		"loop": true,
	},
	"angel_covenant": {
		"path": "res://assets/audio/bgm/angel_covenant_heavenly_loop.ogg",
		"title": "天使立约 · Heavenly Loop（CC0）",
		"loop": true,
	},
	"highschool_abandoned": {
		"path": "res://assets/audio/bgm/abandoned_factory_cc0.ogg",
		"title": "废弃校园 · Factory ambiance（CC0）",
		"loop": true,
	},
	"time_rewind": {
		"path": "res://assets/audio/bgm/portal_searching_cc0.ogg",
		"title": "传送门 · Searching（CC0）",
		"loop": true,
	},
	## 旧夜间 ID 保留兼容；高中外景使用独立的 highschool_night。
	"night": {
		"path": "res://assets/audio/bgm/highschool_night.ogg",
		"title": "高中校园 · 夜间（兼容 ID）",
		"loop": true,
	},
	"battle_theme_a": {
		"path":"res://assets/audio/bgm/battle/battle_theme_a.ogg",
		"title":"战斗 · Battle Theme A（cynicmusic，CC0）", "gain_db":-3.0, "loop":true,
	},
	"battle_theme_b": {
		"path":"res://assets/audio/bgm/battle/battle_theme_b.ogg",
		"title":"战斗 · Battle Theme B（cynicmusic，CC0）", "gain_db":-3.0, "loop":true,
	},
	"battle_epic_rock": {
		"path":"res://assets/audio/bgm/battle/battle_epic_rock.ogg",
		"title":"战斗 · JRPG Epic Rock（HydroGene，CC0）", "gain_db":-3.0, "loop":true,
	},
	"battle_pursuit": {
		"path":"res://assets/audio/bgm/battle/battle_pursuit.ogg",
		"title":"战斗 · Determined Pursuit（Emma_MA，CC0）", "gain_db":-3.0, "loop":true,
	},
	"battle": {
		"path": "res://assets/audio/bgm/junkala_boss_fight.ogg",
		"title": "战斗 - Boss Fight",
		# 源文件 -11.44 LUFS；地图约 -24 LUFS，补偿后约 -23.44 LUFS。
		"gain_db": -12.0,
		"loop": true,
	},
}

const DEFAULT_FADE := 1.0

var current_track: String = ""
var is_playing: bool = false
## 临时剧情音乐覆盖：地图的常规音乐同步在覆盖期间让路，避免下一帧切回场景 BGM。
var _override_track: String = ""

signal track_changed(track_id: String)

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade_tween: Tween
var _stopping := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停菜单里音乐也要能继续
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "BgmPlayer%d" % i
		p.bus = AudioManager.BUS_MUSIC
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	# 让音量设置先生效
	AudioManager.apply_volumes.call_deferred()


func has_track(track_id: String) -> bool:
	return TRACKS.has(track_id)


func set_override(track_id: String, fade: float = DEFAULT_FADE) -> void:
	if not has_track(track_id):
		push_warning("Music.set_override: 未知曲目 '%s'" % track_id)
		return
	_override_track = track_id
	play(track_id, fade)


func clear_override() -> void:
	_override_track = ""


func has_override() -> bool:
	return _override_track != ""


## 取"按曲目表配置好循环标志"的音频流（不播放）。
## 供播放使用，也供自检/测试核对循环设置是否真的生效。
## 注意：直接 load(path) 拿到的是资源默认值（OGG 导入默认 loop=false），
## 所以判断循环必须走这里，而不是自己 load。
func get_configured_stream(track_id: String) -> AudioStream:
	if not TRACKS.has(track_id):
		return null
	return _load_stream(track_id)


func track_title(track_id: String = "") -> String:
	var id := track_id if track_id != "" else current_track
	if id == "" or not TRACKS.has(id):
		return ""
	return TRACKS[id]["title"]


func track_gain_db(track_id: String) -> float:
	return float(TRACKS.get(track_id, {}).get("gain_db", 0.0))


## 播放曲目。重复调用同一首不会重启（除非 restart=true）。
##
## ⚠️ 但"正在播"这件事要**问播放器本身**，不能只看 `is_playing`：
##    暂停菜单把 tree 暂停过之后，播放器可能停在 `stream_paused = true`，
##    而 `is_playing` 仍是 true —— 这时从暂停里回到标题，就会"该换的曲子没换"（实测踩到）。
func play(track_id: String, fade: float = DEFAULT_FADE, restart: bool = false) -> void:
	if not TRACKS.has(track_id):
		push_warning("Music.play: 未知曲目 '%s'" % track_id)
		return
	if track_id == current_track and is_playing and not restart and _really_playing():
		return
	# 上一次是被暂停挂起的：先把暂停状态摘掉，否则新曲子会以"暂停"的姿势开始
	_clear_pause()

	var stream := _load_stream(track_id)
	if stream == null:
		# 素材缺失时不算崩溃：记录下来，画面照常，方便美术没到位时开发
		push_warning("Music.play: 曲目 '%s' 的音频文件不存在，已跳过播放。" % track_id)
		current_track = track_id
		is_playing = false
		track_changed.emit(track_id)
		return

	_stopping = false
	var from := _players[_active]
	_active = 1 - _active
	var to := _players[_active]

	to.stream = stream
	to.volume_db = -80.0
	to.play()

	_kill_fade()
	var target_db := track_gain_db(track_id)
	if fade <= 0.01:
		to.volume_db = target_db
		from.stop()
	else:
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(to, "volume_db", target_db, fade)
		if from.playing:
			_fade_tween.tween_property(from, "volume_db", -80.0, fade)
			_fade_tween.chain().tween_callback(from.stop)

	current_track = track_id
	is_playing = true
	track_changed.emit(track_id)


## 关闭音乐
func stop(fade: float = DEFAULT_FADE) -> void:
	_kill_fade()
	is_playing = false
	_stopping = true
	var from := _players[_active]
	if not from.playing:
		current_track = ""
		return
	if fade <= 0.01:
		from.stop()
		current_track = ""
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(from, "volume_db", -80.0, fade)
	_fade_tween.tween_callback(func() -> void:
		from.stop()
		current_track = ""
	)


## 当前那个播放器**真的在出声**吗（正在播 且 不是挂起状态）
func _really_playing() -> bool:
	for p in _players:
		if p.playing and not p.stream_paused:
			return true
	return false


## 摘掉"暂停挂起"状态（不影响音量与当前曲目）。
## 用途：从暂停菜单/暂停的 tree 里回到别的场景时，别让新曲子以暂停的姿势开始。
func _clear_pause() -> void:
	for p in _players:
		if p.stream_paused:
			p.stream_paused = false


func pause() -> void:
	for p in _players:
		if p.playing:
			p.stream_paused = true
	is_playing = false


func resume() -> void:
	for p in _players:
		if p.playing:
			p.stream_paused = false
	is_playing = true


## 暂停 / 恢复切换（留给暂停菜单用）
func toggle_pause() -> void:
	if is_playing:
		pause()
	else:
		resume()


func _load_stream(track_id: String) -> AudioStream:
	var path: String = TRACKS[track_id]["path"]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	# 让 WAV / OGG / MP3 都按曲目表决定是否循环。
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var should_loop := bool(TRACKS[track_id]["loop"])
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
		if should_loop:
			# Godot 的 WAV 导入器会把未指定的 loop_end 留成 -1；一旦打开
			# LOOP_FORWARD，-1 会被当成无效区间，播放器随即停止。
			# 用采样数明确指定整首音频，避免 WAV 曲目“状态显示正在播放但没有声音”。
			wav.loop_begin = 0
			wav.loop_end = maxi(1, int(wav.get_length() * wav.mix_rate))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = bool(TRACKS[track_id]["loop"])
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = bool(TRACKS[track_id]["loop"])
	return stream


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
