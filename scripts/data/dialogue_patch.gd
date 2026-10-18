class_name DialoguePatch
extends RefCounted
## 对话补丁：**不改源码**的台词覆盖层。
##
## ------------------------------------------------------------------ 它解决什么
##
## 项目里的台词散在十几个数据文件里，而且大部分是**算出来的**（带 `%s` 参数、
## 按剧情开关分支、按楼层生成教室号）。让一个 GUI 去"改写 GDScript 源码"既危险又
## 做不干净；所以走和**布局编辑器**完全相同的路子：
##
##     原始台词（各处数据/脚本）  →  DialoguePatch（覆盖层）  →  对话框
##
## 工具只碰 `data/dialogue_patch.json` 这一个文件，源码一行都不动。
## 补丁里没有的对话块 = 原样播原文；有 = 整段换成你编辑后的版本。
##
## ------------------------------------------------------------------ 三条纪律
##
##   ⚠️ **一个块要么整段被覆盖，要么完全不动**（不做"逐行打补丁"）。
##      逐行补丁在"你删了一行"之后所有下标都会错位 —— 那种补丁文件改两次就废了。
##      整段替换的代价是"上游改了原文、你的覆盖会把新原文挡住"，
##      所以每个块都存了一份 `base`（编辑时的原文快照），编辑器据此报"上游已变"。
##
##   ⚠️ **台词行里的 `flag` / `choices` 是剧情开关与分支**，不是文案。
##      编辑器会把它们原样保留；但如果你把带着 `flag` 的那一行删掉，剧情就会卡住。
##      所以编辑器在保存时会报"原文里有 N 个开关，你的版本里少了 X/Y"。
##
##   ⚠️ **自检默认忽略补丁**（`disabled = true`）：补丁是作者/玩家的文本覆盖，
##      不该让"剧情逻辑"的测试跟着变红。补丁本身由对话编辑器自己的自检负责。

const DEFAULT_PATH := "res://data/dialogue_patch.json"
const VERSION := 1

## 进程级缓存。编辑器可以和游戏同时运行，因此不能假定补丁文件在进程启动后永远不变；
## `current()` 会用文件内容指纹检查磁盘是否被对话编辑器更新。
static var _current: DialoguePatch = null
static var _disk_signature := ""
## 自检/剧情测试用的内存补丁不能被磁盘指纹检查覆盖。
static var _manual_override := false
## 走查/自检把它置 true：`apply()` 一律返回原文
static var disabled := false


var _path := DEFAULT_PATH
## id -> {"lines": Array, "base": Array}
var _blocks: Dictionary = {}


# ---------------------------------------------------------------- 进程级入口


## 当前生效的补丁。首次调用或磁盘内容变化时从磁盘读，读不到就是空补丁。
static func current() -> DialoguePatch:
	if _manual_override:
		return _current if _current != null else empty()
	var signature := _file_signature(DEFAULT_PATH)
	if _current == null or signature != _disk_signature:
		_current = load_from()
		_disk_signature = signature
	return _current


## 丢掉缓存，下次 `current()` 重新读盘（编辑器保存之后调它）。
##
## ⚠️⚠️ **名字不能叫 `reload()`**（2026-09-20 实测踩到，而且是静默失效的）：
##    `DialoguePatch` 这个 `class_name` 本身是一个 `GDScript` 对象，而它的基类
##    `Script` 已经有一个内建方法 `reload()`。写 `DialoguePatch.reload()` 时，
##    引擎解析到的是**内建那个**（重新加载脚本本身），于是：
##      · 我们的静态函数**一次都没被调用**（补丁缓存永远不刷新）；
##      · 屏幕上只多一条 `ERROR: Cannot reload script while instances exist.`，
##        而且它出现在对话编辑器"保存成功"之后 —— 很容易被当成无关噪音忽略。
##    表现就是用户 2026-09-20 报的那条："我修改的（台词）没生效"。
##    所以改名为 `reload_from_disk()`。**新增静态方法前先查基类有没有同名成员。**
static func reload_from_disk() -> void:
	_manual_override = false
	_current = null
	_disk_signature = ""


