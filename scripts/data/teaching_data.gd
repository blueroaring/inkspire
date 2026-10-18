class_name TeachingData
extends RefCounted
## 大学 · 教学楼的**场景几何** —— 纯数据 + 纯函数，不碰任何节点。
##
## 用户 2026-09-19（`request/01_GOALS.md`）：
##   "这里教学楼场景需要生成三层楼各自的走廊，以及上下楼的楼梯，走廊两边的教室。"
##
## ------------------------------------------------------------------ 为什么是"一层一个场景"
##
## 三层各自是一张地图（`scenes/college/teaching_1f~3f.tscn`），楼梯是**指向兄弟楼层的门**
## （`SceneDoor`），不是"同一张图里把人瞬移"。
## 理由：① 与食堂/卫生间/宿舍完全同一套写法（`SceneRouter` 同时只持有一个场景）；
##       ② 镜头永远只框住当前楼层；③ 以后换成正式美术时每层可以独立替换。
##
## ------------------------------------------------------------------ 楼层平面（俯视）
##
##   ┌──────────────────────────────────────────────────────────┐
##   │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 教 室 所 在 的 厚 墙 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
##   │       ┌──┐      ┌──┐      ┌──┐      ┌──┐                │
## 出口╞══════╡  │══════╡  │══════╡  │══════╡  │═══ 走 廊 ═══╤═══╡楼梯
##   │       └──┘      └──┘      └──┘      └──┘                │
##   │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 教 室 所 在 的 厚 墙 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
##   └──────────────────────────────────────────────────────────┘
##
## ⚠️ **走廊必须窄**（用户 2026-09-19 实报："走廊宽度太大了，不像走廊"）。
##    第一版把整间房的可走区域都当走廊（9 格高 = 288px），看起来像个大厅。
##    现在的写法是"**厚墙 + 窄走廊**"：外框还是 26x10 格（世界 832x320，16:9 屏幕上
##    横向铺满、上下只留一点边），但内部分成三段 ——
##      北侧 3 格 = 教室所在的厚墙（实心，不可走）
##      中间 4 格 = **走廊**（`CORRIDOR_TILES`，128px，约"两个人并排"）
##      南侧 3 格 = 教室所在的厚墙（实心，不可走）
##    于是走廊读起来就是一条窄廊，而两边的厚度读作"墙后面是教室"。
##
## ------------------------------------------------------------------ 两套格子别混
##
## ⚠️ 见 `grid.gd`：本文件里 **逻辑格**（32px）写 `Vector2i/Rect2i` 的 `tiles`，
##    **图块格**（16px）写 `cells`，换算一律走 `Grid.tile_to_cell()` /
##    `Grid.rect_to_cells()`，不要手写 `*2`。

## 楼层数（教学楼的物理层数；`floor_index` 从 0 开始）
const FLOORS := 3

## 一层的外框尺寸（逻辑格）：26 x 10 = 832 x 320 px。
##
## 为什么是这个比例：相机 `fixed_zoom = 0` 时按世界尺寸自动算缩放
## （`CameraFollow._apply_zoom`），26:10 ≈ 2.6 比 16:9(1.78) 更宽，
## 于是**铺满屏幕宽度**、上下留一点边 —— 走廊看起来是"横向贯通的"。
## ⚠️ 改这个数就会改缩放；出生点/楼梯的像素值全部由下面的函数推出来，不用手改。
const ROOM_SIZE := Vector2i(26, 10)

## 墙环厚度（图块数，与宿舍/食堂一致 = 2 图块 = 32px = 1 逻辑格）
const WALL_TILES := 2

## **可走的走廊**（逻辑格）：x 1..24（整条），y 3..6（4 格 = 128px）。
## 这是"走廊有多宽"的唯一定义 —— 门、楼梯、出生点、地面线全部按它算。
const CORRIDOR_TILES := Rect2i(1, 3, 24, 4)

## 地板/墙材质（下标与 TileSet 的 terrain 一致，见 tools/build_tileset.gd）。
## 教学楼走廊使用冷灰石材，让木框玻璃门、灯具与门牌更清楚；教室内部仍由后续场景自定义。
const FLOOR_MATERIAL := CampusData.FLOOR_STONE
const WALL_MATERIAL := CampusData.WALL_STONE

