class_name SpiritLevels
extends RefCounted
## 每关地图、机关参数与校验路线均独立于 UI。坐标 Vector3i(x, y, 层)。

static func all() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var l := _make("1-1", "放学后的钥匙", "初识灵境", [[
		"#######", "#S..K##", "#.#...#", "#...E##", "#######"]], 5,
		"钥匙与门锁", "D D D S S")
	l["hint"] = "钥匙在右侧，出口在钥匙下方。"
	levels.append(l)
	l = _make("1-2", "走廊断层", "初识灵境", [[
		"#########", "#Sj #K.E#", "#..F....#", "#########"]], 3,
		"跳板与断层", "D D D")
	_patch(l, Vector3i(2, 1, 0), {"distance": 3, "direction": 1})
	l["hint"] = "定向跳板固定向右，落点就是钥匙格。"
	levels.append(l)
	l = _make("1-3", "课桌间的滑轨", "初识灵境", [[
		"#######", "#SI..K#", "#####C#", "#....E#", "#######"]], 3,
		"滑轨与裂板", "D S S")
	_patch(l, Vector3i(2, 1, 0), {"direction": 1})
	l["hint"] = "滑轨尽头是钥匙，下方的裂板只能经过一次。"
	levels.append(l)
	l = _make("2-1", "借一页纸", "搭起回忆", [[
		"#########", "#SB  K.E#", "#########"]], 6,
		"神经通路", "D B:line:3:1:0:0 D D D D D")
	_patch(l, Vector3i(2, 1, 0), {"bridge": "line"})
	l["hint"] = "缺口宽两格，直线通路可以横着补上。"
	l["clear_bridges"] = {"single": 1}
	levels.append(l)
	l = _make("2-2", "昨天的走廊", "搭起回忆", [[
		"#########", "#SR  K.E#", "#########"]], 6,
		"时序回溯", "D Q D D D D D")
	l["rewinds"] = 2
	_patch(l, Vector3i(2, 1, 0), {"region": "hall"})
	l["regions"] = {"hall": {"past": {Vector3i(3, 1, 0): {"kind": "floor"}, Vector3i(4, 1, 0): {"kind": "floor"}}, "present": {Vector3i(3, 1, 0): {"kind": "void"}, Vector3i(4, 1, 0): {"kind": "void"}}}}
	l["hint"] = "回溯能恢复走廊地板；切回现在也会消耗一次回溯。"
	levels.append(l)
	l = _make("2-3", "天台的另一侧", "搭起回忆", [[
		"#########", "#SA#..P##", "#########"], [
		"#########", "#.J.K.E##", "#########"]], 8,
		"飞行与传送", "D D D D D D D D")
	_patch(l, Vector3i(2, 1, 0), {"distance": 3})
	_patch(l, Vector3i(6, 1, 0), {"target": Vector3i(1, 1, 1)})
	_patch(l, Vector3i(2, 1, 1), {"distance": 2})
	l["hint"] = "飞行持续三格，传送门需要落地后触发。"
	levels.append(l)
	l = _make("3-1", "记忆中的座位", "观察与交互", [[
		"#########", "#SHHHK.E#", "# ?    ##", "#########"]], 6,
		"隐形与游移地板", "D D D D D D")
	l["random_groups"] = [{"positions": [Vector3i(2, 2, 0), Vector3i(3, 2, 0), Vector3i(4, 2, 0)]}]
	l["hint"] = "上排连续三格是隐形地板，下排地板会换位。"
	levels.append(l)
	l = _make("3-2", "雨后的实验室", "观察与交互", [[
		"#########", "#SWVZK.E#", "#.WWG####", "#########"]], 6,
		"水路与供电", "D D D D D D")
	_patch(l, Vector3i(4, 2, 0), {"light_bounds": Rect2i(4, 0, 5, 4)})
	_patch(l, Vector3i(4, 1, 0), {"source": Vector3i(3, 2, 0)})
	_patch(l, Vector3i(7, 1, 0), {"requires_power": true})
	l["intro"] = "先烘干，再踩导电格。电流会沿水路启动发电机，照亮右边的实验室。发电机挡路，要从旁边通过。"
	l["hint"] = "先向右经过水格和蒸发格，再踩发亮的导电格。发电机启动后，右边的钥匙和出口就能看清了。"
	levels.append(l)
	l = _make("3-3", "消防演习", "观察与交互", [[
		"##########", "#SO>F.K.E#", "##########"]], 7,
		"水流与火焰", "D D D D D D D")
	_patch(l, Vector3i(3, 1, 0), {"direction": 1})
	l["hint"] = "蓄水格沿朝向放水，水流能熄灭右侧的火焰。"
	levels.append(l)
	l = _make("4-1", "走廊里的追影", "独自越过危险", [[
		"#########", "#S..K.E##", "#.F....##", "#########"]], 7,
		"追逐与陷阱", "S W D D D D D")
	l["enemies"] = [{"pos": Vector3i(3, 2, 0), "hp": 12, "mode": "chase", "sight": 6, "name": "试卷残影"}]
	l["hint"] = "向下移动时，追影会向左追来，经过火焰。"
	levels.append(l)
	l = _make("4-2", "广播室的开关", "独自越过危险", [[
		"#########", "^..K...E#", "#S.!#####", "#########"]], 7,
		"开关与飞刺", "D D W D D D D")
	_patch(l, Vector3i(0, 1, 0), {"direction": 1})
	_patch(l, Vector3i(3, 2, 0), {"emitters": [Vector3i(0, 1, 0)]})
	l["enemies"] = [{"pos": Vector3i(3, 1, 0), "hp": 999, "strong": true, "mode": "static", "name": "监考残影", "xp": 30}]
	l["hint"] = "右侧开关控制上排的飞刺，下排不在射程内。"
	levels.append(l)
	l = _make("4-3", "终课铃声", "独自越过危险", [[
		"#########", "#SBR.K.E#", "### ###.#", "#K.C...P#", "#########"]], 14,
		"回溯与返程", "D D Q S S A A B:single:3:3:0:0 D D D D D D D D")
	l["required_keys"] = 2
	l["quotas"] = {0: 0, 1: 10, 2: 2, 3: 2}
	l["rewinds"] = 1
	_patch(l, Vector3i(2, 1, 0), {"bridge": "single"})
	_patch(l, Vector3i(3, 1, 0), {"region": "stairs"})
	_patch(l, Vector3i(7, 3, 0), {"target": Vector3i(5, 1, 0)})
	l["regions"] = {"stairs": {"past": {Vector3i(3, 2, 0): {"kind": "floor"}}, "present": {Vector3i(3, 2, 0): {"kind": "void"}}}}
	l["enemies"] = [{"pos": Vector3i(4, 1, 0), "hp": 999, "strong": true, "mode": "static", "name": "监考残影"}]
	l["hint"] = "回溯能恢复楼梯。裂板坍塌后，可用单格通路补上返程的缺口；下排右端的传送门通往另一把钥匙。"
	levels.append(l)
	levels.append_array(_advanced())
	return levels