## **自检专用**：把一份内存补丁装成"当前生效的补丁"。
##
## 为什么需要它：想验证"补丁真的会改变游戏里播的台词"，就必须让某一段被覆盖 ——
## 但自检**绝不能去改磁盘上的 `data/dialogue_patch.json`**（作者可能正在里面写东西）。
## 于是给一个只改内存缓存的入口，测完再 `reload()` 还原。
static func install_for_test(patch: DialoguePatch) -> void:
	_manual_override = true
	_current = patch
	_disk_signature = "<test-override>"


## **运行时唯一入口**：把 [param id] 这一段台词过一遍补丁。
##
## [param lines] 传**原文**；没被覆盖就原样返回，被覆盖了就返回覆盖后的整段。
## 返回的是**深拷贝**，调用方随便改（例如 `AlyinaBanter` 会往后追加插话），
## 不会污染缓存。
static func apply(id: String, lines: Array) -> Array:
	if disabled or id == "":
		return lines
	return current().patched(id, lines)


# ---------------------------------------------------------------- 读 / 写


static func load_from(path: String = DEFAULT_PATH) -> DialoguePatch:
	var patch := DialoguePatch.new()
	patch._path = path
	if not FileAccess.file_exists(path):
		return patch
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("DialoguePatch: 打不开 %s" % path)
		return patch
	var text := f.get_as_text()
	f.close()
	return from_json(text, path)


static func empty() -> DialoguePatch:
	return DialoguePatch.new()


static func from_json(text: String, path: String = DEFAULT_PATH) -> DialoguePatch:
	var patch := DialoguePatch.new()
	patch._path = path
	if text.strip_edges() == "":
		return patch
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("DialoguePatch: %s 不是合法 JSON，按空补丁处理" % path)
		return patch
	var root: Dictionary = parsed
	var blocks: Variant = root.get("blocks", {})
	if not (blocks is Dictionary):
		return patch
	for id_variant in (blocks as Dictionary):
		var id := String(id_variant)
		var entry: Variant = (blocks as Dictionary)[id_variant]
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		var lines: Array = e.get("lines", [])
		var base: Array = e.get("base", [])
		if lines.is_empty() and base.is_empty():
			continue
		patch._blocks[id] = {"lines": lines.duplicate(true), "base": base.duplicate(true)}
	return patch


func to_json() -> String:
	var blocks := {}
	# 排序后再写：同一个补丁反复保存不会产生"顺序不同"的假 diff
	var ids := _blocks.keys()
	ids.sort()
	for id_variant in ids:
		var id := String(id_variant)
		var entry: Dictionary = _blocks[id]
		blocks[id] = {
			"base": entry["base"],
			"lines": entry["lines"],
		}
	return JSON.stringify({
		"note": "对话补丁（由 tools/dialogue_editor.tscn 生成，也可手写）。"
			+ "这是**覆盖层**：补丁里没有的对话块原样播原文；有的话整段换成这里的 lines。"
			+ "⚠️ 台词行里的 flag/choices 是剧情开关与分支，删掉会让剧情卡住。",
		"version": VERSION,
		"blocks": blocks,
	}, "  ")


func save_to(path: String = "") -> String:
	var target := path if path != "" else _path
	var f := FileAccess.open(target, FileAccess.WRITE)
	if f == null:
		return "打不开 %s（错误码 %d）" % [target, FileAccess.get_open_error()]
	f.store_string(to_json() + "\n")
	f.close()
	_path = target
	return ""