## 教室门（装饰）占的图块格：3 x 2 —— 正好是 Interiors 图集里"木框玻璃双开门"的原生尺寸。
## ⚠️ `place_prop` 会把精灵**等比**缩放到占地里，占地比例与素材不一致就会被压扁
##    （宿舍那批床/椅踩过：横构图塞进竖占地 → 缩成一条）。
const CLASSROOM_DOOR_CELLS := Vector2i(3, 2)

## 教室门在南/北墙上的横向位置（图块格 x）。一排 4 间。
##
## ⚠️ **必须避开楼梯间**（用户 2026-09-19 实报："教学楼的上楼下楼不应该和教室的位置在一起，
##    看起来不合理"）。楼梯间占图块格 x 40..49（逻辑格 20..24）——
##    第一版最后一间教室的门正好落在 x=42，于是"教室门开在楼梯上"。
##    现在最右一间到 x=36 为止，和楼梯之间留出 2 逻辑格的空墙。
##    改这里的数就跟着 `STAIRS_TILES` 一起核对（自检里有断言守着）。
const CLASSROOM_DOOR_X: Array[int] = [4, 14, 24, 34]

## 每层最后一扇南侧门改作卫生间，保留 7 间教室门并给卫生间独立的交互门牌。
const BATHROOM_DOOR_INDEX := 7
const BATHROOM_SIDE := "down"

## 楼梯间（逻辑格）：走廊东端的一整块（占满走廊宽度），上下楼各占一半。
## ⚠️ 这里**没有碰撞** —— 楼梯是要走上去的，做成实体墙就没法用了。
const STAIRS_TILES := Rect2i(20, 3, 5, 4)
const STAIRS_UP_TILES := Rect2i(20, 3, 5, 2)    ## 上楼口（北半边）
const STAIRS_DOWN_TILES := Rect2i(20, 5, 5, 2)  ## 下楼口（南半边）

## 名称（存档槽界面 / 自检用）。下标 = floor_index
const FLOOR_LABELS: Array[String] = ["一层", "二层", "三层"]


static func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Grid.size_to_px(ROOM_SIZE))


static func outer_cells() -> Rect2i:
	return Grid.rect_to_cells(world_rect())


static func inner_cells() -> Rect2i:
	var outer := outer_cells()
	return Rect2i(outer.position + Vector2i(WALL_TILES, WALL_TILES),
			outer.size - Vector2i(WALL_TILES * 2, WALL_TILES * 2))


## 走廊（图块格）
static func corridor_cells() -> Rect2i:
	return _tiles_to_cells(CORRIDOR_TILES)


## 走廊（世界像素）
static func corridor_px() -> Rect2:
	return _tiles_rect_px(CORRIDOR_TILES)


## 走廊两侧要**额外铺成墙**的两条带（图块格）。
##
## 外环（`build_wall_ring`）只给 1 逻辑格厚；这两条把南北各加厚到 3 逻辑格，
## 中间自然只剩 4 格走廊。做法比"直接缩房间高度"好在：世界尺寸不变
## （相机缩放不变、屏幕上下留边不变），变的只是"墙有多厚"。
##
## 返回顺序 = [北带, 南带]。
static func wall_bands_cells() -> Array[Rect2i]:
	var inner := inner_cells()
	var corridor := corridor_cells()
	var north := Rect2i(inner.position, Vector2i(inner.size.x, corridor.position.y - inner.position.y))
	var south_top := corridor.end.y
	var south := Rect2i(Vector2i(inner.position.x, south_top),
			Vector2i(inner.size.x, inner.end.y - south_top))
	return [north, south]


# ---------------------------------------------------------------- 地点 id / 名字


## 第 n 层的地点 id（`GameState.LOCATIONS` 的键）。**只有一个地方拼这个字符串**，
## 免得场景脚本、门口、自检各自拼一遍（拼错就是"未登记的地点"静默不跳转）。
static func location_id(floor_index: int) -> String:
	return "college.teaching_%df" % (clampi(floor_index, 0, FLOORS - 1) + 1)


static func location_name(floor_index: int) -> String:
	var i := clampi(floor_index, 0, FLOORS - 1)
	return "大学 · 教学楼 %s" % FLOOR_LABELS[i]


