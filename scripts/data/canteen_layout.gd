extends RefCounted
## 食堂布局的**覆盖层**（开发工具写、游戏读）—— 与 `data/layout_patch.json` 并列。
##
## 为什么单独一个文件、而不是塞进 `layout_patch.json`：
##   那个补丁是按**校园分区**（life / teaching / sports）分组的，键是 `CampusLayout` 生成的
##   部件 id（`life|green_line:2|tree@40,15` 这种）。食堂是**室内场景**，它的部件
##   （家具 / 座位）是 `CanteenData` 建出来的、用的是逻辑格坐标 —— 两套身份体系硬塞进
##   一个文件只会让两边都变脆。所以这里只放食堂自己的东西，结构简单到一眼能看懂。
##
## ⚠️ 这个文件**由 `tools/layout_editor.tscn` 覆盖**（Ctrl+S 时重写）。
##    它是**数据**，不是代码逻辑 —— 想手改也可以，但改完请开一次编辑器或跑一次游戏确认。
##
## 结构（家具 + 人物 + **编辑器新增的件**）：
##   {
##     "fixtures": { "counter#1_2": {"tile": [x, y]} },   # 键 = 种类 + 原始逻辑格
##     "people":   { "person#0":   {"tile": [x, y]} },    # 键 = 人物下标
##     "props":    { "new0": {"kind": "table", "tile": [x, y], "person": false} }
##   }
##
## 键里带**原始坐标/下标**：`fixtures()` / `people()` 是按数据顺序生成的，
## 万一以后调整了数据表顺序，带原始坐标的键仍然指得准那一件
## （不带的键会指错件 —— 那种错还不报错）。
## ⚠️ 人物只有下标可用（三个同学是同一张图的三张变体），所以
##    **`people()` 的顺序就是他们的身份**：只允许往后追加，不许插队。
##
## ⚠️ **`props` 与 `fixtures`/`people` 是并行的两条支线**（2026-09-20 加）：
##    前两条改的是"**数据表规定的**那些件"（位置/删掉），
##    `props` 装的是"**编辑器额外加上去的**件"（`CanteenData.extra_props()` 读它）。
##    分开的理由：两边的键**不能共用**（数据表件的键是 `counter#1_2`，
##    新增件的键是 `new3`），共用会让"新增的柜台"和"原来的柜台"互相覆盖。
##
## ⚠️ 座位那条支线已删（用户 2026-09-20 要求去掉食堂的"坐下"交互）。

const PATH := "res://data/canteen_layout.json"


## 读出覆盖数据（文件不存在/坏了都返回空结构 —— 让游戏照常跑）
static func load_overrides() -> Dictionary:
	var empty := {"fixtures": {}, "people": {}, "props": {}}
	if not FileAccess.file_exists(PATH):
		return empty
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return empty
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("食堂布局覆盖文件不是字典，已忽略：%s" % PATH)
		return empty
	var d := parsed as Dictionary
	# ⚠️ 只取这三个键：老版本写进去的 `seats` 会被**忽略**（不再有座位这回事），
	#    下一次在编辑器里 Ctrl+S 就会把它从文件里清掉。
	return {
		"fixtures": d.get("fixtures", {}) if d.get("fixtures", {}) is Dictionary else {},
		"people": d.get("people", {}) if d.get("people", {}) is Dictionary else {},
		"props": d.get("props", {}) if d.get("props", {}) is Dictionary else {},
	}


## 写回覆盖数据（编辑器用）。返回空串 = 成功，否则是错误说明。
static func save_overrides(overrides: Dictionary) -> String:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return "打不开 %s（err=%d）" % [PATH, FileAccess.get_open_error()]
	f.store_string(JSON.stringify(overrides, "  "))
	f.close()
	return ""


## `[x, y]` → `Vector2i`（拿不到就返回 [param fallback]）
static func to_tile(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and (value as Array).size() >= 2:
		var a := value as Array
		return Vector2i(int(a[0]), int(a[1]))
	return fallback


static func to_array(tile: Vector2i) -> Array:
	return [tile.x, tile.y]
