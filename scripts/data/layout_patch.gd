class_name LayoutPatch
extends RefCounted
## 校园布局的**覆盖层**（增 / 删 / 移），数据落在 `res://data/layout_patch.json`。
##
## ------------------------------------------------------------------ 为什么要这一层
##
## 校园里所有建筑、绿化、街具的坐标都是 `CampusData` 里的**算法生成的**（沿路等距、网格撒点）。
## 那些算法适合"铺一张大图"，不适合"把食堂往东挪两格"这种手调 —— 改一个数字就牵动一整排。
## 所以加一层补丁：**生成照旧、结果可覆盖**，于是可以有一个可视化编辑器直接拖。
##
##     CampusData 生成 → (按 id) 删除 → (按 id) 移位 → (按表) 新增 → 交给 campus.gd 摆
##
## ------------------------------------------------------------------ id 契约（关键）
##
## id 由 `CampusLayout` 在**生成顺序**上算出来，形如：
##
##     life|building:canteen                建筑（用它自己的 id）
##     life|green_spot:1|tree_autumn@28,3    定点绿化（序号 = 在数据表里的下标）
##     life|green_line:1004|bush_pink@6,2    沿路绿化（序号 = 组号*1000 + 组内第几件）
##     life|green_scatter:12|bush_pink@15,3  撒点绿化
##     life|prop_line:0|lamp@7,12            沿路街具
##     life|prop_spot:2|bench@20,19          定点街具（序号 = 在数据表里的下标）
##     life|added:3|bush_pink@30,17          补丁新增件（序号 = 在 added 表里的第几条）
##
## 序号与落地格都写进 id：序号管"是哪一件"，`@x,y` 管"当年在哪"。
## 所以读 id 就能一眼看出补丁指的是不是你要的那一件。
##
## 为了防"上游算法改了、补丁还按老位置生效"这种**静默错位**，每条 deleted / moved
## 都带一个 `orig`（当年记下的坐标）。对不上就计数并打印警告，不硬套。
##
## ------------------------------------------------------------------ 字段
##
##   deleted  [ {id, orig?, note?} ]            按 id 删掉那一件
##   moved    [ {id, to:[x,y], orig?, note?} ]  把那一件的**落点格**改到 to（尺寸与占地自动重算）
##   added    [ {kind, at:[x,y], src?, decal?, note?} ]
##                 kind = 绿化/街具大类（见 CampusData.GREEN_KINDS / PROP_KINDS）
##                 at   = 落点逻辑格（与数据表里的 tile 同义）
##                 src  = 生成来源，仅作备注（"editor" / "manual"）
##                 decal= true 时不给碰撞体（纯装饰，可以走过去）

const DEFAULT_PATH := "res://data/layout_patch.json"

## 版本号：格式改了要 +1，并在 `load_from()` 里拒绝不认识的版本
const VERSION := 1

var version: int = VERSION
var note: String = ""
## zone_id -> { deleted: Array, moved: Array, added: Array }
var zones: Dictionary = {}
## 统计：生效 / 跳过（给自检与编辑器看）
var stats: Dictionary = {
	"deleted": 0, "moved": 0, "added": 0,
	"missing": 0,   # 补丁点名了一件**不存在**的东西（多半是上游算法改了）
	"stale": 0,     # orig 与当前实际坐标对不上
	"blocked": 0,   # added 落在被占用 / 越界的格子上，没摆
}


