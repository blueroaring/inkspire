class_name CampusLayout
extends RefCounted
## 校园布局的**统一清单**：把 `CampusData` 的生成过程按原顺序跑一遍，给每一件产出打上稳定 id，
## 再套一层 `LayoutPatch`，最后交回给 `campus.gd` 去摆。
##
## ------------------------------------------------------------------ 它解决什么
##
## 「手动拖部件」卡在一个前提上：**得先有"这一件"这个概念**。
## 而校园里的东西全是算法算出来的（沿路等距、网格撒点、按行扫描），没有清单、也没有 id。
## 所以本文件做三件事：
##
##   ① 按 campus.gd 原来的**组装顺序**复现生成（顺序变了 id 就会变，别乱调）
##   ② 用「来源 + 组号 + 组内序号 + 落地格」拼出稳定 id（见 `_make_id`）
##   ③ 应用补丁：删除 → 移位 → 新增，并在新增时做占用/越界检查
##
## ------------------------------------------------------------------ ⚠️ 与 CampusData 的重复
##
## `_greenery()` / `_street_props()` 是 `CampusData.greenery()` / `CampusData.props()` 的
## **逐行复刻**，唯一区别是顺手记下「这一件是哪一行的第几件」。之所以复刻而不是在
## `CampusData` 里加参数：生成算法是"声明式地图"的地基，值得保持原样不动。
##
## 这份重复由 `tools/check_campus_layout.gd` 做**逐件比对**（无补丁时两边的
## kind / cells / 顺序必须完全一致）—— 改了 `CampusData` 的生成逻辑却忘了同步这里，跑那个脚本就会报。
##
## ------------------------------------------------------------------ ⚠️ 与生成期占用判定的关系
##
## 位移/新增会重算 `cells`（占地），但**不会**回头去改生成时的占用判定：
## "原来那格被谁占着"是生成期的事实，改它等于重跑整套算法。所以拖动之后出现的新重叠
## 由 `overlaps_of()` 报出来（编辑器会标红），而不是偷偷互相顶掉。

## 来源标记（放进 item 的 `_src_kind`，编辑器与自检按它分类）
const SRC_BUILDING := "building"
const SRC_GATE := "gate"
const SRC_NPC := "npc"
const SRC_GREEN_SPOT := "green_spot"
const SRC_GREEN_LINE := "green_line"
const SRC_GREEN_SCATTER := "green_scatter"
const SRC_PROP_LINE := "prop_line"
const SRC_PROP_SPOT := "prop_spot"
const SRC_ADDED := "added"


## 建一份布局。
##
## [param patch] 传 null 时**按文件读**（`res://data/layout_patch.json`）；
## 编辑器可以直接传一个内存里的补丁，做到"边拖边看、按保存才落盘"。
static func build(zone: Dictionary, patch: LayoutPatch = null) -> Dictionary:
	var zone_id := String(zone.get("id", ""))
	var effective := patch
	if effective == null:
		effective = LayoutPatch.load_from()

	var buildings := _buildings(zone, zone_id)
	var gates := _gates(zone, zone_id)
	var npcs := _npcs(zone, zone_id)
	var greens := _greenery(zone, zone_id)
	var props := _street_props(zone, zone_id)

	# ---------------- 补丁：删除 → 移位 ----------------
	# 各组 id 前缀不同，各自独立处理（按前缀分桶，见 apply_deleted 的说明）；
	# `gone` 要合并 —— 删了又移的条目直接忽略。
	var id_of := func(it: Variant) -> String: return String((it as Dictionary).get("_id", ""))
	var gone := {}
	gone.merge(effective.apply_deleted(zone_id, buildings, id_of, [SRC_BUILDING]))
	gone.merge(effective.apply_deleted(zone_id, gates, id_of, [SRC_GATE]))
	gone.merge(effective.apply_deleted(zone_id, npcs, id_of, [SRC_NPC]))
	gone.merge(effective.apply_deleted(zone_id, greens, id_of,
			[SRC_GREEN_SPOT, SRC_GREEN_LINE, SRC_GREEN_SCATTER]))
	gone.merge(effective.apply_deleted(zone_id, props, id_of, [SRC_PROP_SPOT, SRC_PROP_LINE]))

	effective.apply_moved(zone_id, buildings, id_of, gone, [SRC_BUILDING])
	effective.apply_moved(zone_id, gates, id_of, gone, [SRC_GATE])
	effective.apply_moved(zone_id, npcs, id_of, gone, [SRC_NPC])
	effective.apply_moved(zone_id, greens, id_of, gone,
			[SRC_GREEN_SPOT, SRC_GREEN_LINE, SRC_GREEN_SCATTER])
	effective.apply_moved(zone_id, props, id_of, gone, [SRC_PROP_SPOT, SRC_PROP_LINE])

	# 移位之后必须**重算占地**：`to` 说的是"落地那一格"，cells 是它的函数
	# （与 `CampusData.prop_footprint_cells` / `green_footprint_cells` 是同一套映射）。
	for item_variant: Variant in buildings:
		_recompute_building_cells(item_variant as Dictionary)
	for item_variant: Variant in gates:
		_recompute_building_cells(item_variant as Dictionary)
	for item_variant: Variant in npcs:
		_recompute_npc_cells(item_variant as Dictionary)
	for item_variant: Variant in greens:
		_recompute_green_cells(item_variant as Dictionary)
	for item_variant: Variant in props:
		_recompute_prop_cells(item_variant as Dictionary)

	# ---------------- 补丁：新增 ----------------
	var occupied := occupancy_of(buildings, greens, props)
	# ⚠️ 路网/墙/广场那些"禁放格"是在生成期算的（`CampusData.blocked_cells()`），
	#    它只知道建筑**原来**在哪。所以这里把**移动/删掉之后**的建筑占地重新补进去：
	#    否则把教学楼拖走会在原地留下一片**看不见的空气墙**（玩家撞不到楼、却撞得到空气）。
	var blocked := blocked_cells_with(buildings, occupied)
	var additions := _added_items(zone_id, effective, occupied, blocked)

	var all: Array = []
	all.append_array(buildings)
	all.append_array(gates)
	all.append_array(npcs)
	all.append_array(greens)
	all.append_array(props)
	all.append_array(additions)

	return {
		"zone_id": zone_id,
		"buildings": buildings,
		"gates": gates,
		"npcs": npcs,
		"greenery": greens,
		"props": props,
		"added": additions,
		"all": all,
		"patch": effective,
		"stats": effective.stats,
	}