## 教学楼室内与校园共用时钟判据，夜里教室会换成下班后的见闻。
static func is_night() -> bool:
	return Daylight.period_at(GameState.in_game_minutes) == Daylight.PERIOD_NIGHT


## 契约后的第二天早晨使用独立的校园教学楼见闻。
static func is_morning() -> bool:
	return GameFlow.has_flag(StoryData.FLAG_MORNING)


## 从地点 id 反查楼层号；不是教学楼的地点返回 -1
static func floor_of_location(location: String) -> int:
	for i in FLOORS:
		if location_id(i) == location:
			return i
	return -1


# ---------------------------------------------------------------- 教室门（装饰）


## 本层所有教室：北侧 4 间 + 南侧 4 间。
##
## 返回 `{number, label, side, cells, plate_rect, is_thesis_room, prompt, lines}`：
##   `cells`      门在图块格上占的矩形（`place_prop` 用它摆门板）
##   `plate_rect` 门牌（世界像素），由场景脚本画成一小块浅色矩形 + 教室号
##   `lines`      按 E 看门牌时播的对话
##
## ⚠️ 门摆在**厚墙带最靠走廊的那两行**上（不是外环）：外环离走廊有 3 格远，
##    门开在那儿会变成"墙中间浮着一扇门"。现在门紧贴走廊边，走进去就是门。
## ⚠️ 教室门**不是** `SceneDoor`：本轮不做教室内部（用户 2026-09-19 选择
##    "只做走廊 + 教室门/门牌，门是装饰"）。所以它是 `ExamineObject`：
##    看得见、有门牌、按 E 会说一句，但推不开。
static func classrooms(floor_index: int) -> Array[Dictionary]:
	var i := clampi(floor_index, 0, FLOORS - 1)
	var corridor := corridor_cells()
	# 北墙：紧贴走廊上沿的两行；南墙：紧贴走廊下沿的两行
	var north_row := corridor.position.y - CLASSROOM_DOOR_CELLS.y
	var south_row := corridor.end.y
	var out: Array[Dictionary] = []
	for idx in CLASSROOM_DOOR_X.size():
		var x: int = CLASSROOM_DOOR_X[idx]
		var north_index := idx * 2
		var south_index := north_index + 1
		out.append(_classroom(i, north_index, "up",
				Rect2i(Vector2i(x, north_row), CLASSROOM_DOOR_CELLS)))
		if south_index != BATHROOM_DOOR_INDEX:
			out.append(_classroom(i, south_index, "down",
				Rect2i(Vector2i(x, south_row), CLASSROOM_DOOR_CELLS)))
	return out


## 一层有多少间教室（自检/走查对账用；改 `CLASSROOM_DOOR_X` 会自动跟着变）
static func classroom_doors_count() -> int:
	return CLASSROOM_DOOR_X.size() * 2 - 1


static func bathroom_doors_count() -> int:
	return 1


## 每层唯一的卫生间门：保留在原本最右侧南墙门位，不占用楼梯间。
## 它是走廊内可查看的门，不跳转到宿舍卫生间场景，避免错误地把玩家送回宿舍。
static func bathroom_door(floor_index: int) -> Dictionary:
	var i := clampi(floor_index, 0, FLOORS - 1)
	var corridor := corridor_cells()
	var south_row := corridor.end.y
	var x: int = CLASSROOM_DOOR_X[CLASSROOM_DOOR_X.size() - 1]
	var cells := Rect2i(Vector2i(x, south_row), CLASSROOM_DOOR_CELLS)
	var rect := Grid.cells_to_rect(cells)
	return {
		"id": "bathroom",
		"label": "卫生间",
		"side": BATHROOM_SIDE,
		"cells": cells,
		"plate_rect": Rect2(rect.position.x + 4.0, rect.position.y + 2.0, rect.size.x - 8.0, 12.0),
		"prompt": "看门牌（卫生间）",
		"dialogue_id": "teaching.bathroom.%d" % (i + 1),
		"lines": [
			{"speaker": "", "text": "门牌写着“卫生间”，里面传来水管的回声。"},
			{"speaker": "周明远", "text": "先不进去，还是赶紧去教室吧。", "emotion": "自语"},
		],
	}


## 本层教室的牌子（例：["101 教室", …, "301 毕业论文写作", …]）
static func classroom_labels(floor_index: int) -> Array[String]:
	var out: Array[String] = []
	for room_variant in classrooms(floor_index):
		out.append(String((room_variant as Dictionary)["label"]))
	return out