## 进阶关：先观察时序，再组合资源，最后在多层中完成整条因果链。
## solution 只供规则回归；游戏里只显示分层提示，不自动泄露路线。
static func _advanced() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var l := _make("5-1", "错峰放学", "借怪物的脚步", [[
		"###########", "#...p.....#", "###########", "#S..g.K.E.#", "##..#######", "###########"]], 21,
		"巡逻节奏 × 压板门。怪物也有重量：观察它何时踩下压板，再穿过同字母的门。门前下方有绕行空位，可通过移动调整节奏。",
		"D D S W S W D D D D D")
	_patch(l, Vector3i(4, 1, 0), {"channel": "A"})
	_patch(l, Vector3i(4, 3, 0), {"channel": "A"})
	l["enemies"] = [_patrol([Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(3, 1, 0), Vector3i(4, 1, 0)], false)]
	l["enemies"][0]["interval"] = 2
	_hints(l, ["上下走廊隔开了，但压板 A 和门 A 相连。悬停怪物可看巡逻路线。",
		"试卷兽每两次移动走一格。到门前观察 A；没有压亮时，走下方侧路再回来。人在门中时门保持开启。",
		"先向右两步，再向下、向上往返两次。压板亮起后向右穿门取钥匙；错过可继续绕行一轮。"])
	levels.append(l)

	l = _make("5-2", "同时在场", "借怪物的脚步", [[
		"###########", "#...p.....#", "###########", "#Sp..gK.E.#", "##..#######", "###########"]], 21,
		"双压板 × 锁存门。让艾莉娜与巡逻试卷兽同时踩下 A、B，门才会永久解锁。",
		"D S W S W D D D D D D")
	_patch(l, Vector3i(4, 1, 0), {"channel": "A"})
	_patch(l, Vector3i(2, 3, 0), {"channel": "B"})
	_patch(l, Vector3i(5, 3, 0), {"channels": ["A", "B"], "latch": true})
	l["enemies"] = [_patrol([Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(3, 1, 0), Vector3i(4, 1, 0)], true)]
	l["enemies"][0].merge({"pos": Vector3i(2, 1, 0), "interval": 2}, true)
	_hints(l, ["这扇门要求两块压板同时有人，不是先后踩过。试卷兽是另一份重量。",
		"从 B 走进下方侧路再回来，争取与上方强敌同时踩板。门上的锁存标记表示开过就不再关闭。",
		"这只巡逻强敌每两次移动走一格。向右踩 B，再向下、向上往返两次，回到 B 时双板同时压亮。杀死它会失去帮助。"])
	levels.append(l)

	l = _make("5-3", "视线的死角", "借怪物的脚步", [[
		"#####^#####", "#S..#....K#", "#.#.#.###.#", "#...#.....#", "###!..###.#", "#.....#..E#", "###########"]], 22,
		"定向警戒 × 遮挡 × 飞刺。警戒试卷兽只看朝向直线，发现目标后会追踪三回合。利用隔墙接近发射开关。",
		"S S D D S D D W W W D D D D S S S S")
	_patch(l, Vector3i(5, 0, 0), {"direction": 2})
	_patch(l, Vector3i(3, 4, 0), {"emitters": [Vector3i(5, 0, 0)]})
	l["enemies"] = [_enemy(Vector3i(5, 3, 0), "sentry", true, {"facing": 2, "home_facing": 2, "sight": 5, "memory": 3})]
	_hints(l, ["警戒者向下看，中央墙可以挡住它的视线。右侧钥匙必须从它身后的通道接近。",
		"开关位于左下安全区。顶部发射器沿第五列通道向下发射，别站在射线上。",
		"从左侧绕到射击开关，先清掉守卫，再从中央向上取钥匙，沿最右侧下行至出口。"])
	levels.append(l)

	l = _make("6-1", "水线接力", "机关的因果链", [[
		"#############", "#S.O>###K.E##", "#..#.#....###", "#T..>WWG..###", "#############"]], 22,
		"放水转弯 × 导电 × 远程清敌。先接通水路，再从干燥的开关发送电击，最后进入实验室。",
		"D D A A S S D D D D D D D W W D D")
	_patch(l, Vector3i(4, 1, 0), {"direction": 2})
	_patch(l, Vector3i(4, 3, 0), {"direction": 1})
	_patch(l, Vector3i(1, 3, 0), {"electric_source": Vector3i(4, 1, 0), "damage": 999})
	l.cells[Vector3i(7, 3, 0)] = {"kind": "floor"}
	l.cells[Vector3i(7, 2, 0)] = {"kind": "generator", "light_bounds": Rect2i(5, 0, 7, 5)}
	_patch(l, Vector3i(10, 1, 0), {"requires_power": true})
	l["enemies"] = [_enemy(Vector3i(6, 3, 0), "static", true)]
	l["room_style"] = "laboratory"
	_hints(l, ["右侧实验室停电了，发电机旁的水还没连到电源。先沿箭头放水，再回到左下开关送电。",
		"从左向右踩蓄水格，水流会向下再向右。回到左下的干燥开关送电，不要带着自己站进水路。",
		"先放水，沿原路退回起点，再去左下开关。灯亮后沿下方水路前进，从发电机旁边绕到右上的钥匙。"])
	levels.append(l)

	l = _make("6-2", "回溯的两面", "机关的因果链", [[
		"#############", "#K..R.. .E###", "#### ########", "#S..R..B#####", "#############"]], 26,
		"两次回溯 × 先备资源 × 一次性桥。过去打开上楼通路，却拆掉出口一侧的地板；现在恰好相反。",
		"D D D D D D A A A Q W W A A A D D D Q B:single:7:1:0:0 D D D D D")
	_temporal_room(l, 0)
	l["enemies"] = [_enemy(Vector3i(6, 1, 0), "static", true)]
	_hints(l, ["两块回溯机关控制同一区域。钥匙与背包不会随地形回到过去。先看出口还缺哪一格。",
		"先拿下方补给，再恢复楼梯。过去会使上方强敌脚下的地板消失，但也会拆掉出口前两格。",
		"在过去拿左侧钥匙，回到上层回溯机关切回现在；最后用单格通路补好剩下的缺口。"])
	levels.append(l)

	l = _make("6-3", "留一条归路", "机关的因果链", [[
		"#############", "#S.B  K#..E##", "##### #..####", "#KBC...P#####", "#############"]], 27,
		"折角桥 × 双钥匙 × 裂板返程。永久桥要同时服务上下两条路，临时桥则必须留到裂板坍塌以后。",
		"D D B:corner:4:1:0:0 D D D A S S A A A A D B:single:3:3:0:0 D D D D D W D D")
	l["required_keys"] = 2
	_patch(l, Vector3i(3, 1, 0), {"bridge": "corner"})
	_patch(l, Vector3i(2, 3, 0), {"bridge": "single"})
	_patch(l, Vector3i(7, 3, 0), {"target": Vector3i(8, 2, 0)})
	_hints(l, ["折角桥只能放一次。它既要接住上方钥匙，也要接通向下的路。出口要求两把钥匙。",
		"永久桥放在上方三格 L 形缺口。先拿上方钥匙，再下楼；左侧裂板离开后会消失。",
		"下方补给是临时单格桥，取到左侧钥匙后补在坍塌处返程。最后从右端传送到出口侧。"])
	levels.append(l)

	l = _hunt_level("7-1", "隔墙追猎", "追猎型 × 诱导 × 射击时机。它会绕墙寻找最短安全道路，火焰和深坑骗不过它。让它进入射线。")
	l["solution"] = "S S D D S S W W D D W W D D D D".split(" ")
	l["steps"] = 20
	_hints(l, ["追猎者沿道路计算距离，会绕墙，也会避开火焰。中央横廊在飞刺覆盖范围内。",
		"不要急着向钥匙靠近。向下方开关移动，让强敌先从右上方追到中央横廊。",
		"沿左侧下行、横向两格，再连续下行到开关。强敌此时还在横廊；清除后从中央上行取钥匙。"])
	levels.append(l)

	l = _make("7-2", "双层联锁", "综合推演", [[
		"###########", "#SI..pgKP##", "####..#####", "###########"], [
		"###########", "#..p......#", "###########", "#.WVZK.GE##", "###########"]], 25,
		"滑轨定位 × 跨层双压板 × 干湿供电。上层的巡逻者控制下层的门，两把钥匙和电力缺一不可。",
		"D S W S W D D D D D D D D D D")
	l["required_keys"] = 2
	l["room_style"] = "laboratory"
	_patch(l, Vector3i(2, 1, 0), {"direction": 1})
	_patch(l, Vector3i(5, 1, 0), {"channel": "B"})
	_patch(l, Vector3i(6, 1, 0), {"channels": ["A", "B"], "latch": true})
	_patch(l, Vector3i(8, 1, 0), {"target": Vector3i(1, 3, 1)})
	_patch(l, Vector3i(3, 1, 1), {"channel": "A"})
	_patch(l, Vector3i(4, 3, 1), {"damage": 999})
	_patch(l, Vector3i(5, 3, 1), {"water": true})
	_patch(l, Vector3i(6, 3, 1), {"water": true})
	l.cells[Vector3i(7, 3, 1)] = {"kind": "water"}
	l.cells[Vector3i(7, 2, 1)] = {"kind": "generator", "light_bounds": Rect2i(4, 2, 6, 3)}
	_patch(l, Vector3i(8, 3, 1), {"requires_power": true})
	l["enemies"] = [_patrol([Vector3i(1, 1, 1), Vector3i(2, 1, 1), Vector3i(3, 1, 1), Vector3i(4, 1, 1)], false),
		_enemy(Vector3i(6, 3, 1), "static", true)]
	l["enemies"][0]["interval"] = 2
	_hints(l, ["切到全部楼层，找到 A、B 两块压板。滑轨会把艾莉娜送到关闭的门前。",
		"从 B 走进下方侧路再返回，往返两次，与慢速巡逻者同时踩板后门会锁存开启。拿钥匙，传送到上层实验区。",
		"先经蒸发格烘干，再踩导电格。发电机亮起后，实验区的路和钥匙就能看清了；从机身下方走向出口。"])
	levels.append(l)

	l = _hunt_level("7-3", "终夜的联考", "追猎诱导 × 双层回溯 × 远程供电 × 折角桥。先处理身后的追兵，再安排上层的资源、时间状态和出口电源。")
	var upper := _make("upper", "", "", [["#############", "#KT.R..  .###", "#### ### E###", "#...R..B#####", "#############"]], 1, "", "")
	for pos: Vector3i in upper["cells"]: l["cells"][Vector3i(pos.x, pos.y, 1)] = upper["cells"][pos].duplicate(true)
	l["sizes"].append(upper["sizes"][0])
	l["steps"] = 45
	l["required_keys"] = 2
	l["cells"][Vector3i(9, 1, 0)] = {"kind": "portal", "target": Vector3i(1, 3, 1)}
	l["cells"][Vector3i(7, 5, 0)] = {"kind": "water"}
	l["cells"][Vector3i(8, 5, 0)] = {"kind": "water"}
	l["cells"][Vector3i(9, 5, 0)] = {"kind": "generator", "light_bounds": Rect2i(7, 4, 3, 2)}
	_temporal_room(l, 1)
	_patch(l, Vector3i(7, 3, 1), {"bridge": "corner"})
	_patch(l, Vector3i(2, 1, 1), {"electric_source": Vector3i(7, 5, 0), "damage": 999})
	_patch(l, Vector3i(9, 2, 1), {"requires_power": true})
	l["enemies"].append(_enemy(Vector3i(6, 1, 1), "static", true))
	l["solution"] = ("S S D D S S W W D D W W D D D D " +
		"D D D D D D A A A Q W W A A A D D D Q B:corner:7:1:1:0 D D D D S D").split(" ")
	_hints(l, ["把目标拆成三段：在下层清除追兵；到上层先拿桥，再用过去上楼；收集钥匙并供电后回到现在。",
		"上层左侧的开关连接下层水路，能点亮下层机房并给出口送电。过去能拆掉守卫脚下地板，但会断开右侧。",
		"上层补给是折角桥。切回现在后，将它铺在出口前的 L 形缺口，从桥的下端向右进入通电大门。"])
	levels.append(l)
	return levels