# ------------------------------------------------------------------ 生成（CampusData 的逐行复刻）


static func _buildings(zone: Dictionary, zone_id: String) -> Array:
	var out: Array = []
	for b_variant: Variant in zone.get("buildings", []):
		var b: Dictionary = b_variant
		var item := {
			"kind": "building",
			"whole_sprite": true,
			"texture_path": String(b.get("texture", "")),
			# 建筑是整块碰撞（见 campus.gd::_build_building）
			"collision": Rect2(0.0, 0.0, 1.0, 1.0),
			"_base_tile": b["tile_pos"] as Vector2i,
			"_size_tiles": b["size_tiles"] as Vector2i,
			"_src_kind": SRC_BUILDING,
			"_src_label": String(b.get("label", "")),
			"_building_label": String(b.get("label", "")),
			"_building_id": String(b.get("id", "")),
		}
		item["_id"] = "%s|building:%s" % [zone_id, String(b.get("id", "?"))]
		_recompute_building_cells(item)
		out.append(item)
	return out


## 校门也是"一件东西"（能拖能删能改），所以同样进清单。
## 校门的美术是整件精灵 + 整块占地挡人；没有美术时 `campus.gd::_build_gate()` 会退回砖结构。
static func _gates(zone: Dictionary, zone_id: String) -> Array:
	var out: Array = []
	var gates: Array = zone.get("gates", [])
	for i in gates.size():
		var g: Dictionary = gates[i]
		var tile: Vector2i = g["tile"]
		var size: Vector2i = g["size"]
		var item := {
			"kind": "gate",
			"whole_sprite": true,
			"texture_path": String(g.get("texture", "")),
			# 校门是边界：整块占地挡人
			"collision": Rect2(0.0, 0.0, 1.0, 1.0),
			"_base_tile": tile,
			"_size_tiles": size,
			"_src_kind": SRC_GATE,
			"_src_label": String(g.get("label", "")),
			"_gate_label": String(g.get("label", "")),
			"_gate_lines": g.get("lines", []),
			# "某个开关成立后整体换一段"（08：看校门（南）那几句在她入队后改写）
			"_gate_rewrite_after": String(g.get("rewrite_after", "")),
			"_gate_lines_after": g.get("lines_after", []),
			"_gate_morning_lines": g.get("morning_lines", []),
			"_id": "%s|gate:%d|%s@%d,%d" % [zone_id, i, String(g.get("label", "gate")), tile.x, tile.y],
		}
		_recompute_building_cells(item)
		out.append(item)
	return out


## NPC 也进清单（2026-09-19 用户要求"可视化加入对 npc 的移动功能"）。
##
## NPC 不是"摆在图块上的东西"：它的位置就是 `tile` 换算出来的像素点（`Grid.tile_to_px`），
## 而且它自带的交谈区是**挂在 NPC 节点下的子 Area2D**（见 campus.gd::_build_npcs），
## 所以这里只需要给出"落点格 + 一个能点中的框"：
##   · `_base_tile` = NPC 站的那一格（拖动改的就是它）
##   · `cells`      = 以落点格为中心的一个逻辑格方框（编辑器命中测试与预览都用它）
##   · `_size_tiles`= (1,1)，所以拖动时不会像建筑那样算占地
## 交互区与名字/台词原样带着走，拖完仍然是同一个 NPC（id 不变，只有位置变）。
static func _npcs(zone: Dictionary, zone_id: String) -> Array:
	var out: Array = []
	var npcs: Array = zone.get("npcs", [])
	for i in npcs.size():
		var n: Dictionary = npcs[i]
		var tile: Vector2i = n["tile"]
		var item := {
			"kind": "npc",
			"whole_sprite": false,
			# NPC 的碰撞在它自己的场景里（CharacterBody2D），布局层不额外加碰撞
			"_base_tile": tile,
			"_size_tiles": Vector2i.ONE,
			"cells": Rect2i(tile * Grid.CELLS_PER_TILE,
					Vector2i(Grid.CELLS_PER_TILE, Grid.CELLS_PER_TILE)),
			"_src_kind": SRC_NPC,
			"_src_label": String(n.get("name", "")),
			"_npc_id": String(n.get("id", "")),
			"_npc_name": String(n.get("name", "")),
			"_npc_face": n.get("face", Vector2i(0, 1)),
			"_npc_lines": n.get("lines", []),
			"_npc_prompt": String(n.get("prompt", "")),
			"_npc_model_path": String(n.get("model_path", "")),
			# 夜间只保留门卫、夜跑同学和超市促销阿姨；其它 NPC 不生成。
			"_npc_night_visible": bool(n.get("night_visible", false)),
			"_npc_night_name": String(n.get("night_name", "")),
			"_npc_night_lines": n.get("night_lines", []),
			"_npc_morning_visible": bool(n.get("morning_visible", true)),
			"_npc_morning_lines": n.get("morning_lines", []),
			# 脚本行为（可选，见 `CampusData._npc()` 的说明）：多阶段对话 / 说完就走 / 门槛开关。
			# ⚠️ 这三个键要**原样带过来**：本清单是场景脚本唯一的数据源，
			#    漏一个的表现是"数据里写了、游戏里没反应"（而且不报错）。
			"_npc_talk_order": n.get("talk_order", []),
			"_npc_require_flag": String(n.get("require_flag", "")),
			# "某个开关成立后整体换台词"（08 标"（全部修改）"的那几位）
			"_npc_rewrite_after": String(n.get("rewrite_after", "")),
			"_npc_lines_after": n.get("lines_after", []),
			# 换了之后名字也换（同宿舍楼的同学：白天是"同层的同学"）
			"_npc_name_after": String(n.get("name_after", "")),
			"_npc_vanish_after": String(n.get("vanish_after", "")),
			"_npc_vanish_also_after": n.get("vanish_also_after", []),
			"_npc_vanish_line": n.get("vanish_line", []),
			"_id": "%s|npc:%d|%s@%d,%d" % [zone_id, i, String(n.get("id", "npc")), tile.x, tile.y],
		}
		out.append(item)
	return out