## 单间教室：编号按楼层排（1F = 101..108，3F = 301..308），
## 三层的**第一间**是"毕业论文写作"要用的那间（剧情里主角要去的教室）。
static func _classroom(floor_index: int, index: int, side: String, cells: Rect2i) -> Dictionary:
	var number := (floor_index + 1) * 100 + index + 1
	var rect := Grid.cells_to_rect(cells)
	# 门牌贴在门朝向走廊的那条边上：北墙的门朝下、南墙的门朝上（玩家从走廊看过来）
	# 尺寸 12px 高：里面要放得下 3 位教室号（字号 9 的世界文字），再小就糊了
	var plate := Rect2(rect.position.x + 4.0,
			rect.position.y + 2.0 if side == "down" else rect.end.y - 14.0,
			rect.size.x - 8.0, 12.0)

	var is_thesis := floor_index == 2 and index == 0
	var label := "%d 教室" % number
	var lines: Array = []
	if is_thesis:
		label = "%d 毕业论文写作" % number
		# ⚠️ 这一间就是"翘课"那场戏的触发点（用户 2026-09-19：
		#    "应该是交互了 301 教室后再触发翘课的对话"）。
		#    白天是那段决定；夜间则换成独立的 301 特别交互，不重复翘课剧情。
		if is_night():
			lines = night_thesis_room_lines(number)
		elif is_morning():
			lines = morning_thesis_room_lines(number)
		else:
			lines = thesis_room_lines(number)
	else:
		if is_night():
			lines = night_classroom_variant_lines(number)
		elif is_morning():
			lines = morning_classroom_variant_lines(number)
		else:
			lines = classroom_variant_lines(number)
	return {
		"number": number,
		"label": label,
		"side": side,
		"cells": cells,
		"plate_rect": plate,
		"is_thesis_room": is_thesis,
		"prompt": "看门牌（%s）" % label,
		"lines": lines,
	}


## 走廊两边**其他教室**门前的见闻 —— `request/08_DIALOG.md` 里那六段，一段一间。
##
## 六段分别是：零星自习的同学 / 空教室 / 水课（睡觉与刷手机）/ 黑板上的合同变换法 /
## 用 ai agent 教学的老师 / 走错门进了办公室。
##
## ⚠️ 分配方式：**按教室号轮转**（见 `classroom_variant_index()`），不是 `randi()`。
##    理由有两条，都很实在：
##      ① 用户的要求是"随机在如下几个分配"，指的是"不要每间都一样"；
##         轮转同样做到了"走廊上不会连着两间说同一句"，而且**每一次进游戏都一样**；
##      ② `randi()` 会让走查/自检里"某间教室说了哪句"变成不可复现的 ——
##         这种"只在玩家机子上偶发"的写法，出问题根本查不出来。
##
## ⚠️ 301（毕业论文写作那间）**不走这里**：它的台词是"翘课那场戏"，见 `thesis_room_lines()`。
##    本函数只是替它兜个底（万一以后有人给它算变体），实际不会被调用。
##
## 一段一间地列成常量、而不是拼在 `_classroom()` 里，是为了让"到底有哪几句"一眼看得完
## （也包括对话编辑器与以后换文案的人）。
const CLASSROOM_VARIANTS: Array = [
	# ① 零星自习的同学
	[
		{"speaker": "", "text": "你看了看教室里，只有几个零星的自习的同学。"},
		{"speaker": "周明远", "text": "这么勤奋，在教室里自习。我这四年里从来没做过。",
			"emotion": "自嘲"},
	],
	# ② 空教室
	[
		{"speaker": "", "text": "你打开了教室门，教室里空无一人，连灯都没开。"},
		{"speaker": "周明远", "text": "上课不在这个教室。", "emotion": "自语"},
		{"speaker": "", "text": "你关上了门。"},
	],
	# ③ 水课：睡觉的、刷手机的
	[
		{"speaker": "", "text": "你从窗户向教室内看去，只见一位教授正使用 ppt 眉飞色舞地讲授中，"
			+ "但是底下的学生有睡觉的，还有刷手机的，认真听课的寥寥无几。"},
		{"speaker": "周明远", "text": "……凑学分的水课。", "emotion": "了然"},
	],
	# ④ 黑板上的推导（大一时认真学过的那门）
	[
		{"speaker": "", "text": "你从窗户向教室里看去，只见上课的教授正在黑板上推导"
			+ "你早就不再熟悉的数学公式，底下的同学认真地做着笔记。"},
		{"speaker": "周明远", "text": "当时我大一学高数时也这么认真过，但是高数还是太难了。",
			"emotion": "怀念"},
		{"speaker": "周明远",
			"text": "我看看在推导什么……合同变换法？亏我还能想起来点线性代数的知识，"
			+ "可能拜那个考研的室友的影响。",
			"emotion": "意外"},
	],
	# ⑤ 用 ai agent 教学的老师
	[
		{"speaker": "", "text": "你看见教室里的老师正在使用 ai agent 进行教学。"},
		{"speaker": "周明远", "text": "现在除了 vibe coding，还有 vibe teaching 了吗？",
			"emotion": "吐槽"},
	],
	# ⑥ 走错门：这是个办公室
	[
		{"speaker": "", "text": "你打开门，发现是一个老师办公室。"},
		{"speaker": "周明远", "text": "……走错了。", "emotion": "尴尬"},
		{"speaker": "", "text": "你急忙关上了门。"},
	],
]