## 读一份补丁。文件不存在、解析失败、版本不认识 → 返回**空补丁**（游戏照常跑）。
static func load_from(path: String = DEFAULT_PATH) -> LayoutPatch:
	var patch := LayoutPatch.new()
	if path == "" or not FileAccess.file_exists(path):
		return patch
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("LayoutPatch: 打不开 %s（错误码 %d），按空补丁继续" % [path, FileAccess.get_open_error()])
		return patch
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("LayoutPatch: %s 不是合法 JSON，按空补丁继续" % path)
		return patch
	var dict := parsed as Dictionary
	var v := int(dict.get("version", 0))
	if v > VERSION:
		push_error("LayoutPatch: 补丁版本 %d 比代码认识的 %d 新，按空补丁继续（先升级代码）" % [v, VERSION])
		return patch
	patch.version = v if v > 0 else VERSION
	patch.note = String(dict.get("note", ""))
	var zones_variant: Variant = dict.get("zones", {})
	if zones_variant is Dictionary:
		for zone_id: Variant in (zones_variant as Dictionary):
			var entry: Variant = (zones_variant as Dictionary)[zone_id]
			if not (entry is Dictionary):
				continue
			var e := entry as Dictionary
			patch.zones[String(zone_id)] = {
				"note": String(e.get("note", "")),
				"deleted": unpack_entries(e.get("deleted", [])),
				"moved": unpack_entries(e.get("moved", [])),
				"added": unpack_entries(e.get("added", [])),
			}
	return patch


## 把 JSON 读回来的条目**还原成 Vector2i**（`orig` / `to` / `at`）。
##
## ⚠️ 为什么必须显式转换（踩过，现象很隐蔽）：
##    Godot 4 的 `JSON.stringify()` 遇到 Vector2i **不写 {"x":..,"y":..}，而是写成字符串 "(25, 20)"**。
##    于是解析回来是 String，坐标静默变成 (0,0) —— 表现是"补丁里明明有这一条，
##    却报'要移位的 id 不存在'、新增件全落在 (0,0)"，而且**没有任何报错**。
##    所以：写盘时统一打包成 `[x, y]`，读盘时统一在这里还原。
static func unpack_entries(entries_variant: Variant) -> Array:
	var out: Array = []
	if not (entries_variant is Array):
		return out
	for item_variant: Variant in (entries_variant as Array):
		if not (item_variant is Dictionary):
			continue
		var item := (item_variant as Dictionary).duplicate()
		for key in ["orig", "to", "at"]:
			if item.has(key):
				item[key] = to_vec2i(item[key])
		out.append(item)
	return out


## 从一段 JSON 文本还原补丁（编辑器撤销栈用：撤销 = 把上一步的快照读回来）
static func from_json(text: String) -> LayoutPatch:
	var patch := LayoutPatch.new()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("LayoutPatch: from_json 收到非法 JSON，返回空补丁")
		return patch
	var dict := parsed as Dictionary
	patch.version = int(dict.get("version", VERSION))
	patch.note = String(dict.get("note", ""))
	var zones_variant: Variant = dict.get("zones", {})
	if zones_variant is Dictionary:
		for zone_id: Variant in (zones_variant as Dictionary):
			var entry: Variant = (zones_variant as Dictionary)[zone_id]
			if not (entry is Dictionary):
				continue
			var e := entry as Dictionary
			patch.zones[String(zone_id)] = {
				"note": String(e.get("note", "")),
				"deleted": unpack_entries(e.get("deleted", [])),
				"moved": unpack_entries(e.get("moved", [])),
				"added": unpack_entries(e.get("added", [])),
			}
	return patch


## 空补丁（= 完全不覆盖）。`is_empty()` 为 true 时调用方可以整段跳过。
static func empty() -> LayoutPatch:
	return LayoutPatch.new()


func is_empty() -> bool:
	for zone_id: Variant in zones:
		var e: Dictionary = zones[zone_id]
		if not (e.get("deleted", []) as Array).is_empty() \
				or not (e.get("moved", []) as Array).is_empty() \
				or not (e.get("added", []) as Array).is_empty():
			return false
	return true


## 某区的三个条目表（永远返回可写的副本结构，绝不返回 null）
func zone_entries(zone_id: String) -> Dictionary:
	if not zones.has(zone_id):
		zones[zone_id] = {"note": "", "deleted": [], "moved": [], "added": []}
	return zones[zone_id]