## 逐行复刻 `CampusData.greenery()`：green_lines → green_spots（逐个判空+间距）→ 撒点
static func _greenery(zone: Dictionary, zone_id: String) -> Array:
	var out: Array = []
	var blocked := CampusData.blocked_cells(zone)
	var lines: Array = zone.get("green_lines", [])

	for line_index in lines.size():
		var line: Dictionary = lines[line_index]
		var before := out.size()
		_emit_green_line(out, blocked, line)
		for i in range(before, out.size()):
			_tag(out[i] as Dictionary, zone_id, SRC_GREEN_LINE, line_index, i - before)

	# ⚠️ 定点绿化是**逐个累加**判定的（后面的点位要避开前面已摆的），所以只能一个一个来
	var spots: Array = zone.get("green_spots", [])
	for spot_index in spots.size():
		var spot: Dictionary = spots[spot_index]
		var tile: Vector2i = spot["tile"]
		var kind := String(spot["kind"])
		var cells := CampusData.green_footprint_cells(tile, kind)
		if not _free(cells, blocked):
			continue
		if _too_close(out, cells, 1):
			continue
		var item := _green_item(kind, cells)
		_tag(item, zone_id, SRC_GREEN_SPOT, spot_index, 0)
		out.append(item)

	var before_scatter := out.size()
	_fill_green_scatter(out, blocked)
	for i in range(before_scatter, out.size()):
		_tag(out[i] as Dictionary, zone_id, SRC_GREEN_SCATTER, 0, i - before_scatter)
	return out


## 逐行复刻 `CampusData.props()`：prop_lines（只避让底座）→ prop_spots
static func _street_props(zone: Dictionary, zone_id: String) -> Array:
	var occupied: Dictionary = {}
	for item_variant: Variant in CampusData.greenery(zone):
		_mark(occupied, (item_variant as Dictionary)["cells"])
	var out: Array = []
	var blocked := CampusData.blocked_cells_for_props(zone)
	var taken: Dictionary = occupied.duplicate()
	var lines: Array = zone.get("prop_lines", [])

	for line_index in lines.size():
		var line: Dictionary = lines[line_index]
		var kind := String(line.get("kind", "lamp"))
		var def: Dictionary = CampusData.PROP_KINDS.get(kind, {})
		if def.is_empty():
			continue
		var size_tiles: Vector2i = def["tiles"]
		var t := int(line["from"])
		var to := int(line["to"])
		var step: int = maxi(1, int(line["step"]))
		var axis := String(line["axis"])
		var at := int(line["at"])
		var seq := 0
		while t <= to:
			var tile := Vector2i(t, at) if axis == "x" else Vector2i(at, t)
			var cells := CampusData.prop_footprint_cells(tile, size_tiles)
			# ⚠️ 判空只看**底座那一格**，不是整个占地（路灯灯头悬空，按整个占地判空会一根都排不出来）
			var base := Rect2i(tile * Grid.CELLS_PER_TILE,
					Vector2i(Grid.CELLS_PER_TILE, Grid.CELLS_PER_TILE))
			if CampusData.zone_cells().encloses(cells) and _free(base, blocked) \
					and not _overlaps_any(base, taken):
				var item := {
					"kind": kind,
					"cells": cells,
					"texture_path": CampusData.prop_texture(kind),
					# 坐下时换成的图（人 + 椅一体的成品）；没有就是空串 = 不换
					"sit_texture": CampusData.prop_sit_texture(kind),
					"whole_sprite": true,
					"collision": def.get("solid", Rect2(0.3, 0.6, 0.4, 0.35)),
					"street_prop": true,
					"base_tile": tile,
				}
				_tag(item, zone_id, SRC_PROP_LINE, line_index, seq)
				out.append(item)
				seq += 1
				_mark(taken, base)
			t += step

	var spots: Array = zone.get("prop_spots", [])
	for spot_index in spots.size():
		var spot: Dictionary = spots[spot_index]
		var kind := String(spot["kind"])
		var def: Dictionary = CampusData.PROP_KINDS.get(kind, {})
		if def.is_empty():
			continue
		var tile: Vector2i = spot["tile"]
		var size_tiles: Vector2i = def["tiles"]
		var cells := CampusData.prop_footprint_cells(tile, size_tiles)
		var base := Rect2i(tile * Grid.CELLS_PER_TILE,
				Vector2i(Grid.CELLS_PER_TILE, Grid.CELLS_PER_TILE))
		if not CampusData.zone_cells().encloses(cells) or not _free(base, blocked):
			continue
		# 只避让**底座**：灯臂/椅背可以重叠，但两件东西的"落地那一格"不能同格
		if _overlaps_any(base, taken):
			continue
		var item := {
			"kind": kind,
			"cells": cells,
			"texture_path": CampusData.prop_texture(kind),
			# 坐下时换成的图（人 + 椅一体的成品）；没有就是空串 = 不换
			"sit_texture": CampusData.prop_sit_texture(kind),
			"whole_sprite": true,
			"collision": def.get("solid", Rect2(0.3, 0.6, 0.4, 0.35)),
			"street_prop": true,
			"base_tile": tile,
		}
		_tag(item, zone_id, SRC_PROP_SPOT, spot_index, 0)
		out.append(item)
		_mark(taken, cells)
	return out


# ------------------------------------------------------------------ 生成期小工具（CampusData 的逐行复刻）


## ⚠️ 下面这几个函数是 `CampusData` 里同名实现的**逐行复刻**，不是"多此一举"：
##    生成算法（`CampusData.greenery()` / `props()`）用的是模块内私有小工具，
##    而本文件要在"复现生成过程"的同时**记下每一件来自哪一组**（那才是 id 的来源）。
##    复刻而不是去改 `CampusData` 的签名，是为了让"声明式地图"的地基保持原样。
##    ⚠️ 改了 `CampusData` 的排布逻辑，这里必须同步 —— `tools/check_campus_layout.gd`
##    会在无补丁时逐件比对（kind / cells / 顺序），漏同步就会报出来。