static func _enemy(pos: Vector3i, mode: String, strong: bool, extra: Dictionary = {}) -> Dictionary:
	var enemy := {"pos": pos, "mode": mode, "strong": strong, "hp": 999 if strong else 12,
		"name": "试卷兽", "sight": 7, "interval": 1, "xp": 30 if strong else 15}
	enemy.merge(extra, true)
	return enemy

static func _patrol(path: Array, strong: bool) -> Dictionary:
	return _enemy(path[0], "patrol", strong, {"path": path, "ping_pong": true})

static func _hints(level: Dictionary, hints: Array) -> void:
	level["hints"] = hints
	level["hint"] = hints[0]
	# 密集的进阶图采用矮隔断，保留房间边界，同时能看清隔断后的机关。
	level["obstacle_height_scale"] = 0.42
	if level["room_style"] == "classroom": level["room_style"] = "corridor"

static func _temporal_room(level: Dictionary, z: int) -> void:
	level["rewinds"] = 2
	_patch(level, Vector3i(4, 1, z), {"region": "stairs"})
	_patch(level, Vector3i(4, 3, z), {"region": "stairs"})
	_patch(level, Vector3i(7, 3, z), {"bridge": "single"})
	level["regions"] = {"stairs": {
		"past": {Vector3i(4, 2, z): {"kind": "floor"}, Vector3i(5, 1, z): {"kind": "void"}, Vector3i(6, 1, z): {"kind": "void"}},
		"present": {Vector3i(4, 2, z): {"kind": "void"}, Vector3i(5, 1, z): {"kind": "floor"}, Vector3i(6, 1, z): {"kind": "floor"}}}}