## 该区有没有实质内容（编辑器用来判断"这个区调过没有"）
func zone_is_empty(zone_id: String) -> bool:
	var e := zone_entries(zone_id)
	return (e["deleted"] as Array).is_empty() and (e["moved"] as Array).is_empty() \
			and (e["added"] as Array).is_empty()


# ------------------------------------------------------------------ 写盘（编辑器用）


## 序列化成 JSON 文本（缩进 2 格）。
## ⚠️ 坐标在这里被打包成 `[x, y]` —— 不能让 Godot 自己去序列化 Vector2i（见 `unpack_entries()`）。
func to_json() -> String:
	var out := {
		"version": VERSION,
		"note": "布局补丁（由 tools/layout_editor.tscn 生成，也可手写）。"
				+ "这是**覆盖层**，不改任何生成算法：默认生成的清单 → 先按 id 删除、"
				+ "再按 id 移位、最后按表新增。本文件为空时游戏表现与没有它时完全一致。"
				+ "坐标一律是【逻辑格】数组 [x, y]（32px/格）。",
		"zones": {},
	}
	var zones_out: Dictionary = out["zones"]
	var zone_ids: Array = zones.keys()
	zone_ids.sort()
	for zone_id: Variant in zone_ids:
		var e: Dictionary = zones[zone_id]
		zones_out[String(zone_id)] = {
			"note": String(e.get("note", "")),
			"deleted": _clean_entries(e.get("deleted", [])),
			"moved": _clean_entries(e.get("moved", [])),
			"added": _clean_entries(e.get("added", [])),
		}
	return JSON.stringify(out, "  ") + "\n"


## 去掉多余键（只留契约里那几项），顺序也固定，让 git diff 干净；坐标同时打包成 [x, y]
static func _clean_entries(entries_variant: Variant) -> Array:
	var out: Array = []
	if not (entries_variant is Array):
		return out
	for item_variant: Variant in (entries_variant as Array):
		if not (item_variant is Dictionary):
			continue
		var item := item_variant as Dictionary
		var clean: Dictionary = {}
		for key in ["id", "orig", "to", "kind", "at", "src", "decal", "note"]:
			if not item.has(key):
				continue
			var value: Variant = item[key]
			if value is Vector2i:
				var v := value as Vector2i
				clean[key] = [v.x, v.y]
			elif value is Vector2:
				var vf := value as Vector2
				clean[key] = [int(roundf(vf.x)), int(roundf(vf.y))]
			else:
				clean[key] = value
		out.append(clean)
	return out


## 写回磁盘。返回空串 = 成功，否则是错误说明。
func save_to(path: String = DEFAULT_PATH) -> String:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return "建目录失败 %s（%d）" % [dir, err]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "写不开 %s（错误码 %d）" % [path, FileAccess.get_open_error()]
	f.store_string(to_json())
	f.close()
	return ""


# ------------------------------------------------------------------ 增删改（编辑器用）


func delete_item(zone_id: String, id: String, orig: Vector2i, note: String = "") -> void:
	var e := zone_entries(zone_id)
	# 已经删过就不重复记（编辑器反复右键不该堆一堆重复条目）
	for item_variant: Variant in (e["deleted"] as Array):
		if String((item_variant as Dictionary).get("id", "")) == id:
			return
	# 如果它原本是被 moved 移走的：删掉 moved、留下 deleted（净效果 = 回到生成位置后消失）
	_remove_moved(zone_id, id)
	(e["deleted"] as Array).append({"id": id, "orig": orig, "note": note})


func move_item(zone_id: String, id: String, to: Vector2i, orig: Vector2i, note: String = "") -> void:
	var e := zone_entries(zone_id)
	for item_variant: Variant in (e["moved"] as Array):
		var item := item_variant as Dictionary
		if String(item.get("id", "")) == id:
			item["to"] = to
			if note != "":
				item["note"] = note
			return
	(e["moved"] as Array).append({"id": id, "to": to, "orig": orig, "note": note})


