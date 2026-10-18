class_name SpiritTutorial
extends RefCounted
## 一张连续的 31×19 剧情教学地图；九段共用规则、资源与出口，不切换关卡。
const ID := "story-tutorial"
const ORIGINS := [Vector2i(0, 0), Vector2i(10, 0), Vector2i(20, 0),
	Vector2i(20, 6), Vector2i(10, 6), Vector2i(0, 6), Vector2i(0, 12), Vector2i(10, 12), Vector2i(20, 12)]

static func point(zone: int, x: int, y: int) -> Vector3i:
	var origin: Vector2i = ORIGINS[zone]
	return Vector3i(origin.x + (10 - x if zone in [3, 4, 5] else x), origin.y + y, 0)

static func direction(zone: int, local: int) -> int:
	return 4 - local if zone in [3, 4, 5] and local in [1, 3] else local

static func definition() -> Dictionary:
	var rooms := [
		["###########", "###########", "##..#######", "#S.K......#", "##..#######", "###########", "###########"],
		["###########", "###########", "########.j#", "#SJ .I.>..#", "###########", "###########", "###########"],
		["###########", "###########", "###########", "#SBC  R  .#", "###########", "###########", "###########"],
		["###########", "###########", "###########", "#SA#X.P#..#", "###########", "###########", "###########"],
		["###########", "###########", "###########", "#SHHH.T? .#", "###########", "###########", "###########"],
		["###########", "###########", "######...##", "#SO>#.UUK.#", "###>F.#####", "###########", "###########"],
		["###########", "###########", "####WWG####", "#SWVZ+V...#", "###########", "###########", "###########"],
		["###########", "#...p.....#", "###########", "#S..g.....#", "##..#######", "###########", "###########"],
		["###########", "^..g.K.j..#", "#####.#X###", "#S.T.!...E#", "###########", "###########", "###########"],
	]
	var cells: Dictionary = {}
	for y in 19:
		for x in 31: cells[Vector3i(x, y, 0)] = {"kind": "wall"}
	for z in rooms.size():
		for y in 7:
			for x in 11:
				cells[point(z, x, y)] = {"kind": SpiritTiles.SYMBOLS.get(rooms[z][y].substr(x, 1), "floor")}
	# 相邻区域共享门口；南北转弯是实走走廊，只有教学传送格发生传送。
	for link in [Vector2i(10, 3), Vector2i(20, 3), Vector2i(20, 9), Vector2i(10, 9), Vector2i(10, 15), Vector2i(20, 15)]:
		cells[Vector3i(link.x, link.y, 0)] = {"kind": "floor"}
	for y in range(4, 9): cells[Vector3i(29, y, 0)] = {"kind": "floor"}
	for y in range(10, 15): cells[Vector3i(1, y, 0)] = {"kind": "floor"}
	var level := {"id": ID, "display_id": "剧情教程", "title": "回忆长廊", "chapter": "一段完整的回忆",
		"cells": cells, "sizes": [Vector2i(31, 19)], "start": point(0, 1, 3), "facing": 1,
		"steps": 155, "required_keys": 3, "rewinds": 2, "room_style": "corridor", "obstacle_height_scale": 0.32, "tutorial_partitions": true,
		"vision": 6, "vision_persists": true, "follow_camera": true, "camera_span": 7.2,
		"intro": "沿着长廊找回三把钥匙，打开尽头的门。走错了也没关系，按 R 就能回到这一段的入口。",
		"hint": "先向右收集钥匙，沿着亮起的门口前进。", "clear_reward": {"xp": 25, "money": 0, "fragments": 0},
		"enemies": [], "tutorial_zones": [], "solution": PackedStringArray()}
	_patch(level, 1, 2, 3, {"distance": 2})
	# 落点紧接滑轨，转向后在北端停下，再由定向跳板落回主路。
	_patch(level, 1, 5, 3, {"direction": 1})
	_patch(level, 1, 7, 3, {"direction": 0})
	cells[point(1, 7, 2)] = {"kind": "floor"}
	cells[point(1, 8, 2)] = {"kind": "jump_fixed", "direction": 2, "distance": 1}
	cells[point(1, 9, 2)] = {"kind": "wall"}
	_patch(level, 2, 2, 3, {"bridge": "line"})
	_patch(level, 2, 6, 3, {"region": "gallery"})
	level["regions"] = {"gallery": {"past": {point(2, 7, 3): {"kind": "floor"}, point(2, 8, 3): {"kind": "floor"}},
		"present": {point(2, 7, 3): {"kind": "void"}, point(2, 8, 3): {"kind": "void"}}}}
	_patch(level, 3, 2, 3, {"distance": 3})
	_patch(level, 3, 6, 3, {"target": point(3, 8, 3)})
	var platforms := [point(4, 7, 3), point(4, 8, 3)]
	level["random_groups"] = [{"positions": platforms, "tutorial_zone": 4}]
	_patch(level, 4, 6, 3, {"changes": {platforms[0]: {"kind": "bridge", "built": true}, platforms[1]: {"kind": "bridge", "built": true}}})
	_patch(level, 5, 3, 3, {"direction": 2})
	_patch(level, 5, 3, 4, {"direction": direction(5, 1)})
	level.enemies.append({"pos": point(5, 7, 3), "hp": 12, "mode": "static", "tutorial_zone": 5})
	_patch(level, 6, 5, 3, {"amount": 6})
	_patch(level, 6, 6, 3, {"damage": 6})
	_patch(level, 6, 6, 2, {"light_bounds": Rect2i(4, 13, 6, 5)})
	_patch(level, 7, 4, 1, {"channel": "A"})
	_patch(level, 7, 4, 3, {"channel": "A"})
	level.enemies.append({"pos": point(7, 1, 1), "hp": 12, "mode": "patrol", "ping_pong": true, "interval": 2,
		"path": [point(7, 1, 1), point(7, 2, 1), point(7, 3, 1), point(7, 4, 1)], "tutorial_zone": 7})
	_patch(level, 8, 0, 1, {"direction": 1})
	_patch(level, 8, 3, 1, {"channel": "B"})
	_patch(level, 8, 3, 3, {"changes": {point(8, 3, 1): {"kind": "gate", "channel": "B", "open": true, "latched": true}}})
	_patch(level, 8, 5, 3, {"emitters": [point(8, 0, 1)]})
	_patch(level, 8, 7, 1, {"direction": 2, "distance": 2})
	_patch(level, 8, 9, 3, {"requires_power": true})
	level.enemies.append({"pos": point(8, 5, 1), "hp": 999, "strong": true, "mode": "static", "tutorial_zone": 8})
	var lessons := [
		["醒来的长廊", "找到第一把钥匙", "走到钥匙上就能拾取，收齐三把才能开门。鼠标移到机关上，可以查看它的用途。", "第一把钥匙就在右边，沿走廊走过去即可。"],
		["借风前行", "通过跳板和滑轨", "跳板能让你越过缺口。踏上滑轨后，会沿着箭头滑到障碍前。", "向右踏上跳板，再走上滑轨。停下后，向右踩双箭头跳板，回到走廊。"],
		["补好这一页", "修复断掉的走廊", "捡起积木，点击下方的两格形状卡，再点击金框缺口，按 Enter 铺设。", "先拿补给，再选两格形状卡；金点对准第一个缺口，必要时按 F 旋转，预览为青色后按 Enter。过桥后站上紫色回溯格按 Q。"],
		["越过险处", "飞过障碍，找到传送口", "飞行能越过柜子和陷阱，但三格后就会结束。落地踏上传送口，可以去到墙的另一边。", "沿走廊向左飞，第三格落在地板上，再向左走一步进入传送口。"],
		["看不见的路", "走过隐形地板", "看不见的地板仍然能走。记住位置，通过后再找找能固定游移地板的开关。", "先向左走过三块隐形地板，再踩下开关。等前面的两块地板停稳，就可以继续走。"],
		["水与蒸汽", "熄灭火焰，拿到第二把钥匙", "水能熄火，蒸汽则能点燃另一只喷口。试着借这些机关对付挡路的怪物。", "先向左放水，沿箭头向下、再向左走。绕到蒸汽口右侧，向左踏上它。点火后，走上方小路去拿钥匙。"],
		["点亮旧电路", "启动发电机，照亮走廊", "发电机能照亮附近的停电区域。它的机身挡路，踩旁边的导电格才能沿水路送电。", "先向右经过水格和蒸发格，再踩发亮的导电格。灯亮后从发电机下方通过，拿到护盾再穿过热气。"],
		["借它的脚步", "借试卷兽打开门", "你每走两步，试卷兽就走一步。让它踩住 A 压板，就能打开前面的门。", "到门前时，试卷兽还没走到压板。向下走进小路，再向上回来，多绕一次，等它踩上 A 压板就向右穿门。"],
		["接回铃声", "拿到最后一把钥匙", "强敌守着最后一把钥匙。打开上方的门，让飞刺能飞到它面前。", "先踩下方的地形开关开门，再踩发射开关。等怪物倒下，向上去拿钥匙，再向右踩跳板越过陷阱，走到出口。"],
	]
	var routes := ["D D D D D D D D", "D D D D", "D D B D D D Q D D D", "D D D D D D",
		"D D D D D D D D", "D D S D D W D W D D S D", "D D D D D D D D", "D D S W S W D D D D D D", "D D D D W W D D D D"]
	for i in 9:
		var lesson: Array = lessons[i]
		var origin: Vector2i = ORIGINS[i]
		level.tutorial_zones.append({"entry": point(i, 1, 3), "exit": point(i, 9, 3), "bounds": Rect2i(origin, Vector2i(11, 7)),
			"title": lesson[0], "objective": lesson[1], "text": lesson[2], "hint": lesson[3], "reveal_hidden": i == 4})
		for command in routes[i].split(" ", false):
			if command == "B":
				var anchor := point(i, 4, 3)
				level.solution.append("B:line:%d:%d:0:0" % [anchor.x, anchor.y])
			elif i in [3, 4, 5] and command in ["D", "A"]: level.solution.append("A" if command == "D" else "D")
			else: level.solution.append(command)
		if i in [2, 5]:
			for step in 6: level.solution.append("S")
		elif i < 8:
			for step in 2: level.solution.append("A" if i in [3, 4] else "D")
	return level

static func _patch(level: Dictionary, zone: int, x: int, y: int, properties: Dictionary) -> void:
	level.cells[point(zone, x, y)].merge(properties, true)
