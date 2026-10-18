class_name Portraits
extends RefCounted
## 角色头像表：**说话人名字 -> 头像图片路径**。
##
## 为什么要有这张表：
##   对话数据里只写 speaker（例如 {"speaker": "周明远", ...}），
##   头像由名字自动解析，这样**剧本数据不用到处填图片路径**，
##   换素材或加角色只改这一处。
##
## 现有配角头像来自 Kenney Roguelike Characters（CC0，见 docs/THIRD_PARTY_ASSETS.md）。
## Noel / Alice / Celia 的正式像素头像则放在同一目录，由生成管线处理为 64x64 透明 PNG。
##
## 替换成正式立绘的方法：把对应条目的 path 换成新图即可，调用方不用动。

const DIR := "res://assets/graphics/portraits/"
const ZHOU_SPIRIT := DIR + "generated/zhou_spirit/portrait.png"
const ZHOU_PAST := DIR + "generated/photo_uniform/zhou.png"
const ALYINA_HD := DIR + "generated/celia/processed/anime.png"

## 说话人名 -> 文件名（不含目录）
const PORTRAITS := {
	"周明远": "noel.png",
	"诺诶尔": "noel.png",
	"Noel": "noel.png",
	"李安雅": "li_anya.png",
	"艾莉娜": "celia.png",   # 旧剧本别名
	"西莉亚": "celia.png",
	"Celia": "celia.png",
	"爱丽丝": "alice.png",
	"Alice": "alice.png",
	"陈默": "chenmo.png",
	"看书的女生": "student_f.png",
	"排队的同学": "student_m.png",
	"端着饭盒的同学": "student_m.png",
	"买文具的同学": "student_m.png",
	"取证件照的同学": "student_m.png",
	# ⚠️ 名字跟 `CampusData` 里那位 NPC 的 `display_name` **必须一致**：
	#    08 把"同层的同学"改成了"**同宿舍楼的同学**"（艾莉娜入队那一段），
	#    改数据不改这里的话，他只是"没有立绘"而已 —— 不报错，很难发现。
	"同层的同学": "student_m.png",
	"同宿舍楼的同学": "student_m.png",
	"抱着课本的同学": "student_m.png",
	"抄板书的同学": "student_m.png",
	"刚出图书馆的同学": "student_m.png",
	"还书的同学": "student_m.png",
	"校医院门口的同学": "student_m.png",
	"跑步的同学": "student_m.png",
	"拉伸的同学": "student_m.png",
}

## 情绪变体表（可选）：说话人名 -> { 情绪 -> 文件名 }。
## 对话数据里写 `"emotion": "无语"` 时，先来这里找对应表情的立绘；
## 没登记就回退到 PORTRAITS 的默认头像 —— 所以"表情还没画"不会导致没头像。
## 例： "陈默": {"无语": "chenmo_blank.png", "微笑": "chenmo_smile.png"},
const EMOTIONS := {}


## 按说话人名（+可选情绪）解析头像；没有对应头像时返回 null（对话框会自动收起立绘位）
static func resolve(speaker: String, emotion: String = "", form: String = "") -> Texture2D:
	# 明确标记的两种形态可以在同一场景、同一段对话中同时出现。
	if speaker in ["周明远（灵魂体）", "周明远（意识体）"]:
		return _load(ZHOU_SPIRIT)
	if speaker in ["周明远（过去本体）", "周明远（本体）"]:
		return _load(ZHOU_PAST)
	if speaker in ["周明远", "诺诶尔", "Noel"]:
		if form == "spirit":
			return _load(ZHOU_SPIRIT)
		if form == "past":
			return _load(ZHOU_PAST)
	if GameState.chapter >= 1:
		if speaker == "陈默":
			return _load(DIR + "generated/photo_uniform/chenmo.png")
		if speaker == "李安雅":
			return _load(DIR + "generated/photo_uniform/li_anya.png")
		if speaker in ["艾莉娜", "西莉亚", "Celia"]:
			return _load(ALYINA_HD)
		if speaker in ["周明远", "诺诶尔", "Noel"]:
			return _load(ZHOU_SPIRIT if HighschoolData.is_night(GameState.phase) else ZHOU_PAST)
	if emotion != "" and EMOTIONS.has(speaker):
		var table: Dictionary = EMOTIONS[speaker]
		if table.has(emotion):
			var variant := _load(DIR + String(table[emotion]))
			if variant != null:
				return variant
	if speaker == "" or not PORTRAITS.has(speaker):
		return null
	return _load(DIR + String(PORTRAITS[speaker]))


static func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 该说话人是否有头像（供 UI 或调试判断）
static func has_portrait(speaker: String) -> bool:
	return resolve(speaker) != null