func add_item(zone_id: String, kind: String, at: Vector2i, src: String = "editor",
		decal: bool = false, note: String = "") -> void:
	var e := zone_entries(zone_id)
	(e["added"] as Array).append({
		"kind": kind, "at": at, "src": src, "decal": decal, "note": note,
	})


## 撤掉某件东西在补丁里的全部痕迹（编辑器"还原成生成位置"）
func revert_item(zone_id: String, id: String) -> void:
	var e := zone_entries(zone_id)
	_remove_moved(zone_id, id)
	var kept: Array = []
	for item_variant: Variant in (e["deleted"] as Array):
		if String((item_variant as Dictionary).get("id", "")) != id:
			kept.append(item_variant)
	e["deleted"] = kept


func _remove_moved(zone_id: String, id: String) -> void:
	var e := zone_entries(zone_id)
	var kept: Array = []
	for item_variant: Variant in (e["moved"] as Array):
		if String((item_variant as Dictionary).get("id", "")) != id:
			kept.append(item_variant)
	e["moved"] = kept


## 某个 zone 的 added 里，落在 [param at] 的那条（编辑器删"新增件"时用）
func find_added_at(zone_id: String, at: Vector2i) -> int:
	var e := zone_entries(zone_id)
	var added: Array = e["added"]
	for i in added.size():
		if to_vec2i((added[i] as Dictionary).get("at", null)) == at:
			return i
	return -1


func remove_added_at(zone_id: String, at: Vector2i) -> bool:
	var idx := find_added_at(zone_id, at)
	if idx < 0:
		return false
	(zone_entries(zone_id)["added"] as Array).remove_at(idx)
	return true


# ------------------------------------------------------------------ 应用（CampusLayout 调用）


## 按 id 删除。返回删掉的 id 集合（后续 moved 要靠它判断"这件已经没了"）。
##
## ⚠️ 三组（建筑/绿化/街具）的 id 长着不同的前缀（`life|building:` / `life|green_*:`
##    / `life|prop_*:`），所以这里按前缀把条目**分桶**，各自只对属于自己的那一组生效。
##    不分桶就会"每条删除都在三组里各找一遍" → 一条点不中的 id 被报三次 missing（踩过）。
## [param bucket] 这一组认哪些来源（见 `LayoutPatch.SRC_*`）。
func apply_deleted(zone_id: String, items: Array, id_of: Callable, bucket: Array) -> Dictionary:
	var e := zone_entries(zone_id)
	var deleted: Array = e["deleted"]
	if deleted.is_empty():
		return {}
	var by_id: Dictionary = {}
	for item_variant: Variant in items:
		by_id[id_of.call(item_variant)] = item_variant
	var gone: Dictionary = {}
	for entry_variant: Variant in deleted:
		var entry := entry_variant as Dictionary
		var id := String(entry.get("id", ""))
		if id == "" or not bucket.has(_src_kind_of(id)):
			continue
		if not by_id.has(id):
			# 补丁点名了一件不存在的东西：上游算法变了。点名但不报错（否则一改间距就满地红字）
			stats["missing"] = int(stats["missing"]) + 1
			push_warning("LayoutPatch[%s]: 要删的 id 不存在 → %s" % [zone_id, id])
			continue
		_check_orig(zone_id, entry, by_id[id])
		gone[id] = true
		stats["deleted"] = int(stats["deleted"]) + 1
	if gone.is_empty():
		return gone
	var kept: Array = []
	for item_variant: Variant in items:
		if not gone.has(id_of.call(item_variant)):
			kept.append(item_variant)
	items.clear()
	items.append_array(kept)
	return gone