## 一条绿化线（`CampusData.emit_green_line()` 的复刻）
static func _emit_green_line(out: Array, blocked: Dictionary, line_variant: Variant) -> void:
	var line: Dictionary = line_variant
	var t := int(line["from"])
	var to := int(line["to"])
	var step: int = maxi(1, int(line["step"]))
	var axis := String(line["axis"])
	var at := int(line["at"])
	var kinds: Array = line.get("kinds", [String(line.get("kind", "bush"))])
	var placed := 0
	while t <= to:
		var tile := Vector2i(t, at) if axis == "x" else Vector2i(at, t)
		var kind := String(kinds[placed % kinds.size()])
		var cells := CampusData.green_footprint_cells(tile, kind)
		if _free(cells, blocked):
			out.append(_green_item(kind, cells))
			placed += 1
		t += step


## 网格撒点（`CampusData.fill_green_scatter()` 的复刻）。
## `SCATTER_STEP` 与落点规则必须和 `CampusData` 一致，否则 id 会整体漂。
static func _fill_green_scatter(out: Array, blocked: Dictionary) -> void:
	var kinds := ["bush_pink", "rock", "bush_blue", "tree_small", "bush_orange", "rock2",
			"bush_plain", "tree_sakura", "bush_plain", "rock3"]
	var idx := 0
	var size := Grid.CAMPUS_SIZE
	for ty in range(3, size.y - 2, CampusData.SCATTER_STEP):
		var odd_row := (ty / CampusData.SCATTER_STEP) % 2 == 1
		for tx in range(3, size.x - 2, CampusData.SCATTER_STEP):
			var tile := Vector2i(tx + (CampusData.SCATTER_STEP / 2 if odd_row else 0), ty)
			if tile.x >= size.x - 2:
				continue
			var kind: String = kinds[idx % kinds.size()]
			var cells := CampusData.green_footprint_cells(tile, kind)
			if not _free(cells, blocked) or _too_close(out, cells, 1):
				# ⚠️ 这里要写 "bush_plain"（`CampusData.fill_green_scatter()` 里的原字符串）：
				#    `GREEN_KINDS` 里并没有这个键，两处都会落到默认值（1 格 + bush_plain.png），
				#    但**记录里的 kind 字符串会不一样**，逐件比对就会红。原样复刻。
				kind = "bush_plain" if kind.begins_with("tree") else kinds[(idx + 4) % kinds.size()]
				cells = CampusData.green_footprint_cells(tile, kind)
				if not _free(cells, blocked) or _too_close(out, cells, 1):
					continue
			out.append(_green_item(kind, cells))
			idx += 1


## 造一件绿化（`CampusData._green_item()` 的复刻）
static func _green_item(kind: String, cells: Rect2i) -> Dictionary:
	var def: Dictionary = CampusData.GREEN_KINDS.get(kind, {})
	return {
		"kind": kind,
		"cells": cells,
		"texture_path": CampusData.green_texture(kind),
		"whole_sprite": true,
		"collision": def.get("solid", Rect2(0.2, 0.4, 0.6, 0.5)),
		"foliage": true,
	}


## 这一块格子空不空（`CampusData._free()` 的复刻）
static func _free(cells: Rect2i, blocked: Dictionary) -> bool:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			if blocked.has(Vector2i(x, y)):
				return false
	return true


## 与已摆的件是否太近（`CampusData._too_close()` 的复刻）：
## 把占地往外扩 gap 格，扩完还相交就算太近。
static func _too_close(items: Array, cells: Rect2i, gap: int) -> bool:
	var probe := Rect2i(cells.position - Vector2i(gap, gap), cells.size + Vector2i(gap * 2, gap * 2))
	for item_variant: Variant in items:
		if probe.intersects((item_variant as Dictionary)["cells"] as Rect2i):
			return true
	return false


## 给一件生成物打 id + 来源标记，并把"落地格"记下来（补丁按它移位）。
##
## ⚠️ id 里同时写「组号 + 组内序号」与「落地格」：
##    序号说明"它是第几个"，`@x,y` 说明"它当年在哪"，两个一起才是**唯一**的
##    （只靠序号会撞：长椅、垃圾桶、自行车都从 0 开始数，于是 10 件街具共用一个 id，
##     补丁点一个动一个 —— 踩过）。
static func _tag(item: Dictionary, zone_id: String, src_kind: String, group: int, seq: int) -> void:
	var tile := _base_tile_of(item, src_kind)
	item["_src_kind"] = src_kind
	item["_src_group"] = group
	item["_src_ref"] = seq
	item["_base_tile"] = tile
	item["_id"] = _make_id(zone_id, src_kind, String(item.get("kind", "")), tile,
			_seq_of(src_kind, group, seq))


## 把「组号 + 组内序号」压成一个序号数字。
## ⚠️ 沿路生成的排布有"第几行 + 行内第几件"两级，定点表只有一级（就是它在数据表里的下标）。
##    两种来源的序号都从这里出，避免"两个调用点各填一半、拼出来的 id 少一段"（踩过：
##    定点件的 id 全变成 `:0`，于是补丁按 id 一条都点不中，还只报"id 不存在"）。
static func _seq_of(src_kind: String, group: int, seq: int) -> int:
	if src_kind == SRC_GREEN_LINE or src_kind == SRC_PROP_LINE:
		return group * 1000 + seq
	return group if seq == 0 else seq


## id 里"落地格"那一段（`@x,y`）。定点表用组内下标、沿路排布用行内下标，
## 所以 kind + 落地格才是唯一的（见 `_tag()` 的说明）。
static func _id_anchor(src_kind: String, tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]


## 生成物的"落地格"反推（补丁与编辑器拖动都靠它，必须是 `*_footprint_cells` 的逆）
static func _base_tile_of(item: Dictionary, src_kind: String) -> Vector2i:
	if src_kind == SRC_PROP_LINE or src_kind == SRC_PROP_SPOT:
		var tile: Vector2i = item.get("base_tile", Vector2i.ZERO)
		return tile if tile != Vector2i.ZERO else _prop_base_from_cells(item["cells"])
	return _green_base_from_cells(item["cells"])