## 夜间普通教室的见闻：①关灯空教室占多数，②零星自习，③教师办公室。
## 301 不走这里，使用下面的 `night_thesis_room_lines()`。
const NIGHT_CLASSROOM_VARIANTS: Array = [
	[
		{"speaker": "", "text": "教室里关着灯，已经没有人了。"},
	],
	[
		{"speaker": "", "text": "教室里还零星有几个自习的同学。"},
		{"speaker": "周明远", "text": "太卷了，现在还在教室学习。", "emotion": "感慨"},
	],
	[
		{"speaker": "", "text": "这是教师办公室。教师都下班了，你也赶紧回宿舍吧。"},
	],
]


## 第二天早晨的教学楼版本：仍可查看，但不再播第一天白天的上课/翘课内容。
const MORNING_CLASSROOM_VARIANTS: Array = [
	[
		{"speaker": "", "text": "教室里还没有正式开始上课，只有几个同学提前到了。"},
	],
	[
		{"speaker": "", "text": "教室门还锁着，里面没有人。"},
	],
	[
		{"speaker": "", "text": "老师正在准备上午的课程，学生们陆续进门。"},
	],
	[
		{"speaker": "", "text": "黑板上写着今天上午的课程安排。"},
	],
	[
		{"speaker": "", "text": "老师正在调试教学用的 ai agent，准备今天的课。"},
	],
	[
		{"speaker": "", "text": "办公室的门开着，老师们正在准备上午的课。"},
	],
]


## 某个教室号该说哪一段（见 `CLASSROOM_VARIANTS` 的分配说明）
static func classroom_variant_lines(number: int) -> Array:
	return (CLASSROOM_VARIANTS[classroom_variant_index(number)] as Array).duplicate(true)


## 夜间普通教室的分配：第一段占五成以上，第二段两间，办公室一间。
## 用每层 8 间教室的槽位做确定性分配，避免每次进楼随机变化，
## 同时保证“教师办公室”这一项不会因为教室号个位数只有 1..8 而永远抽不到。
static func night_classroom_variant_lines(number: int) -> Array:
	var bucket := posmod(number, 8)
	var index := 0 if bucket <= 4 else (1 if bucket <= 6 else 2)
	return (NIGHT_CLASSROOM_VARIANTS[index] as Array).duplicate(true)


static func morning_classroom_variant_lines(number: int) -> Array:
	return (MORNING_CLASSROOM_VARIANTS[classroom_variant_index(number)] as Array).duplicate(true)


## 教室号 → 变体下标（0..5）。**唯一**一处算这个映射的地方，走查与自检都从这里取。
##
## ⚠️ 那个 `+ 1` 不是凑数：教室号是 101 起的（个位是 1），按 `number % 6` 分的话
##    三层第一间 301 会落到 ①「空无一人」—— 而 301 门口明明是"门虚掩着、有人在翻讲义"，
##    两段自相矛盾。`+1` 之后 301 正好落到 ③「水课」（睡觉的、刷手机的、认真听课的寥寥无几），
##    紧邻的 302 落到 ④「黑板上推公式」—— 这正是 08 里"300 那几间"该有的样子。
static func classroom_variant_index(number: int) -> int:
	return posmod(number + 1, CLASSROOM_VARIANTS.size())


