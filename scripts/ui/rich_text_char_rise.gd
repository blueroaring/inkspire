class_name CharRiseEffect
extends RichTextEffect
## 打字机"逐字淡入 + 上浮"效果（BBCode：`[rise]...[/rise]`）。
##
## 参考 LingChat 的 char-rise 打字动画：新出现的字从下方轻轻浮上来并淡入，
## 而不是"啪"地整字出现，读起来更接近 galgame。
##
## 原理：`RichTextLabel` 每帧都会对范围内的每个字符调用一次 `_process_custom_fx`。
## 引擎不提供"字符自己的出现时刻"，所以我们用
## **该字符距离"打字头"还有多少个字符**当年龄：
## 刚露出来的字符 age=0（最透明、最靠下），露出超过 spread 个字符之后就恢复常态。
## 打字头连续推进，视觉上就是一条跟着打字头走的"上浮尾巴"。
##
## ⚠️ 两个容易踩的点（本文件都踩过）：
##   1) Godot 4 的虚函数叫 `_process_custom_fx(char_fx)`，
##      **不是** Godot 3 的 `_process_effect(effect, range, char_fx)`。
##      签名写错时不会报错 —— 效果"挂上了但从不执行"，画面上只是少个动画。
##   2) BBCode 标签名取自本类的 `bbcode` 属性（取不到时回退到脚本文件名），
##      必须与文本里的 `[rise]` 一致。

var bbcode := "rise"

## 由 DialogueBox 注入：要观察的那个标签（取它的 visible_characters 当打字头）
var label: RichTextLabel = null

## 尾巴长度（字符数）：越小越"干脆"，越大越"飘"。
## 注意年龄是按**字符**算的，所以尾巴的"时长"随打字速度变化：
## 默认打字 40 字/秒时 9 个字符约 0.22 秒，接近 LingChat 的 0.28s 手感。
var spread := 9.0
## 新字起始下沉的像素量
var rise_px := 9.0
## 新字起始透明度
var alpha_from := 0.0
## >= 0 时启用“原位逐字弹出”：整行保持布局，只把尚未轮到的字符隐藏。
## DialogueBox 仅在天使立约段设置它，普通对白仍走 visible_characters 打字机。
var reveal_count := -1

## 诊断计数：真正被改动过的字符数（走查用）。
## 为什么要有它：`custom_effects` 挂上了不等于效果在跑 —— 打字速度为 0（瞬间显示）
## 或者虚函数签名写错时，效果会静默失效，很难发现。
var applied_chars := 0
## 诊断计数：`_process_custom_fx` 被引擎调用的次数（为 0 = 标签没被识别/签名不对）
var calls := 0
## 诊断：最近一次调用时看到的 visible_characters（-1 表示整行已全显示）
var last_visible := -999


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	calls += 1
	if label == null:
		return false
	var visible_chars := label.visible_characters
	last_visible = visible_chars
	var head: float
	if reveal_count >= 0:
		head = float(reveal_count - 1)
	else:
		if visible_chars < 0:
			return false                  # 整行已全部显示，不需要动画
		head = float(visible_chars - 1)
	var age := head - float(char_fx.relative_index)
	if age < 0.0:
		if reveal_count >= 0:
			char_fx.color.a = 0.0
			return true                     # 尚未轮到的字符保持隐藏，但不改变布局
		return false                      # 普通模式下未来字符由 visible_characters 隐藏
	if age >= spread:
		return false                      # 早就"落定"了
	var t: float = clampf(1.0 - age / spread, 0.0, 1.0)   # 1 = 刚出现
	char_fx.offset.y += rise_px * t
	var c := char_fx.color
	c.a *= lerpf(1.0, alpha_from, t)
	char_fx.color = c
	applied_chars += 1
	return true