## `prop_footprint_cells` 的逆：x0 = tx*2 - (w/2-1)，y0 = (ty+1)*2 - h
static func _prop_base_from_cells(cells: Rect2i) -> Vector2i:
	var tile_x := int((float(cells.position.x) + float(cells.size.x) * 0.5 - 1.0)
			/ float(Grid.CELLS_PER_TILE))
	var tile_y := int(floor(float(cells.end.y) / float(Grid.CELLS_PER_TILE))) - 1
	return Vector2i(tile_x, tile_y)


## `green_footprint_cells` 的逆：x0 = tx*2 - (n*2/2-1)，y0 = (ty+1)*2 - n*2
static func _green_base_from_cells(cells: Rect2i) -> Vector2i:
	var tile_x := int((float(cells.position.x) + float(cells.size.x) * 0.5 - 1.0)
			/ float(Grid.CELLS_PER_TILE))
	var tile_y := int(floor(float(cells.end.y) / float(Grid.CELLS_PER_TILE))) - 1
	return Vector2i(tile_x, tile_y)


# ------------------------------------------------------------------ 占地重算


static func _recompute_building_cells(item: Dictionary) -> void:
	var tile: Vector2i = item.get("_base_tile", Vector2i.ZERO)
	var size: Vector2i = item.get("_size_tiles", Vector2i.ONE)
	item["tiles"] = Rect2i(tile, size)
	item["cells"] = Rect2i(tile * Grid.CELLS_PER_TILE, size * Grid.CELLS_PER_TILE)


static func _recompute_green_cells(item: Dictionary) -> void:
	if String(item.get("_src_kind", "")) == SRC_ADDED:
		return  # 新增件在 `make_item()` 里已按自己的 kind 算好
	item["cells"] = CampusData.green_footprint_cells(
			item.get("_base_tile", Vector2i.ZERO), String(item.get("kind", "")))


static func _recompute_prop_cells(item: Dictionary) -> void:
	if String(item.get("_src_kind", "")) == SRC_ADDED:
		return
	var tile: Vector2i = item.get("_base_tile", Vector2i.ZERO)
	var def: Dictionary = CampusData.PROP_KINDS.get(String(item.get("kind", "")), {})
	if def.is_empty():
		return
	item["cells"] = CampusData.prop_footprint_cells(tile, def["tiles"])
	item["base_tile"] = tile


## NPC 的"占地"就是它以落点格为中心的一个逻辑格（只用于编辑器命中测试与预览）
static func _recompute_npc_cells(item: Dictionary) -> void:
	var tile: Vector2i = item.get("_base_tile", Vector2i.ZERO)
	item["cells"] = Rect2i(tile * Grid.CELLS_PER_TILE,
			Vector2i(Grid.CELLS_PER_TILE, Grid.CELLS_PER_TILE))


# ------------------------------------------------------------------ 新增


static func _added_items(zone_id: String, patch: LayoutPatch,
		occupied: Dictionary, blocked: Dictionary) -> Array:
	var e := patch.zone_entries(zone_id)
	var added: Array = e["added"]
	var out: Array = []
	var zone_cells := CampusData.zone_cells()
	var index := 0
	for entry_variant: Variant in added:
		var entry := entry_variant as Dictionary
		var kind := String(entry.get("kind", ""))
		var at: Vector2i = LayoutPatch.to_vec2i(entry.get("at", null))
		var decal := bool(entry.get("decal", false))
		index += 1
		var item := make_item(kind, at, decal)
		if item.is_empty():
			push_warning("LayoutPatch[%s]: 新增件的 kind='%s' 不认识（既不在 GREEN_KINDS 也不在 PROP_KINDS）"
					% [zone_id, kind])
			continue
		item["_src_kind"] = SRC_ADDED
		item["_src_group"] = 0
		item["_src_ref"] = index
		item["_base_tile"] = at
		# ⚠️ 把**在 added 表里的下标**单独带给运行时记录（index 是从 1 开始的第几条）：
		#    编辑器要靠它把"这一件"精确对回补丁里的条目。光靠 `_id` 里的 `@x,y` 是不行的 ——
		#    `_base_tile` 一旦被 moved 改过，id 里的锚点与 added 表里的 `at` 就对不上了，
		#    于是编辑器按 `at` 找不到那一条，只能**再追加**一条新的 moved（重复条目 + 拖了不动，静默）。
		item["_added_index"] = index - 1
		item["_id"] = _make_id(zone_id, SRC_ADDED, kind, at, index)
		var cells: Rect2i = item["cells"]
		# 越界 / 压在道路墙建筑上 / 压在其他部件上 → 不摆（编辑器里这一条会标红）
		var hit := not zone_cells.encloses(cells)
		if not hit:
			hit = _overlaps_any(cells, blocked)
		if not hit:
			hit = _overlaps_any(cells, occupied)
		if hit:
			patch.stats["blocked"] = int(patch.stats["blocked"]) + 1
			push_warning("LayoutPatch[%s]: 新增的 %s@%s 放不下（越界或与已有部件冲突），已跳过"
					% [zone_id, kind, str(at)])
			continue
		_mark(occupied, cells)
		out.append(item)
		patch.stats["added"] = int(patch.stats["added"]) + 1
	return out


## 按 kind 造一件新部件（编辑器"新增"与补丁加载共用）。
## 绿化优先匹配：两表目前没有重名，这里只为确定性。
## [param decal] = true 时**不给碰撞体**（纯装饰，可以走过去）。
static func make_item(kind: String, at: Vector2i, decal: bool = false) -> Dictionary:
	if CampusData.GREEN_KINDS.has(kind):
		var def: Dictionary = CampusData.GREEN_KINDS[kind]
		var cells := CampusData.green_footprint_cells(at, kind)
		var item := {
			"kind": kind,
			"cells": cells,
			"texture_path": CampusData.green_texture(kind),
			"whole_sprite": true,
			"collision": def.get("solid", Rect2(0.2, 0.4, 0.6, 0.5)),
			"foliage": true,
			"_placement": "green",
			"_size_tiles": cells.size / Grid.CELLS_PER_TILE,
		}
		if decal:
			item.erase("collision")
			item["decal_only"] = true
		return item
	if CampusData.PROP_KINDS.has(kind):
		var def: Dictionary = CampusData.PROP_KINDS[kind]
		var item := {
			"kind": kind,
			"cells": CampusData.prop_footprint_cells(at, def["tiles"]),
			"texture_path": CampusData.prop_texture(kind),
			"whole_sprite": true,
			"collision": def.get("solid", Rect2(0.3, 0.6, 0.4, 0.35)),
			"street_prop": true,
			"base_tile": at,
			"_placement": "prop",
			"_size_tiles": def["tiles"],
		}
		if decal:
			item.erase("collision")
			item["decal_only"] = true
		return item
	return {}