## "毕业论文写作"那间教室门口的决定（= 翘课那场戏）。
##
## ⚠️ 这段原来是在 `teaching_floor.gd` 里**一上三楼就自动播**的
##    （`SKIP_LINES` + `_maybe_play_skip_scene`）。用户 2026-09-19 要求改成
##    "**交互了 301 教室之后再触发**"：自动播的问题是玩家还没走到门口、
##    也没看清是哪一间，戏就演完了 —— 而且走到三楼这件事本身不等于"到了教室门口"。
##    现在它挂在 301 的门上，由 `StoryExamine` 触发（做完写 `STORY_SKIPPED_CLASS`）。
##
## 台词逐句照 `request/08_DIALOG.md`（"前往301教室与教室门交互"那一段）：
##   旁白（握上门把的一瞬间改变了主意）→ 出声自语（"我记得好像…不签到来着？"）
##   → 旁白（上周的场景浮现：上世纪的 ppt + 复读机般的讲述，昏昏欲睡）
##   → 决定翘课（"与其听两个小时毕业论文写作理论，还不如多点时间实战写论文呢"）
##   → 旁白（松开把手，准备离开教学楼）。
## ⚠️ 中间两句是**说出声的**（08 里没有括号），所以不是内心独白 ——
##    内心独白在数据里写成 `speaker = 周明远（内心）`（见 `Speakers.DISPLAY`）。
static func thesis_room_lines(number: int = 301) -> Array:
	return [
		{"speaker": "", "text": "门牌：%d　毕业论文写作。门虚掩着，里面有人在翻讲义。" % number},
		{"speaker": "", "text": "你握上教室门把的一瞬间，你改变了主意。"},
		{"speaker": "周明远", "text": "我记得好像上周这门课的老师说过不签到来着？", "emotion": "迟疑"},
		{"speaker": "",
			"text": "上周的场景在你脑中浮现，你记起来上节课你在听到了不签到这句话之后，"
				+ "被老师上世纪的 ppt 和复读机般的讲述搞得昏昏欲睡。"},
		{"speaker": "周明远",
			"text": "……还是翘课得了。与其听两个小时毕业论文写作理论，还不如多点时间实战写论文呢。",
			"emotion": "下定决心"},
		{"speaker": "", "text": "你松开了教室的门把手，准备离开教学楼。"},
	]


## 夜间 301 的特别交互：不再触发白天下课/翘课剧情，只留下这句夜间感想。
static func night_thesis_room_lines(_number: int = 301) -> Array:
	return [
		{"speaker": "", "text": "下午的毕业论文写作签没签到？你无从而知。"},
		{"speaker": "", "text": "但你知道今天已经够魔幻了。"},
	]


static func morning_thesis_room_lines(number: int = 301) -> Array:
	return [
		{"speaker": "", "text": "门牌：%d　毕业论文写作。教室里还没有开始上课。" % number},
		{"speaker": "周明远", "text": "现在还早，先去体育场找艾莉娜吧。"},
	]



## 教学楼自检用：教室门与楼梯间之间必须留出空墙（"门开在楼梯上"是用户报过的 bug）
static func classroom_clear_of_stairs() -> bool:
	var stairs := _tiles_to_cells(STAIRS_TILES)
	for x in CLASSROOM_DOOR_X:
		var door_end := x + CLASSROOM_DOOR_CELLS.x
		if door_end > stairs.position.x:
			return false
	return true


# ---------------------------------------------------------------- 楼梯与出口