static func _hunt_level(id: String, title: String, intro: String) -> Dictionary:
	var level := _make(id, title, "综合推演", [[
		"###########", "#S..#K...E#", "#.#.#.###.#", "^.........#", "###.###.#.#", "#..!..F...#", "###########"]], 20, intro, "")
	_patch(level, Vector3i(0, 3, 0), {"direction": 1})
	_patch(level, Vector3i(3, 5, 0), {"emitters": [Vector3i(0, 3, 0)]})
	level["enemies"] = [_enemy(Vector3i(7, 1, 0), "hunter", true, {"sight": 12, "memory": 3})]
	return level

static func find(id: String) -> Dictionary:
	if id == "clinic-key": return load("res://scripts/spirit/clinic_coop_run.gd").definition()
	if id == "story-tutorial": return load("res://scripts/spirit/spirit_tutorial.gd").definition()
	for level in all():
		if level["id"] == id: return level
	return {}

static func _make(id: String, title: String, chapter: String, layers: Array, budget: int, intro: String, solution: String) -> Dictionary:
	var cells: Dictionary = {}
	var sizes: Array[Vector2i] = []
	var start := Vector3i.ZERO
	for z in layers.size():
		var width := 0
		for row: String in layers[z]: width = maxi(width, row.length())
		sizes.append(Vector2i(width, layers[z].size()))
		for y in layers[z].size():
			var row: String = layers[z][y]
			for x in width:
				var symbol := row.substr(x, 1) if x < row.length() else "#"
				var pos := Vector3i(x, y, z)
				cells[pos] = {"kind": SpiritTiles.SYMBOLS.get(symbol, "floor")}
				if symbol == "S": start = pos
	var room_style: String = {"1-2": "corridor", "2-1": "corridor", "2-2": "corridor",
		"2-3": "rooftop", "3-2": "laboratory", "3-3": "corridor", "4-1": "corridor",
		"4-2": "laboratory", "4-3": "corridor"}.get(id, "classroom")
	return {"id": id, "title": title, "chapter": chapter, "cells": cells, "sizes": sizes, "start": start,
		"room_style": room_style,
		"steps": budget, "intro": intro, "hint": intro, "solution": solution.split(" ", false),
		"clear_reward": {"xp": 10, "money": 0, "fragments": 0}}

static func _patch(level: Dictionary, pos: Vector3i, properties: Dictionary) -> void:
	level["cells"][pos].merge(properties, true)