## 编辑器/补丁都想知道的一件东西的说明文字
static func describe(item: Dictionary) -> String:
	var src := String(item.get("_src_kind", "?"))
	var kind := String(item.get("kind", ""))
	var label := String((CampusData.PROP_KINDS.get(kind, {}) as Dictionary).get("label", ""))
	if label == "":
		label = String((CampusData.GREEN_KINDS.get(kind, {}) as Dictionary).get("label", ""))
	if label == "":
		label = kind
	if src == SRC_BUILDING or src == SRC_NPC:
		label = String(item.get("_src_label", label))
	return "%s（%s）" % [label, src]


## 建筑当前占地的**外扩矩形**（用于"这个交互点属于哪栋楼"的判定）。
static func _expanded_building_rect(rect: Rect2i, pad_tiles: int) -> Rect2i:
	var pad := pad_tiles * Grid.CELLS_PER_TILE
	return Rect2i(rect.position - Vector2i(pad, pad), rect.size + Vector2i(pad * 2, pad * 2))


## 一个逻辑格点落在哪栋建筑的"附近"（含外扩 pad 格）。找不到返回空串。
##
## 判据是"离最近的那栋楼"，不是"被楼盖住" —— 商店/工位本来就摆在人行道上（楼外），
## 所以必须比"点是否在矩形内"宽一些，否则一个都匹配不上。
static func nearest_building_id(layout: Dictionary, tile: Vector2i, pad_tiles: int = 3) -> String:
	var point := Grid.tile_to_px(tile)   # 逻辑格中心
	var best_id := ""
	var best_d := INF
	for item_variant: Variant in layout.get("buildings", []):
		var item := item_variant as Dictionary
		if String(item.get("_src_kind", "")) != SRC_BUILDING:
			continue
		var rect := Grid.cells_to_rect(item.get("cells", Rect2i()))
		var probe := Grid.cells_to_rect(
				_expanded_building_rect(item.get("cells", Rect2i()), pad_tiles))
		var d := 0.0
		if probe.has_point(point):
			# 在外扩区内：按"点到建筑本体矩形"的距离排（越贴楼越优先）
			d = point.distance_to(rect.get_center())
		else:
			continue
		if d < best_d:
			best_d = d
			best_id = String(item.get("_building_id", ""))
	return best_id


## 某栋建筑**当前**的落点格（清单里查；不在清单里返回 null）。
static func building_tile(layout: Dictionary, building_id: String) -> Variant:
	for item_variant: Variant in layout.get("buildings", []):
		var item := item_variant as Dictionary
		if String(item.get("_src_kind", "")) != SRC_BUILDING:
			continue
		if String(item.get("_building_id", "")) == building_id:
			return item.get("_base_tile", Vector2i.ZERO)
	return null


## 某栋建筑的条件：{ "tile": Vector2i, "size": Vector2i }（当前值）。找不到返回空字典。
static func building_place(layout: Dictionary, building_id: String) -> Dictionary:
	for item_variant: Variant in layout.get("buildings", []):
		var item := item_variant as Dictionary
		if String(item.get("_src_kind", "")) != SRC_BUILDING:
			continue
		if String(item.get("_building_id", "")) == building_id:
			return {
				"tile": item.get("_base_tile", Vector2i.ZERO),
				"size": item.get("_size_tiles", Vector2i.ONE),
			}
	return {}


## 一栋楼的"南沿正中那一格"（逻辑格）—— 门板/门口交互区就摆在这。
##
## ⚠️ 要传**落点格 + 尺寸**而不是 `Rect2i`：布局编辑器可以把楼挪走，而数据表里的
##    `tiles` 是生成期坐标 —— 拿表格坐标算出来的门会留在原地（与"商店触发区不跟楼走"
##    是同一个坑，只是门那两处本来就是从建筑数据现算的，所以之前看起来是对的）。
##    场景脚本现在传"清单里那栋楼**当前**的落点格"，门就跟着楼走了。
static func door_tile_on(tile_pos: Vector2i, size_tiles: Vector2i) -> Vector2i:
	if size_tiles.x <= 0 or size_tiles.y <= 0:
		return Vector2i.ZERO
	return Vector2i(tile_pos.x + size_tiles.x / 2 - 1, tile_pos.y + size_tiles.y - 1)


## 某个经济交互点属于哪栋楼，以及它**相对那栋楼的偏移**（世界像素）。
##
## 为什么需要这一层：`CampusData.shops()/jobs()` 的 `tile` 是**生成期写死的绝对坐标**，
## 而建筑可以被布局编辑器挪走 —— 于是"楼挪了、门口的商店触发区还在原地"
## （用户 2026-09-19 实报："建筑的位置变了，但是买东西的交互触发位置没变"）。
## 把交互点锚到**建筑**上，挪楼时它就跟着走，且**挪动前后手感完全一致**（偏移不变）。
##
## ⚠️ 偏移必须相对该楼的**生成期落点**算，相对"当前落点"算会互相抵消：
##    数据里的商店坐标本来就是围着**生成期**那栋楼写的，而 `origin` 又是同一个坐标系里的
##    当前值 —— 两边一起动，加减一遍正好把位移抵消掉（实测：挪完 6 格，交互点一格没动）。
##    正解：`offset = 数据坐标 − 该楼生成期坐标`，再拿 `当前楼位 + offset` 当实际位置。
##
## 归属判定（三级，见 `infer_anchor_building`）：显式 `building` 字段 → id 同名 → 离谁最近。
## 返回 { "building": id, "offset": Vector2 }；判定不出归属时返回空字典
## （那种点就当**绝对坐标**用 —— 比如广场中央的独立工位，不该跟着楼跑）。
static func resolve_spot(layout: Dictionary, entry: Dictionary, pad_tiles: int = 3) -> Dictionary:
	var zone_buildings: Array = layout.get("buildings", [])
	if zone_buildings.is_empty():
		return {}
	var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
	var building_id := infer_anchor_building(layout, entry, pad_tiles)
	if building_id == "":
		return {}
	var item := _building_item(layout, building_id)
	if item.is_empty():
		return {}   # 写了归属但那栋楼被删了：当绝对坐标用，别乱挪
	# 生成期落点：楼一进清单就带着被 moved 覆盖过的值，所以这里要问 mtime 以外的来源 ——
	# 用补丁里记的 `orig`（没被移过时它等于当前值）。
	var origin := _generation_tile(layout, item)
	var offset := Grid.tile_to_px(tile) - Grid.tile_to_px(origin)
	return {"building": building_id, "offset": offset}