## 楼梯口：返回 `{up, down}`，各是 `{tiles, cells, prompt, target_location, target_spawn}`；
## 顶层没有"上楼"、底层没有"下楼"，对应的键**不存在**（场景脚本按 has() 判断）。
##
## ⚠️ 落脚点（`target_spawn`）名字必须与 `spawns()` 里的键一致，否则 `SceneRouter`
##    只会 push_warning 然后把人留在 .tscn 里写的位置（那种"上楼之后站在墙里"的 bug
##    查起来很费劲，所以两边都由本文件提供，不手写字符串）。
static func stairs(floor_index: int) -> Dictionary:
	var i := clampi(floor_index, 0, FLOORS - 1)
	var out := {}
	if i < FLOORS - 1:
		out["up"] = {
			"tiles": STAIRS_UP_TILES,
			"cells": _tiles_to_cells(STAIRS_UP_TILES),
			"prompt": "上楼（%s）" % FLOOR_LABELS[i + 1],
			"label": "楼梯",
			"target_location": location_id(i + 1),
			"target_spawn": SPAWN_FROM_BELOW,
		}
	if i > 0:
		out["down"] = {
			"tiles": STAIRS_DOWN_TILES,
			"cells": _tiles_to_cells(STAIRS_DOWN_TILES),
			"prompt": "下楼（%s）" % FLOOR_LABELS[i - 1],
			"label": "楼梯",
			"target_location": location_id(i - 1),
			"target_spawn": SPAWN_FROM_ABOVE,
		}
	return out


## 楼梯间的地面标记（世界像素）：场景脚本按它画台阶。
## 做成"数据给矩形、脚本去画"是为了以后换正式楼梯素材时只改画法。
static func stair_footprint_px() -> Rect2:
	return _tiles_rect_px(STAIRS_TILES)


static func stairs_up_px() -> Rect2:
	return _tiles_rect_px(STAIRS_UP_TILES)


static func stairs_down_px() -> Rect2:
	return _tiles_rect_px(STAIRS_DOWN_TILES)


## 出口门（回教学区）的图块格：西墙正中，用**窄版竖门** 2x3（宽正好等于墙厚）。
##
## 之所以在西端：走廊的另一头(东端)留给楼梯间，玩家一进门就看见整条走廊。
##
## ⚠️ **只有一层用得上它**（用户 2026-09-20："2、3 楼不应该有直接出教学楼的交互"）：
##    这个矩形是"每层西墙正中"的几何位置，二三层**照样算得出**它 ——
##    所以"哪层该有门"必须由调用方（`teaching_floor.gd::_build_exit()`）按楼层决定，
##    数据这边只描述"门长什么样、开在哪一格"。
static func exit_door_cells() -> Rect2i:
	var corridor := corridor_cells()
	var h := 3
	var top := corridor.position.y + (corridor.size.y - h) / 2
	return Rect2i(0, top, WALL_TILES, h)


## 这一层有没有"出教学楼"的门（只有一层有；二三层只能走楼梯下去）。
##
## ⚠️ 抽成函数是为了让**场景脚本与自检读同一处判据**：
##    自检里那条"二三层不该有 Door_campus"就是按它断言的。
static func has_exit_door(floor_index: int) -> bool:
	return floor_index == 0


## 出口门的数据字典。
##
## ⚠️ 它通往 `college.campus_teaching`，但**剧情上可能要先走一段 CG**
##    （翘课后出楼 → 被天上掉下来的东西砸晕）。那一步交给 `story_door.gd`：
##    这个门字典里带 `story_flag` / `story_location`，门口脚本按开关决定去校园还是去 CG。
static func exit_door() -> Dictionary:
	return {
		"id": "campus",
		"label": "教学楼大门",
		"side": "left",
		"cells": exit_door_cells(),
		"atlas": ATLAS_DOOR,
		"whole_sprite": true,
		"visual_scale": 1.0,
		"render_group": "wall",
		"prompt": "出教学楼（回教学区）",
		"target_location": "college.campus_teaching",
		# ⚠️ 这个出生点**不在 .tscn 里**：由 `campus.gd::_ensure_entrance_spawns()` 按
		#    教学楼当前的位置在门口建出来（楼被布局补丁挪走时它跟着走）。
		#    写死在 .tscn 里的话，楼一挪，出楼就会落在离门很远的地方甚至墙里。
		"target_spawn": "from_teaching_building",
		"story_flag": STORY_SKIPPED_CLASS,
		"story_location": CG_ALYINA,
		"story_spawn": "",
		# ⚠️ **这一条是必需的**（用户 2026-09-19 实报："每次进出教学楼都会触发 cg，
		#    应该在遇到精灵后不会再触发"）。`story_flag` 只说"翘过课"，而翘过课这件事
		#    一旦成立就永远成立 —— 没有这个"演过了"的开关，玩家每次出门都会重看 CG。
		"story_done_flag": STORY_ALYINA_MET,
	}


