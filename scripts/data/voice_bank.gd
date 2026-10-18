class_name VoiceBank
extends RefCounted
## 配音资源表：**接配音时只需要改这一个文件**（对话框只说 `"voice": "<ID>"`）。
##
## 目录约定（相对 `ROOT`）：
##
##     <说话人目录>/<台词 ID>.ogg
##
## 例：`{"speaker": "陈默", "text": "…", "voice": "ch01_0012"}`
##     -> `res://assets/audio/voice/chenmo/ch01_0012.ogg`
##
## 为什么要"按角色分目录 + 台词 ID"：
##   剧本里写的是稳定的 ID，换声优、换格式（ogg/wav/mp3）、换文件名都只动这张表；
##   台词 ID 又能直接当成"该录哪些台词"的清单，交给录音或 TTS 批量产出。
##
## **当前没有任何配音素材**（用户要求先只做系统），所以这里只有目录约定，
## 没有素材时 Voice 单例会静默跳过并把 ID 记进 missing_log，不会打断对话、不会刷报错。

const ROOT := "res://assets/audio/voice/"

## 说话人 -> 配音目录 / 音色微调。
## pitch 用来让"同一个声优素材"扮演不同角色（例如精灵 Alyina 用偏高一点的声音）。
const SPEAKERS := {
	"周明远": {"dir": "zhoumingyuan", "pitch": 1.0, "volume_db": 0.0},
	"李安雅": {"dir": "li_anya", "pitch": 1.0, "volume_db": 0.0},
	"艾莉娜": {"dir": "alyina", "pitch": 1.18, "volume_db": 0.0},
	"陈默": {"dir": "chenmo", "pitch": 0.95, "volume_db": 0.0},
	"看书的女生": {"dir": "student_f", "pitch": 1.05, "volume_db": 0.0},
}

## 台词 ID -> 文件名（相对 ROOT）。可以留空：
##   · 留空时 Voice 会按"角色目录 + ID"约定去猜路径；
##   · 想让某个 ID 指向别的文件（例如共用一句"嗯"）时再在这里登记。
const LINES := {}

## 找不到 .ogg 时依次尝试的扩展名
const EXTS := [".ogg", ".wav", ".mp3"]


## 说话人对应的配音目录；没登记的角色返回空串
static func speaker_dir(speaker: String) -> String:
	if not SPEAKERS.has(speaker):
		return ""
	return String(SPEAKERS[speaker].get("dir", ""))


## 说话人的音高倍率（1.0 = 原样）
static func speaker_pitch(speaker: String) -> float:
	if not SPEAKERS.has(speaker):
		return 1.0
	return float(SPEAKERS[speaker].get("pitch", 1.0))


## 说话人的音量补偿（dB）
static func speaker_volume_db(speaker: String) -> float:
	if not SPEAKERS.has(speaker):
		return 0.0
	return float(SPEAKERS[speaker].get("volume_db", 0.0))


## 台词表里登记的路径；没登记返回空串
static func line_path(id: String) -> String:
	if id == "" or not LINES.has(id):
		return ""
	var value: Variant = LINES[id]
	if value is String:
		return ROOT + String(value) if String(value) != "" else ""
	if value is Dictionary:
		var file := String((value as Dictionary).get("file", ""))
		return ROOT + file if file != "" else ""
	return ""


## 登记的台词 ID 列表（启动自检 / 配音清单用）
static func declared_ids() -> Array:
	return LINES.keys()


## 按"角色目录 + 台词 ID"推导出的候选路径（含各种扩展名）。
## 调用方逐个判存在即可 —— 这样换格式不用改表。
static func guess_candidates(speaker: String, id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := speaker_dir(speaker)
	if dir == "" or id == "":
		return out
	for ext: String in EXTS:
		out.append("%s%s/%s%s" % [ROOT, dir, id, ext])
	return out