## 清单里某栋建筑那一件（找不到返回空字典）
static func _building_item(layout: Dictionary, building_id: String) -> Dictionary:
	for item_variant: Variant in layout.get("buildings", []):
		var item := item_variant as Dictionary
		if String(item.get("_src_kind", "")) != SRC_BUILDING:
			continue
		if String(item.get("_building_id", "")) == building_id:
			return item
	return {}


## 一件部件"生成期"的落地格：被布局补丁移过时，取补丁里记的 `orig`；否则就是当前位置。
##
## 为什么非要这个值：数据表（`CampusData.shops()` 的 `tile`）是围着**生成期**的建筑坐标写的，
## 想算"交互点相对楼的偏移"就必须拿同一个基准（生成期），否则两边一起动会把位移抵消掉。
static func _generation_tile(layout: Dictionary, item: Dictionary) -> Vector2i:
	var current: Vector2i = item.get("_base_tile", Vector2i.ZERO)
	if not item.has("_patched"):
		return current
	var patch := layout.get("patch", null) as LayoutPatch
	if patch == null:
		return current
	var zone_id := String(layout.get("zone_id", ""))
	var id := String(item.get("_id", ""))
	for entry_variant: Variant in (patch.zone_entries(zone_id)["moved"] as Array):
		var entry := entry_variant as Dictionary
		if String(entry.get("id", "")) == id and entry.has("orig"):
			return LayoutPatch.to_vec2i(entry["orig"])
	return current


## 推断一个经济点锚在哪栋楼。三级判据，**顺序不能换**：
##   ① 数据里显式的 `building` 字段（最可靠 —— 楼被挪远之后"最近"会判错，这时只能靠它）；
##   ② 交互点 id 与建筑 id 同名（`supermarket` → `supermarket` 那栋楼）。
##      实测：只按"离谁最近"会把 `supermarket@(21,12)` 判给 `photo_copy` 那栋楼
##      （两者都在附近，距离只差一格多）—— 挪楼时它就会跟着**别人**跑。
##   ③ 离谁最近（在外扩 pad 格内），给"工位在食堂里"这类没有同名建筑的点兜底。
static func infer_anchor_building(layout: Dictionary, entry: Dictionary, pad_tiles: int = 3) -> String:
	var explicit := String(entry.get("building", ""))
	if explicit != "" and not building_tile(layout, explicit) == null:
		return explicit
	var entry_id := String(entry.get("id", ""))
	if entry_id != "" and not building_tile(layout, entry_id) == null:
		return entry_id
	return nearest_building_id(layout, entry.get("tile", Vector2i.ZERO), pad_tiles)


## 把 `CampusData.shops()/jobs()` 里的一个条目解析成**当前该摆的位置**（逻辑格）。
## 建筑挪过之后，返回的就是"跟着挪过去"的那一格。
static func spot_tile(layout: Dictionary, entry: Dictionary, pad_tiles: int = 3) -> Vector2i:
	var resolved := resolve_spot(layout, entry, pad_tiles)
	if resolved.is_empty():
		return entry.get("tile", Vector2i.ZERO)
	var origin: Variant = building_tile(layout, String(resolved["building"]))
	if origin == null:
		return entry.get("tile", Vector2i.ZERO)
	return Grid.px_to_tile(Grid.tile_to_px(origin as Vector2i) + (resolved["offset"] as Vector2))


## 交互区**上沿**离它所属建筑的南沿最多允许多少像素。
##
## 用户 2026-09-19 实报："需要离开建筑一段距离才能触发买东西的交互，有些奇怪。"
## 量出来的原因：商店 `tile` 写的是**逻辑格**，而 `spot_rect()` 把交互区**居中**在那一格 ——
## 一个 3x2 格的交互区摆在楼南沿下面第 2 格时，它的上沿落在楼南沿 +48px；
## 玩家身体半径 8、探测半径 12，**贴着楼站**时探测圆最多只够到楼南沿 +4px，
## 所以"站在门口"永远差 44px 够不到，必须往南走一格多才提示（还只提示"看牌子"）。
##
## 修法：把"交互区离楼多远"也归建筑管 —— 锚定过的交互区，上沿最多落在楼南沿下方 8px，
## 于是**贴着楼就能按 E**，而且这个距离是**常量**，不会再被数据里那一格的写法牵着走。
const SPOT_GAP_MAX_PX := 8.0


## 交互区的世界矩形（已按上面的规则把它拉到楼边）。
## 没锚上建筑的点（广场中央的独立工位）原样返回 —— 那种点本来就该按绝对坐标摆。
static func spot_rect_for(layout: Dictionary, entry: Dictionary, pad_tiles: int = 3) -> Rect2:
	var spot := CampusData.spot_rect(spot_tile(layout, entry, pad_tiles), entry["size"])
	var resolved := resolve_spot(layout, entry, pad_tiles)
	if resolved.is_empty():
		return spot
	var place := building_place(layout, String(resolved["building"]))
	if place.is_empty():
		return spot
	var building_bottom := float((place["tile"] as Vector2i).y + (place["size"] as Vector2i).y) * Grid.TILE
	var max_top := building_bottom + SPOT_GAP_MAX_PX
	if spot.position.y > max_top:
		spot.position.y = max_top
	return spot