## 按 id 移位。把清单里那一件的 `_base_tile` 换成 to，`cells` 由调用方在
## `_configure()` 里重算 —— 这里只动数据，不碰节点。
## [param skip] 是 apply_deleted 返回的"已删掉"集合：删了又移的条目直接忽略。
## [param bucket] 同 `apply_deleted()`：这组认哪些来源。
func apply_moved(zone_id: String, items: Array, id_of: Callable, skip: Dictionary,
		bucket: Array) -> void:
	var e := zone_entries(zone_id)
	var moved: Array = e["moved"]
	if moved.is_empty():
		return
	for entry_variant: Variant in moved:
		var entry := entry_variant as Dictionary
		var id := String(entry.get("id", ""))
		if id == "" or skip.has(id) or not bucket.has(_src_kind_of(id)):
			continue
		var target: Variant = null
		for item_variant: Variant in items:
			if String(id_of.call(item_variant)) == id:
				target = item_variant
				break
		if target == null:
			stats["missing"] = int(stats["missing"]) + 1
			push_warning("LayoutPatch[%s]: 要移位的 id 不存在 → %s" % [zone_id, id])
			continue
		var item := target as Dictionary
		_check_orig(zone_id, entry, item)
		var to := to_vec2i(entry.get("to", null))
		item["_base_tile"] = to
		item["_patched"] = "moved"
		stats["moved"] = int(stats["moved"]) + 1


## 从 id 里取出"来源"那一段（`life|prop_spot:3|bench@20,19` → `prop_spot`）。
## 认不出来返回空串 —— 那种条目只会被当成"点不中"。
static func _src_kind_of(id: String) -> String:
	var bar := id.find("|")
	if bar < 0:
		return ""
	var rest := id.substr(bar + 1)
	var colon := rest.find(":")
	return rest.substr(0, colon) if colon > 0 else rest


## 补丁里记的 orig 与当前实际落点对不上 → 记 stale 并警告（不阻断，继续按 to 生效）。
func _check_orig(zone_id: String, entry: Dictionary, item: Dictionary) -> void:
	if not entry.has("orig"):
		return
	var orig := to_vec2i(entry.get("orig", null))
	var actual := to_vec2i(item.get("_base_tile", null))
	if orig != actual:
		stats["stale"] = int(stats["stale"]) + 1
		push_warning("LayoutPatch[%s]: %s 的 orig=%s 与实际 %s 不符（上游布局变过了），仍按补丁生效"
				% [zone_id, String(entry.get("id", "?")), str(orig), str(actual)])


## JSON 里 [x, y] / {"x":..,"y":..} / Vector2i / Godot 写出的 "(x, y)" 字符串都认。
## ⚠️ 是**公开**静态函数：`CampusLayout` 解析补丁时用同一套口径。
static func to_vec2i(variant: Variant) -> Vector2i:
	if variant == null:
		return Vector2i.ZERO
	if variant is Vector2i:
		return variant
	if variant is Vector2:
		return Vector2i((variant as Vector2).round())
	if variant is Array:
		var arr := variant as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
		return Vector2i.ZERO
	if variant is Dictionary:
		var d := variant as Dictionary
		if d.has("x") and d.has("y"):
			return Vector2i(int(d["x"]), int(d["y"]))
		return Vector2i.ZERO
	if variant is String:
		# 兜底：Godot 的 JSON.stringify() 会把 Vector2i 写成 "(25, 20)" 这种字符串
		var text := (variant as String).strip_edges().trim_prefix("(").trim_suffix(")")
		var parts := text.split(",")
		if parts.size() >= 2:
			return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	return Vector2i.ZERO


## 统计行（自检里打印，看"补丁到底生效了几条"）
func stats_line() -> String:
	return "删除=%d 移位=%d 新增=%d（未找到=%d 位置漂移=%d 放下被挡=%d）" % [
		int(stats["deleted"]), int(stats["moved"]), int(stats["added"]),
		int(stats["missing"]), int(stats["stale"]), int(stats["blocked"]),
	]