## 读取补丁文件的轻量指纹。每次交互只读一个很小的 JSON 文件，
## 用内容指纹而非修改时间，避免 Windows 同一秒内连续保存时漏掉更新。
static func _file_signature(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<missing>"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "<unreadable:%d>" % FileAccess.get_open_error()
	var text := f.get_as_text()
	f.close()
	return "%d:%d" % [text.length(), text.hash()]


# ---------------------------------------------------------------- 查询 / 覆盖


func patch_path() -> String:
	return _path


func is_empty() -> bool:
	return _blocks.is_empty()


func has_block(id: String) -> bool:
	return _blocks.has(id)


func block_ids() -> Array[String]:
	var out: Array[String] = []
	for id_variant in _blocks:
		out.append(String(id_variant))
	out.sort()
	return out


func block_count() -> int:
	return _blocks.size()


## 这一段的覆盖版本（没有覆盖返回空数组）
func lines_of(id: String) -> Array:
	if not _blocks.has(id):
		return []
	return (_blocks[id]["lines"] as Array).duplicate(true)


## 编辑时的原文快照（没有覆盖返回空数组）
func base_of(id: String) -> Array:
	if not _blocks.has(id):
		return []
	return (_blocks[id]["base"] as Array).duplicate(true)


## 写入覆盖。[param base] 是**当前原文**，存下来供"上游已变"检测。
func set_block(id: String, lines: Array, base: Array = []) -> void:
	_blocks[id] = {"lines": _clean_lines(lines), "base": _clean_lines(base)}


func revert_block(id: String) -> void:
	_blocks.erase(id)


func revert_all() -> void:
	_blocks.clear()


## 运行时替换：没覆盖就返回原文（**深拷贝**，见 `apply()` 的说明）
func patched(id: String, lines: Array) -> Array:
	if not _blocks.has(id):
		return lines
	return (_blocks[id]["lines"] as Array).duplicate(true)


## 上游台词改过了没有（存下来的 `base` 与当前原文不一致 = 你的覆盖可能过时）
## [param current_raw] 由调用方从数据源现取（补丁层不认识业务数据）。
func drifted(id: String, current_raw: Array) -> bool:
	if not _blocks.has(id):
		return false
	var base: Array = _blocks[id]["base"]
	if base.is_empty() and current_raw.is_empty():
		return false
	return _signature(base) != _signature(current_raw)


## 覆盖版里比原文少了哪些剧情开关（少了就可能把剧情卡住）
##
## 只比对 `flag` 字段：这是"台词行同时承担剧情推进"的唯一写法（见 `DialogueBox`）。
func missing_flags(id: String, current_raw: Array) -> Array[String]:
	var out: Array[String] = []
	if not _blocks.has(id):
		return out
	var mine: Array = _blocks[id]["lines"]
	var raw_flags := _flags_in(current_raw)
	var my_flags := _flags_in(mine)
	for flag in raw_flags:
		if not my_flags.has(flag):
			out.append(flag)
	return out


func stats_line() -> String:
	return "覆盖 %d 段台词" % _blocks.size()


# ---------------------------------------------------------------- 内部


static func _flags_in(lines: Array) -> Array[String]:
	var out: Array[String] = []
	for line_variant in lines:
		if not (line_variant is Dictionary):
			continue
		var line: Dictionary = line_variant
		var flag := String(line.get("flag", ""))
		if flag != "" and not out.has(flag):
			out.append(flag)
		# 选项分支里也可以写开关
		for choice_variant in (line.get("choices", []) as Array):
			if choice_variant is Dictionary:
				var cflag := String((choice_variant as Dictionary).get("flag", ""))
				if cflag != "" and not out.has(cflag):
					out.append(cflag)
	return out


## 只看"人看得见的那部分"的指纹：说话人 / 正文 / 情绪。
## 不把 `flag`、`voice` 之类算进去 —— 它们不是文案，改了不该报"上游已变"。
static func _signature(lines: Array) -> String:
	var parts := PackedStringArray()
	for line_variant in lines:
		if not (line_variant is Dictionary):
			parts.append("?")
			continue
		var line: Dictionary = line_variant
		parts.append("%s|%s|%s" % [
			String(line.get("speaker", "")),
			String(line.get("text", "")),
			String(line.get("emotion", "")),
		])
	return "\n".join(parts)


## 台词行必须是"能被 JSON 存下来"的纯数据。
## ⚠️ 万一有人往行里塞了 Texture2D（`portrait` 支持直接给资源），
##    `JSON.stringify` 会写出垃圾甚至报错 —— 这里统一把非基础类型转成字符串兜住。
func _clean_lines(lines: Array) -> Array:
	var out: Array = []
	for line_variant in lines:
		if line_variant is Dictionary:
			out.append(_clean_value(line_variant))
		elif line_variant is String:
			# 允许写裸字符串？不允许 —— 对话框只认字典，写进去等于坏数据
			push_warning("DialoguePatch: 台词行必须是字典，已丢弃一个字符串条目")
	return out


func _clean_value(value: Variant) -> Variant:
	if value == null or value is String or value is int or value is float or value is bool:
		return value
	if value is Array:
		var arr: Array = []
		for v in (value as Array):
			arr.append(_clean_value(v))
		return arr
	if value is Dictionary:
		var dict := {}
		for k in (value as Dictionary):
			dict[String(k)] = _clean_value((value as Dictionary)[k])
		return dict
	return str(value)
