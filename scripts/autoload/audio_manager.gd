extends Node
## 音频总线管理（自动加载单例 AudioManager）
##
## 职责：把游戏音量设置映射到音频总线，并提供全局音效播放。
## 背景音乐不在这里，见 Music 单例（它负责切换/淡入淡出/跨场景保持）。

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_VOICE := "Voice"

## 同时可叠加的音效播放器数量
const SFX_POOL_SIZE := 8
const SFX_GAIN_DB := 3.0
const VOICE_GAIN_DB := 3.0
## 旧版普通技能与剧情配音仍暂停；战斗播放器单独开放已交付的新录音。
const SPEECH_ENABLED := false
const ULTIMATE_SPEECH_ENABLED := true
const CARD_SELECT := preload("res://assets/audio/sfx/card_select.wav")
signal voice_availability_changed(enabled: bool)

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _voices_enabled := true


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_VOICE)
	# Peak protection for layered battle impacts and the louder voice mix.
	var master_index := AudioServer.get_bus_index(BUS_MASTER)
	var has_limiter := false
	for index in AudioServer.get_bus_effect_count(master_index):
		if AudioServer.get_bus_effect(master_index, index) is AudioEffectLimiter: has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master_index, limiter)
	_build_sfx_pool()
	apply_volumes()


## 确保存在名为 bus_name 的总线（不存在则从 Master 派生一个）
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, BUS_MASTER)


func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_sfx_players.append(p)


## 线性音量（0..1）转成分贝；0 直接静音，避免 -inf
func _linear_to_db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, _linear_to_db(clamped))
	AudioServer.set_bus_mute(idx, clamped <= 0.001)


## 把 Settings 里的音量同步到总线。Settings._ready 与设置界面改动时都会调用。
func apply_volumes() -> void:
	if not Settings:
		return
	_set_bus_volume(BUS_MASTER, float(Settings.get_value("audio", "master_volume", 1.0)))
	_set_bus_volume(BUS_MUSIC, float(Settings.get_value("audio", "music_volume", 1.0)))
	_apply_boosted_bus_volume(BUS_SFX, float(Settings.get_value("audio", "sfx_volume", 1.0)), SFX_GAIN_DB)
	_apply_boosted_bus_volume(BUS_VOICE, float(Settings.get_value("audio", "voice_volume", 1.0)), VOICE_GAIN_DB)
	var voice_bus := AudioServer.get_bus_index(BUS_VOICE)
	var enabled := Settings.all_voice_enabled()
	if not enabled and voice_bus >= 0:
		AudioServer.set_bus_mute(voice_bus, true)
	if enabled != _voices_enabled:
		_voices_enabled = enabled
		voice_availability_changed.emit(enabled)

func _apply_boosted_bus_volume(bus_name: String, linear: float, gain_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	var clamped := clampf(linear, 0.0, 1.0)
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, _linear_to_db(clamped) + gain_db if clamped > 0.001 else -80.0)
	AudioServer.set_bus_mute(idx, clamped <= 0.001)


## 播放一次性音效（自动轮流使用播放器，不做打断管理）
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## 清亮、短促的选牌提示，统一跟随音效音量。
func play_card_select() -> void:
	play_sfx(CARD_SELECT, -6.0)


## 播放 UI 音效（后续接入真实音效资源；现在没有资源时静默跳过）
func play_ui(kind: String = "click") -> void:
	var path := "res://assets/audio/sfx/%s.ogg" % kind
	if ResourceLoader.exists(path):
		play_sfx(load(path) as AudioStream)