# ------------------------------------------------------------------ 占用 / 重叠诊断


## 已被部件占掉的图块格（编辑器判"这里放不下"靠它）
static func _occupancy(buildings: Array, greens: Array, props: Array) -> Dictionary:
	var out: Dictionary = {}
	for group: Array in [buildings, greens, props]:
		for item_variant: Variant in group:
			_mark(out, (item_variant as Dictionary).get("cells", Rect2i()))
	return out


static func occupancy_of(buildings: Array, greens: Array, props: Array) -> Dictionary:
	return _occupancy(buildings, greens, props)


## "禁放格" = `CampusData.blocked_cells()`（路网/墙/广场/操场，**不含**建筑）
##          + 建筑**当前**占地。建筑单独拎出来补，是为了让"拖过的楼"跟着一起动。
static func blocked_cells_with(buildings: Array, occupied: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in occupied:
		out[key] = true
	for item_variant: Variant in buildings:
		_mark(out, (item_variant as Dictionary).get("cells", Rect2i()))
	return out


## 一件部件**真正挡人的那一小块**（图块格集合）。
##
## ⚠️ 为什么不能拿整块占地判重叠：大树的占地是 8x8 图块（128px），但它的碰撞只有
##    树干那一小块（`GREEN_KINDS[kind].solid`）。生成期本来就是按"占地可以叠、实体不能叠"
##    排的，所以两棵相邻的树/一丛灌木，占地会大面积相交 —— 拿占地判重叠会报一堆**假警报**
##    （实测生活区基线就有 9 "处重叠"，全是树和灌木的叶子碰叶子）。
##    这里改成只看 `solid` 那一块，报出来的才是真的"两件东西撞在一起"。
static func solid_cells(item: Dictionary) -> Array:
	var kind := String(item.get("kind", ""))
	var cells: Rect2i = item.get("cells", Rect2i())
	var def: Dictionary = {}
	if kind == "building" or kind == "gate":
		def = {"solid": Rect2(0.0, 0.0, 1.0, 1.0)}
	elif CampusData.PROP_KINDS.has(kind):
		def = CampusData.PROP_KINDS[kind]
	elif CampusData.GREEN_KINDS.has(kind):
		def = CampusData.GREEN_KINDS[kind]
	else:
		return []
	var solid: Variant = def.get("solid", null)
	if not (solid is Rect2):
		return []  # 补丁新增的"纯装饰"件：不挡人，也就不会跟人撞
	var rect := solid as Rect2
	var px := Rect2(Vector2(cells.position * Grid.CELL), Vector2(cells.size * Grid.CELL))
	var area := Rect2(px.position + px.size * rect.position, px.size * rect.size)
	var out: Array = []
	var x0 := floori(area.position.x / Grid.CELL)
	var y0 := floori(area.position.y / Grid.CELL)
	var x1 := ceili(area.end.x / Grid.CELL)
	var y1 := ceili(area.end.y / Grid.CELL)
	for y in range(y0, maxi(y1, y0 + 1)):
		for x in range(x0, maxi(x1, x0 + 1)):
			out.append(Vector2i(x, y))
	return out


## 补丁之后真正撞在一起的重叠对（编辑器标红用）。返回 [{a, b, site, cells}]
##
## 判定口径：**两边都挡人的那一小块**相交才算数；
## 或者其中一边是**被拖动/新增**的（那是用户刚干的事，哪怕只是"叶子叠叶子"也值得看一眼）。
static func overlaps_of(layout: Dictionary) -> Array:
	var items: Array = layout.get("all", [])
	var taken: Dictionary = {}   # 图块格 -> [item, solid 列表]
	var out: Array = []
	for item_variant: Variant in items:
		var item := item_variant as Dictionary
		var patched := String(item.get("_src_kind", "")) == SRC_ADDED or item.has("_patched")
		if String(item.get("kind", "")) == "building" and not patched:
			continue  # 建筑本来就压在草地上，不算"重叠"
		var solid := solid_cells(item)
		var hit: Variant = null
		for cell_variant: Variant in solid:
			var cell := cell_variant as Vector2i
			if not taken.has(cell):
				continue
			var other := (taken[cell] as Array)[0] as Dictionary
			var both_solid := (taken[cell] as Array)[1] as bool
			if both_solid or patched or String(other.get("_src_kind", "")) == SRC_ADDED \
					or other.has("_patched"):
				hit = other
				break
		if hit != null:
			out.append({
				"a": String((hit as Dictionary).get("_id", "")),
				"b": String(item.get("_id", "")),
				"kind": String(item.get("kind", "")),
				"cells": item.get("cells", Rect2i()),
			})
			continue
		for cell_variant: Variant in solid:
			taken[cell_variant as Vector2i] = [item, not solid.is_empty()]
	return out


## 绿化总件数（生成 + 补丁新增的）。自检与编辑器都该看这个数 —— `layout["greenery"]`
## 只是**生成**出来的那批，补丁新增的件在 `layout["added"]` 里、靠 `_placement` 分流。
static func greenery_count(layout: Dictionary) -> int:
	var n: int = (layout.get("greenery", []) as Array).size()
	for item_variant: Variant in layout.get("added", []):
		if String((item_variant as Dictionary).get("_placement", "")) == "green":
			n += 1
	return n


## 街具总件数（生成 + 补丁新增的）
static func props_count(layout: Dictionary) -> int:
	var n: int = (layout.get("props", []) as Array).size()
	for item_variant: Variant in layout.get("added", []):
		if String((item_variant as Dictionary).get("_placement", "")) == "prop":
			n += 1
	return n


# ------------------------------------------------------------------ 小工具


static func _make_id(zone_id: String, src_kind: String, kind: String,
		tile: Vector2i, seq: int) -> String:
	return "%s|%s:%d|%s@%s" % [zone_id, src_kind, seq, kind, _id_anchor(src_kind, tile)]


static func _mark(target: Dictionary, cells: Rect2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			target[Vector2i(x, y)] = true


static func _overlaps_any(cells: Rect2i, occupied: Dictionary) -> bool:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			if occupied.has(Vector2i(x, y)):
				return true
	return false