## 教室门板用的图集坐标：木框玻璃**双开门**（3x2，`tools/interiors_sprite_catalog.md`）。
const ATLAS_CLASSROOM_DOOR := Vector2i(13, 49)
## 出口门板：窄版竖门（2x3，宽正好等于墙厚）
const ATLAS_DOOR := Vector2i(9, 48)
## 卫生间门沿用窄版木门，门牌用程序化青绿色标识区分。
const ATLAS_BATHROOM_DOOR := ATLAS_DOOR
## 走廊陈设：均为 modern_interiors 图集中的原生像素素材。
const ATLAS_WALL_LAMP := Vector2i(14, 59)
const ATLAS_FRAMED_POSTER := Vector2i(9, 24)
const ATLAS_BOOKSHELF := Vector2i(13, 38)


# ---------------------------------------------------------------- 剧情开关与地点 id
#
# 开关名写在这里、由 `story_flags` 存盘（跟着存档走）。
# 为什么集中成常量：同一个开关被"三楼独白 / 出口门 / 任务指引 / 走查断言"四处读，
# 手写字符串拼错一个字母就会静默失效（那种 bug 没有任何报错）。

## 主角在三楼决定翘课（由 `teaching_floor.gd` 播完独白后写入）
const STORY_SKIPPED_CLASS := "skipped_thesis_class"
## 艾莉娜登场（CG 播完写入）
const STORY_ALYINA_MET := "alyina_met"
## 艾莉娜开始跟随（与上一条同时写；分成两个开关是为了以后"她暂时离开队伍"能单独关掉跟随）
const STORY_ALYINA_FOLLOWS := "alyina_follows"

## 翘课后出楼要走的 CG 场景地点 id
const CG_ALYINA := "cg.alyina_fall"

## 出生点名字（`SpawnPoints/<名字>`，也是 SceneDoor 的 target_spawn）
const SPAWN_FROM_CAMPUS := "from_campus"        ## 从教学区推门进来
const SPAWN_FROM_BELOW := "from_stairs_below"   ## 从下一层上来（站在上楼口）
const SPAWN_FROM_ABOVE := "from_stairs_above"   ## 从上一层下来（站在下楼口）


## 出生点（像素）：必须与 `scenes/college/teaching_*.tscn` 里的 Marker2D 一致，
## `teaching_floor.gd` 的自检会逐个对账（这是"出生点卡墙里"唯一的防线）。
##
## y 的取法与食堂同一条经验：门口交互区会**往房间内伸 16px**，所以出生点要落在
## "交互区里但不贴门"的位置（否则一进门就被门框挡住 / 或者干脆站进墙里）。
static func spawns() -> Dictionary:
	var door_rect := Grid.cells_to_rect(exit_door_cells())
	var spawn_y := door_rect.get_center().y
	return {
		SPAWN_FROM_CAMPUS: Vector2(door_rect.end.x + 24.0, spawn_y),
		"default": Vector2(door_rect.end.x + 24.0, spawn_y),
		SPAWN_FROM_BELOW: Vector2(stairs_up_px().position.x - 16.0, stairs_up_px().get_center().y),
		SPAWN_FROM_ABOVE: Vector2(stairs_down_px().position.x - 16.0, stairs_down_px().get_center().y),
	}


## 出生点朝向（`metadata/face_x`、`face_y`）：进门面朝走廊（+x），
## 从楼梯上来面朝走廊（-x，因为楼梯在楼层东端）。
static func spawn_facing(spawn_name: String) -> Vector2i:
	if spawn_name == SPAWN_FROM_BELOW or spawn_name == SPAWN_FROM_ABOVE:
		return Vector2i(-1, 0)
	return Vector2i(1, 0)


# ---------------------------------------------------------------- 换算助手


static func _tiles_to_cells(tiles: Rect2i) -> Rect2i:
	return Rect2i(Grid.tile_to_cell(tiles.position), tiles.size * Grid.CELLS_PER_TILE)


static func _tiles_rect_px(tiles: Rect2i) -> Rect2:
	return Rect2(Grid.tile_to_px(tiles.position) - Vector2(Grid.TILE, Grid.TILE) * 0.5,
			Grid.size_to_px(tiles.size))
