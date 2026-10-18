class_name CanteenData
extends RefCounted
## 大学 · 食堂（第一食堂 · 后厨洗碗间）的地图数据 —— **纯数据 + 纯函数**，不碰节点。
##
## 用户 2026-09-19："把食堂打工作为进入食堂场景后可以选择的小游戏，需要先搭建食堂场景"。
## 所以这里定义的是**场景几何**：房间多大、墙/地板材料、餐桌怎么摆、
## 洗碗台与三个回收桶在哪、工位摆在哪、出生点在哪。
## 小游戏本身在 `scripts/minigames/plate_sort_game.gd`，规则与工钱在 `WorkDb`。
##
## 与宿舍/卫生间完全同一套写法：
##   地板层 terrain / 墙层 MATCH_SIDES / 物件层（参与 y 排序）/ 贴地装饰层
##
## ⚠️ 本场景的"家具"是**程序化拼色块**（正式美术还没有）：这是刻意的 ——
##    小游戏与流程必须先能玩。换正式图时只改 `canteen.gd::_build_fixture()` 的画法，
##    占地/碰撞/工位坐标一行都不用动（它对外仍是"占地 + 碰撞 + 名字"这一套）。

## 房间尺寸（逻辑格）：16x14 → 512x448px。比卫生间(11x8)大、比校园(48x34)小。
const ROOM_SIZE := Vector2i(16, 14)

## 墙环厚度（图块数，与宿舍/卫生间一致 = 2 图块 = 32px = 1 逻辑格）
const WALL_TILES := 2

## 地板/墙材质（下标与 TileSet 的 terrain 一致，见 tools/build_tileset.gd）
const FLOOR_MATERIAL := CampusData.FLOOR_TILE_CREAM
const WALL_MATERIAL := CampusData.WALL_STONE

## 工位 id：洗碗间那个工位（场景脚本与走查都按它找节点）
const WORK_ID := "canteen_shift"

## 打饭窗口的 id（交互点节点名 = `Meal_canteen_counter`，见 `canteen.gd::_build_meal()`）
const MEAL_ID := "canteen_counter"

## 打饭窗口交互区**从柜台往房间内伸出去多少像素**（= 玩家的够得着范围）。
##
## ⚠️ 这个数是被"站得到的地方"逼出来的，不是审美：
##   柜台自己整块有碰撞（y 64..96），玩家**中心进不去柜台**，而探测半径只有 12px ——
##   交互区如果只覆盖柜台本身（第一版就是），玩家站在柜台南边第一块地板（y≈164）时
##   离它还有 48px，**永远按不到**（实测：走查里能过、真玩时按 E 没反应，
##   因为走查是 `global_position` 瞬移过去的，会落进柜台里）。
##   现在伸到 y≈176（墙脚那一线）：玩家贴着柜台站着就能够到。
##   ⚠️ 别再改小；也别超过 `inner` 的南沿（会伸进墙里）。
const MEAL_REACH_PX := 112.0


## 打饭窗口的柜台占地（世界像素）—— 交互区与自检都按它算，不抄坐标
##
## ⚠️ 逻辑格 → 世界像素只走 `Grid`（两套格子别混，见 `grid.gd`）：
##    `COUNTER_TILES` 是**逻辑格**矩形，先按 `Grid.TILE` 换算成像素。
## ⚠️ 这里取的是**生效后**的位置（`effective_tile`）：编辑器把柜台拖走过之后，
##    打饭交互区要跟着柜台走 —— 否则"柜台挪了、按 E 的地方还在老位置"（很难查）。
static func counter_rect() -> Rect2:
	var tile := effective_tile("counter", COUNTER_TILES.position)
	return Rect2(Grid.tile_to_px(tile), Grid.size_to_px(COUNTER_TILES.size))


## 打饭窗口的交互区（世界像素）：柜台 + 往南伸出的 `MEAL_REACH_PX`。
## ⚠️ "从柜台一直伸到玩家站得到的地方"是这一条能用的**唯一**原因（详见 `MEAL_REACH_PX`）。
static func meal_rect() -> Rect2:
	var counter := counter_rect()
	return Rect2(counter.position, Vector2(counter.size.x, counter.size.y + MEAL_REACH_PX))


static func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Grid.size_to_px(ROOM_SIZE))


# ---------------------------------------------------------------- 布局覆盖（编辑器写的）
#
# 见 `scripts/data/canteen_layout.gd`：食堂的**家具**可以被布局编辑器拖动，
# 结果写进 `res://data/canteen_layout.json`，游戏侧在这里"读进来 + 覆盖到数据上"。
# ⚠️ 座位那条支线已经删掉（2026-09-20 用户要求去掉食堂的"坐下"交互），
#    所以覆盖层现在只覆盖家具。


## 食堂布局的覆盖层（编辑器写、游戏读）。
##
## ⚠️ 用 `preload` 而不是 `class_name`：本项目的地雷是
##    ——新增 `class_name` 之后**必须**跑一次 `godot --import` 刷新全局类缓存，
##    否则运行时是 `Identifier "Xxx" not declared in the current scope.`（静默炸在建场那一步）。
##    这里只是个静态工具，`preload` 拿到的就是脚本对象、静态方法直接点得出来，没必要多一个全局名。
const CanteenLayout := preload("res://scripts/data/canteen_layout.gd")

## 布局编辑器在同一个进程里重建预览场景时使用的覆盖层。
## 游戏运行时保持为空，仍从 data/canteen_layout.json 读取；工具模式下则让
## 尚未 Ctrl+S 的新增/移动/删除立刻反映到预览场景，避免“数据已改、画面没变”。
static var _editor_overrides: Dictionary = {}
static var _editor_overrides_active := false


static func set_editor_overrides(overrides: Dictionary) -> void:
	_editor_overrides = overrides
	_editor_overrides_active = true


static func clear_editor_overrides() -> void:
	_editor_overrides = {}
	_editor_overrides_active = false


static func _layout_overrides() -> Dictionary:
	return _editor_overrides if _editor_overrides_active else CanteenLayout.load_overrides()


## 这件家具在覆盖层里被标记成"删掉"了吗（编辑器右键删的）
static func is_deleted(kind: String, base: Vector2i) -> bool:
	var overrides: Dictionary = _layout_overrides()
	var table: Dictionary = overrides.get("fixtures", {})
	var key := fixture_key(kind, base)
	if not table.has(key):
		return false
	return bool((table[key] as Dictionary).get("deleted", false))


## 生效后的家具位置：数据里的逻辑格 + 覆盖层（没有覆盖就是原值）
static func effective_tile(kind: String, base: Vector2i) -> Vector2i:
	var overrides: Dictionary = _layout_overrides()
	var table: Dictionary = overrides.get("fixtures", {})
	var key := fixture_key(kind, base)
	if table.has(key):
		return CanteenLayout.to_tile((table[key] as Dictionary).get("tile"), base)
	return base


## 家具覆盖键（**唯一来源**：编辑器写、游戏读都用它，两边不会写岔）
static func fixture_key(kind: String, base: Vector2i) -> String:
	return "%s#%d_%d" % [kind, base.x, base.y]


# ---------------------------------------------------------------- 人物（阿姨 / 端盘子的同学）
#
# 与家具同源的一套覆盖读写，只是**身份用下标**（人物没有"种类 + 原始坐标"这种稳定键：
# 三个同学是同一张图的三张变体，坐标为 0 的话下标就是唯一身份）。
# 编辑器把人物当**第三种条目**（`_src_kind = "person"`），拖/删都写 `people` 这一节。


static func person_key(index: int) -> String:
	return "person#%d" % index


static func effective_person_tile(index: int, base: Vector2i) -> Vector2i:
	var overrides: Dictionary = _layout_overrides()
	var table: Dictionary = overrides.get("people", {})
	var key := person_key(index)
	if table.has(key):
		return CanteenLayout.to_tile((table[key] as Dictionary).get("tile"), base)
	return base


static func is_person_deleted(index: int) -> bool:
	var overrides: Dictionary = _layout_overrides()
	var table: Dictionary = overrides.get("people", {})
	var key := person_key(index)
	if not table.has(key):
		return false
	return bool((table[key] as Dictionary).get("deleted", false))


## 外框（图块格）：整间房 + 墙环
static func outer_cells() -> Rect2i:
	return Grid.rect_to_cells(world_rect())


## 内部地板（图块格）
static func inner_cells() -> Rect2i:
	var outer := outer_cells()
	return Rect2i(outer.position + Vector2i(WALL_TILES, WALL_TILES),
			outer.size - Vector2i(WALL_TILES * 2, WALL_TILES * 2))


# ---------------------------------------------------------------- 家具布局
#
# 布局口径（**都按逻辑格**，别和上面的图块格混）：
#   · 房间 16x14 逻辑格；墙环占掉最外 1 逻辑格 → 可走的地板是 x∈[1,14]、y∈[1,12]；
#   · 北墙那条 y=1 是"后厨操作台"（贴墙摆，占住墙环那一条）；
#   · 所有**要交互**的东西（洗碗台、桶、工位）都必须落在可走范围内或紧贴它 ——
#     家具自己有碰撞，交互区陷进碰撞体里就永远按不到（踩过）。
#
# ## 2026-09-20 晚：**按用户口述重排**
#
# 用户原话："食堂阿姨在打饭处后面；三个桶在合适位置；桌子正常摆放；打饭的同学排在打饭处前面。"
#
#   ① **阿姨在打饭处后面** → 站 `(4, 1)`：柜台占 y=2..3，她的脚在 y=1 那格的上沿（=32px），
#      立绘 36px ⇒ 头顶 ≈52px，从柜台（屏上 y≈45..88）**上沿探出来**；
#      而柜台 root 在 y=128 > 32，y 排序把她**画在柜台之下** ⇒ 下半身被柜台挡住。
#      这正是"站在打饭台后面"的观感（与"柜台前面"是**靠 y 排序区分**的，不是靠坐标猜）。
#   ② **打饭的同学排在打饭处前面** → 三人一排 `x = 2 / 4 / 6, y = 5`，
#      正对柜台（柜台 x=1..5），且都在柜台**南侧**（y 更大 ⇒ 画在柜台之上，人会盖住柜台下沿，正常）。
#      ⚠️ 间距 2 格是为了让各自的 16x12 碰撞体不叠 —— 同格叠人会互相挤开（踩过）。
#   ③ **三个桶在合适位置** → 保持 `x=8..13, y=3..4`（门东侧那一片）：它们**不占过道**
#      （x=7..13 只有门在 y=2），也不挡排队那一列（x=2..6）。
#   ④ **桌子正常摆放** → 三列两排，`x = 1/5/9`、`y = 7/10`，列间留 1 格、排间留 1 格，
#      四面都能绕过去（原来就是这样，保留）。
#   ⑤ 洗碗台下移到 `y=5..6`：给排队那排（y=5）让开 x=1..4 的西侧，
#      同时仍在柜台/排队的**南边**，不挤在一起。

## 打饭窗口（柜台）：贴北墙的第一排地板格（**不能写 y=1**：那一格属于墙环，
## 摆在墙环上的东西会被墙层盖住 —— 实测"柜台只剩一条露在墙外"）。
##
## ⚠️ 2026-09-20 换成真图时**从 4x1 调成 5x2**，原因是**素材宽高比**：
##    柜台那张裁掉透明边距后是 230x75（**3.07 : 1** 的扁长条），
##    塞进 4x1 逻辑格（128x32 = 4:1）只能按高度定标 → 屏幕上又窄又小；
##    给 5x2（160x64 = 2.5:1）之后 `contain` 按宽度定标，做出来 160x52，
##    宽度撑满、高度也够，看着才是"一条柜台"。
##    ⚠️ 这就是 `_place_whole_prop` 注释里说的"占地宽高比要与素材大致对上"，
##       对不上不会报错，只会静静地把家具做小/做扁。
const COUNTER_TILES := Rect2i(1, 2, 5, 2)

## 后厨门（视觉用；不做场景跳转）：摆在墙环**内侧**才看得见。
## ⚠️ 柜台加宽到 x=1..5 之后，门要往东让一格（x=7..8），否则被柜台压住。
const BACK_DOOR_TILES := Rect2i(7, 2, 2, 1)

## 洗碗台（工位的"岗位本体"）。
## ⚠️ 2026-09-20 晚**挪到东墙（x=11..14, y=5..6）**：排队那排同学要占 x=2..8（柜台正前方），
##    而洗碗台原来在西墙 x=1..4 —— 队首那位会**和它叠在一起**（实测截图里能看到）。
##    现在贴东墙：排队那一列整条空出来，洗碗台与三个桶同在房间东侧（后厨那一片）。
const SINK_TILES := Rect2i(11, 5, 4, 2)

## 三个回收桶：颜色与盘子颜色一一对应（小游戏判定就是"放对桶"）
const BIN_TILES: Array[Dictionary] = [
	{"color": "red", "tiles": Rect2i(8, 3, 2, 2)},
	{"color": "blue", "tiles": Rect2i(10, 3, 2, 2)},
	{"color": "green", "tiles": Rect2i(12, 3, 2, 2)},
]

## 餐桌：两排、每排三张，桌与桌之间留 1 格过道（3+1+3+1+3 = 11 格宽）
const TABLE_ROWS: Array[int] = [7, 10]
const TABLE_COLUMNS: Array[int] = [1, 5, 9]
const TABLE_SIZE := Vector2i(3, 2)


## 全部家具：{kind, tiles(=逻辑格 Rect2i), solid, ...}
## 顺序 = 摆放顺序（y 排序按各自脚底锚点算，与顺序无关）
##
## ⚠️ **美术已接真图**（2026-09-20，`request/10_CANTEEN_FIELD_PROMPTS.md` 的 C1~C7）：
##    每件带 `art` = `assets/graphics/props/<名字>/processed/clean.png`。
##    出图规范是"单独一件、居中、脚下一条水平落地线、256x256 画布"，
##    `TileRoom.place_prop(..., {whole_sprite: true})` 会**先裁透明边距再等比塞进占地**
##    （踩过的三个坑见 `tile_room.gd::_place_whole_prop` 的注释），所以这里只管给占地。
##
## ⚠️ **`display_px` = 这件家具在屏幕上该占多大（像素，宽 x 高）**（用户 2026-09-20：
##    "打饭台和洗手池也太大了"）。
##
##    不填就是"塞满整个占地"—— 那会让柜台/洗碗池比主角大出一大截
##    （主角屏幕上才 ~30px 高：帧 48 × 内容占 83% × 倍率 0.75）。
##    参考尺度：**主角 ≈ 30px 高**，垃圾桶到腰、餐桌到腰偏上、柜台到胸口略下。
##
##    ⚠️ 这是**超上限**，不是"必须这么大"：`place_prop` 仍会 keep 宽高比取较小值，
##       所以不会把素材拉变形（`--strict-qc` 与"等比缩放"的走查断言都不会红）。
##    ⚠️ 它**只改画面**：挡人范围由 `tiles`（占地逻辑格）决定，一点不变 ——
##       否则"看着能站、其实走不进去"（或反过来能穿进柜台）就会出现。
const DISPLAY_PX := {
	"counter": Vector2(132.0, 44.0),
	"sink": Vector2(84.0, 46.0),
	"table": Vector2(58.0, 48.0),
	"bin": Vector2(46.0, 42.0),
}

## ⚠️ **`solid_frac` = 这件家具**按画面的哪一部分挡人**（0..1，从**底边**往上量）。
##
## 用户 2026-09-20 实报："食堂的碰撞箱有问题，太大了"。
## 第一版是"按整个占地挡人"（`collision_px` = 占地像素），本意是"别让玩家穿进柜台" ——
## 但画面缩小之后（见 `DISPLAY_PX`），占地比画面大一圈，于是**看着没东西的地方走不过去**。
## 现在改成：**碰撞跟画面走**，只不过只挡"贴地的那一截"（家具的高立面本来就不该挡人，
## 这是 `tile_room.gd::_place_whole_prop` 里 `collision` 注释说过的口径）。
##
## 取值理由（都是"这件东西实际占地的样子"）：
##   · 垃圾桶：整个桶就是个圆柱，全高都挡 —— 1.0
##   · 洗碗池：水槽台面是实心的，挡到台面上沿 —— 0.85
##   · 餐桌：桌面悬空、只有四条腿和凳子腿占地，挡下面那一半 —— 0.62
##   · 柜台：同理，挡柜台下沿那一截 —— 0.58
const SOLID_FRAC := {
	"counter": 0.58,
	"sink": 0.85,
	"table": 0.62,
	"bin": 1.0,
}


## 这件家具**实际挡人的矩形**（相对显示矩形，左上角为 (0,0)）。
##
## 与 `place_prop` 的 `collision`（归一化 0..1、相对**显示**尺寸）是同一套坐标系，
## 所以直接给归一化值即可 —— 视觉缩放之后它自然跟着画面走，这正是我们要的。
## 全宽挡人（家具不会允许你从侧面挤进去），高度按 `SOLID_FRAC`。
static func solid_rect(kind: String) -> Rect2:
	var frac := float(SOLID_FRAC.get(base_kind(kind), 1.0))
	var top := clampf(1.0 - frac, 0.0, 1.0)
	return Rect2(0.0, top, 1.0, 1.0 - top)


## **数据表原始**的家具清单（不过覆盖层：不看"删掉"、也不改位置）。
##
## ⚠️ 专给**布局编辑器**用：`fixtures()` 会跳过被删的件（游戏侧不该建它们），
##    而编辑器要**看得见**被删的件（用户 2026-09-20："删除也看不到删除的样子"）。
##    两边共用 `fixtures()` 的话，编辑器就永远看不到"已删除"这一状态。
static func raw_fixtures() -> Array[Dictionary]:
	return _raw_fixtures()


## **数据表原始**的人物清单（同上，给编辑器用）
static func raw_people() -> Array[Dictionary]:
	return _raw_people()


## 数据表里"这一间食堂该有哪些家具"（**唯一来源**，`fixtures()` 与编辑器都从它出发）
static func _raw_fixtures() -> Array[Dictionary]:
	var raw: Array[Dictionary] = []
	# ⚠️ 打饭窗口柜台**没有** `examine`：它上面挂的是 `MealSpot`（按 E 打饭）。
	#    同一格再挂一个"看看窗口"会让玩家得先按 Tab 才找得到打饭，
	#    而那正是开场主线要按的东西（同"开局的手机压过旁边的床"那条经验）。
	raw.append({"kind": "counter", "tiles": COUNTER_TILES, "solid": true,
			"art": "canteen_counter/processed"})
	# ⚠️ 后厨门**没有对应素材**（10 的 C 系列只有 8 件，不含门），继续走程序化色块。
	raw.append({"kind": "back_door", "tiles": BACK_DOOR_TILES, "solid": true})
	raw.append({"kind": "sink", "tiles": SINK_TILES, "solid": true,
			"examine": "sink", "art": "canteen_sink/processed"})
	for bin_variant in BIN_TILES:
		var bin: Dictionary = bin_variant
		raw.append({
			"kind": "bin",
			"tiles": bin["tiles"],
			"solid": true,
			"color": String(bin["color"]),
			"label": "%s桶" % PlateTypes.color_name(String(bin["color"])),
			"examine": String(bin["color"]),
			# 三个桶是三张**单独**的图（颜色就画在图上，不再靠 tint 染）
			"art": "canteen_bin_%s/processed" % String(bin["color"]),
		})
	for row in TABLE_ROWS:
		for column in TABLE_COLUMNS:
			raw.append({
				"kind": "table",
				"tiles": Rect2i(Vector2i(column, row), TABLE_SIZE),
				"solid": true,
				"art": "canteen_table/processed",
			})
	return raw


static func fixtures() -> Array[Dictionary]:
	var raw := _raw_fixtures()

	# 把布局覆盖（编辑器拖过的位置）盖上去。
	# ⚠️ 两个位置都要带出去：
	#   · `tiles`      = **生效**位置（游戏按它摆、编辑器按它画）；
	#   · `base_tiles` = **数据里的原始**位置，用来算覆盖键
	#     （键一旦拿生效位置去算，拖第二次就找不到原来那一条了 —— 与校园那边
	#      `_added_entry_index` 注释里说的"拖过的新增件再拖一次点不中"是同一个坑）。
	var out: Array[Dictionary] = []
	for item_variant in raw:
		var item: Dictionary = item_variant
		var base: Rect2i = item["tiles"]
		var kind := String(item["kind"])
		# 编辑器右键删掉的：数据不动，只是**不生成**
		if is_deleted(kind, base.position):
			continue
		var tile := effective_tile(kind, base.position)
		var moved := item.duplicate()
		moved["base_tiles"] = base
		moved["key"] = fixture_key(kind, base.position)
		moved["tiles"] = Rect2i(tile, base.size)
		out.append(moved)
	return out


## 食堂里"站着的人"：打饭阿姨 + 三个端盘子的同学（C7 / C8）。
## 为什么她们不放进 `fixtures()`：那批是**家具**（有碰撞、进物件层记账、
## 还能被 `_build_examine()` 挂"看看"），而这几位是**人**——
## 走 `ActorSprite` 那套立绘口径（脚底对齐、按角色倍率缩放），
## 也因此**不参与**家具碰撞覆盖率统计。
##
## ⚠️ 但**碰撞是有的**（2026-09-20 用户："没有碰撞体积"）：各带一个
##    16x12 的 `Body`（`Layers.ENVIRONMENT`）。所以"不进家具统计"与"挡人"不矛盾 ——
##    前者说的是**记账体系**（家具碰撞覆盖率），后者是**玩法**。
##
## `tile` 是**逻辑格**（1x2 格的站位，与 `_place_whole_prop` 的脚底口径一致）。
##
## ⚠️ 站位都挑在**过道**上，不压桌子也不压工位。
##
## 2026-09-20 晚按用户口述重排（原话："食堂阿姨在打饭处后面；三个桶在合适位置；
## 桌子正常摆放；打饭的同学排在打饭处前面"）：
##   · **阿姨 `(4, 1)`** —— 在打饭柜台（x=1..5, y=2..3）**后面**。
##     位置细节：她的脚落在 y=1 那格的上沿（32px），立绘 36px ⇒ 头顶 ≈52px，
##     从柜台上沿（屏上 y≈45）**探出来**；柜台 root 在 y=128 > 32 ⇒
##     y 排序把柜台画在她**之上**（下半身被遮）—— 这就是"站在台后"的观感。
##     ⚠️ 别为了"看得全"把她挪到 y=1 以南：那样就变成"站在台前"了。
##   · **同学 `x=2/4/6, y=5`** —— 正对柜台、排成一列（柜台前）。
##     ⚠️ 间距 2 格：各自的 16x12 碰撞体挨着但不重叠（同格会互相挤开）。
##     ⚠️ y=5：柜台碰撞到 y=3 ⇒ y=4 太贴；而 y=5 与桌子（y=7 起）之间仍留 y=6 一条走道。
##     ⚠️ 洗碗台已挪到**东墙**（`SINK_TILES`），所以这一列 x=1..9 整条是空的。
##        第一版洗碗台留在西墙 x=1..4，队首那位就**和它叠在一起**了（实测截图看得到）。
##
## ⚠️ **这几位也能在布局编辑器里拖**（用户 2026-09-20："食堂的 npc 也应该能用 layouteditor 编辑"）。
##    实现与家具同源：`effective_person_tile()` 读覆盖层，编辑器把人物当第三种条目。
##    **下标就是身份**（`index` = 本数组下标）—— 改了数组顺序就等于换了人
##    （覆盖层里的下标会指错），所以这里**只允许往后追加、不许插队**。
static func people() -> Array[Dictionary]:
	var raw := _raw_people()
	# 把布局覆盖（编辑器拖过的位置 / 删掉的人）盖上去，并补上 `index` 与 `key`。
	# ⚠️ 与 `fixtures()` 同一套做法：`tile` 是**生效**位置，`base_tile` 用来算覆盖键
	#    （键一旦拿生效位置去算，拖第二次就找不到原来那一条了）。
	var out: Array[Dictionary] = []
	for i in raw.size():
		var person: Dictionary = raw[i]
		if is_person_deleted(i):
			continue
		var base: Vector2i = person["tile"]
		var moved := person.duplicate()
		moved["index"] = i
		moved["base_tile"] = base
		moved["key"] = person_key(i)
		moved["tile"] = effective_person_tile(i, base)
		out.append(moved)
	return out


## 数据表里"这一间食堂该有哪几位人"（**唯一来源**）。下标 = 身份，见 `people()` 的说明。
static func _raw_people() -> Array[Dictionary]:
	return [
		{
			# **阿姨在打饭处后面**（用户 2026-09-20 晚口述）。
			# 脚落在 y=1 那格的上沿（32px），立绘 36px ⇒ 头顶 ≈52px，
			# 从柜台（屏上 y≈45..88）上沿探出来；柜台 root 在 y=128 > 32，
			# y 排序把柜台画在她之上 ⇒ 下半身被挡住 —— "站在台后"的观感。
			# ⚠️ 别再把她往南挪（那样就成"站在台前"了），也别为了"看得全"抬 z。
			"name": "打饭阿姨",
			"art": "canteen_aunt/processed",
			"tile": Vector2i(4, 1),
		},
		{
			# **排队的同学**：正对柜台（柜台 x=1..5）、在它**南侧**（y 更大 ⇒ 画在柜台之上）。
			# 间距 2 格是给各自的 16x12 碰撞体留位置（同格会互相挤开）。
			"name": "端着盘子的同学 A",
			"art": "canteen_student/processed-a",
			"tile": Vector2i(2, 5),
		},
		{
			"name": "端着盘子的同学 B",
			"art": "canteen_student/processed-b",
			"tile": Vector2i(4, 5),
		},
		{
			"name": "端着盘子的同学 C",
			"art": "canteen_student/processed-c",
			"tile": Vector2i(6, 5),
		},	]


## 布局编辑器"新增素材"用的清单：**家具**。
##
## ⚠️ 与 `fixtures()` 的区别：那个是**本房间实际的布置**（12 件，位置固定），
##    这里是"**可以放什么**"（按类各给一条），新增出来的件在覆盖层里另有一份记录。
##    所以两边的键**不能共用**：`fixtures()` 的键是 `counter#1_2`（原始格），
##    新增件的键是 `counter#new3`（序号）—— 共用的话"新增的柜台"会和"原来的柜台"
##    互相覆盖（改了位置两边一起动）。
##
## `tiles` 是**逻辑格**占地（与 `fixtures()` 同口径），`art` 是素材目录名。
static func palette_fixtures() -> Array[Dictionary]:
	return [
		{"kind": "counter", "label": "打饭柜台", "tiles": COUNTER_TILES.size,
			"art": "canteen_counter/processed", "solid": true},
		{"kind": "sink", "label": "洗碗池", "tiles": SINK_TILES.size,
			"art": "canteen_sink/processed", "solid": true},
		{"kind": "table", "label": "餐桌（带凳）", "tiles": TABLE_SIZE,
			"art": "canteen_table/processed", "solid": true},
		# ⚠️ **三个颜色的桶分开列**（2026-09-20 用户在编辑器里连加了 4 个桶，
		#    结果四个都是"回收桶"——因为原来只有一条通用条目，颜色就丢了）。
		#    素材本来就是三张单独的图（`canteen_bin_<color>`），所以这里拆成三条，
		#    各自带 `art`；`solid_rect()` 那边按 `kind.begins_with("bin")` 认基准种类。
		{"kind": "bin_red", "label": "红桶", "tiles": Vector2i(2, 2),
			"art": "canteen_bin_red/processed", "solid": true},
		{"kind": "bin_blue", "label": "蓝桶", "tiles": Vector2i(2, 2),
			"art": "canteen_bin_blue/processed", "solid": true},
		{"kind": "bin_green", "label": "绿桶", "tiles": Vector2i(2, 2),
			"art": "canteen_bin_green/processed", "solid": true},
	]


## 一件家具的"基准种类"：把调色板里的细分种类折回 `SOLID_FRAC` / `DISPLAY_PX` 认的那几个。
##
## 为什么需要（2026-09-20）：调色板把回收桶拆成了 `bin_red` / `bin_blue` / `bin_green`
## （为了保住颜色与标签），而碰撞比例/显示上限是按 `bin` 这一档配的 ——
## 不折一下，新增的桶会拿不到 `SOLID_FRAC`（退回"整块挡人"）和 `DISPLAY_PX`（画面不缩）。
static func base_kind(kind: String) -> String:
	for prefix in ["bin", "table", "sink", "counter"]:
		if kind == prefix or kind.begins_with(prefix + "_"):
			return prefix
	return kind


## 布局编辑器"新增素材"用的清单：**人物**（阿姨 / 端盘子的同学）。
##
## ⚠️ 人物只有**三个素材**（阿姨 + 同学 A/B/C 各一张），不存在"种类"这种身份 ——
##    所以新增出来的人**是纯装饰**（不在 `people()` 那个正式数组里），
##    只存在于覆盖层的 `props` 节（见 `canteen_layout.gd` 的结构说明）。
##    正式的那 4 位（商店/走查会数人头）仍然由 `people()` 管。
static func palette_people() -> Array[Dictionary]:
	return [
		{"kind": "aunt", "label": "打饭阿姨", "tiles": Vector2i(1, 2),
			"art": "canteen_aunt/processed"},
		{"kind": "student_a", "label": "端盘子的同学 A", "tiles": Vector2i(1, 2),
			"art": "canteen_student/processed-a"},
		{"kind": "student_b", "label": "端盘子的同学 B", "tiles": Vector2i(1, 2),
			"art": "canteen_student/processed-b"},
		{"kind": "student_c", "label": "端盘子的同学 C", "tiles": Vector2i(1, 2),
			"art": "canteen_student/processed-c"},
	]


## 编辑器**新增的**家具/人物（覆盖层 `props` 节）：`[{kind, tile, person?}, ...]`
##
## ⚠️ 它们与 `fixtures()` / `people()` 是**两条独立的支线**：
##    那两条是"数据表规定的布置"（可被覆盖层改位置/删掉），
##    这一条是"编辑器额外加上去的件"。分开的理由见 `palette_fixtures()` 的说明。
static func extra_props() -> Array[Dictionary]:
	var overrides: Dictionary = _layout_overrides()
	var table: Dictionary = overrides.get("props", {})
	var out: Array[Dictionary] = []
	var keys: Array = table.keys()
	keys.sort()
	for key_variant in keys:
		var entry: Dictionary = table[key_variant]
		if bool(entry.get("deleted", false)):
			continue
		var kind := String(entry.get("kind", ""))
		var person := bool(entry.get("person", false))
		var def := palette_person(kind) if person else palette_fixture(kind)
		if def.is_empty():
			continue
		var item := def.duplicate()
		item["key"] = String(key_variant)
		item["kind"] = kind
		item["person"] = person
		item["tile"] = CanteenLayout.to_tile(entry.get("tile"), Vector2i.ZERO)
		item["base_tile"] = item["tile"]
		out.append(item)
	return out


## 调色板里某一类家具的定义（找不到返回空字典）。
##
## ⚠️ **兼容旧格式**：调色板早先只有一条笼统的 `"bin"`。用户在那一版里新增过桶，
##    覆盖层留下的 `kind` 就是 `"bin"` —— 直接查表会查不到，而
##    `canteen.gd::_build_extra_props()` 查不到就**整件不建**（静默消失）。
##    所以这里把 `"bin"` 折到红的（老记录没有颜色信息，红的是那一版配的图）。
static func palette_fixture(kind: String) -> Dictionary:
	for entry_variant in palette_fixtures():
		var entry: Dictionary = entry_variant
		if String(entry["kind"]) == kind:
			return entry
	if kind == "bin":
		return palette_fixture("bin_red")
	return {}


## 调色板里某一位人物的定义（找不到返回空字典）
static func palette_person(kind: String) -> Dictionary:
	for entry_variant in palette_people():
		var entry: Dictionary = entry_variant
		if String(entry["kind"]) == kind:
			return entry
	return {}


## 某件家具/人物的素材路径（没有素材返回空串 = 调用方退回程序化色块）。
##
## ⚠️ `name` 是**相对 `props/` 的目录**，必须把生成器的产物目录一起写上：
##    普通条目是 `<名字>/processed`，C8 那三张变体是 `<名字>/processed-a` 等
##    （`generate2dsprite` 的多变体产物）。**只写 `<名字>` 会静默找不到** ——
##    表现是打饭阿姨和三个同学一个都没摆上，只留一条 warning（踩过一次）。
static func art_path(name: String) -> String:
	if name == "":
		return ""
	return "res://assets/graphics/props/%s/clean.png" % name


## 食堂**没有**可坐的座位（2026-09-20 用户："去掉食堂在凳子上坐下的交互"）。
##
## 曾经这里有一个 `seats()`：从餐桌的东/西外沿算出 6 个座位点，配 `SitSpot`
## 做"在凳子上坐下"。整套（`seats()` / `effective_seat_tile()` / `is_seat_deleted()` /
## 两句旁白 / 覆盖层 / 对话目录条目 / 编辑器条目）**已一并删除** ——
## 只留一半会让人以为"凳子还能坐，只是没生效"。
##
## ⚠️ 凳子仍然**画在** `canteen_table` 那张图里，那只是美术，不是交互点。
## ⚠️ **长椅的坐下交互不受影响**（走 `BenchSpot`，与食堂无关）。


## 工位（洗碗间）：摆在洗碗台**西侧**的过道上（玩家走得到，且贴着洗碗池）
##
## ⚠️ 洗碗台 2026-09-20 晚挪到东墙（x=11..14）之后，工位跟着从 `(4,6)` 挪到 `(8,5)` ——
##    工位是"站在洗碗台旁边干活"的位置，离洗碗台太远就变成"站在房间中间发呆"。
##    ⚠️ `(8,5)` 也刚好避开排队那一列（同学在 x=2/4/6）。
static func work_tiles() -> Vector2i:
	return Vector2i(8, 5)


static func works() -> Array[Dictionary]:
	return [{"id": WORK_ID, "job_id": WORK_ID, "tile": work_tiles(), "size": Vector2i(3, 2)}]


# ---------------------------------------------------------------- 出生点与门


## 出生点（像素）：从食堂推门进来站在**南墙门内侧**，面朝房间内（-y）。
## ⚠️ 门占 y=368..399、交互区还往房间内伸了 16px（到 352），所以出生点取 y=358
##    （在交互区里但不贴门）。数值必须与 `scenes/college/canteen.tscn` 的 Marker 一致。
static func spawns() -> Dictionary:
	return {
		"default": Vector2(240.0, 358.0),
		"from_campus": Vector2(240.0, 358.0),
	}


## 回校园的门（南墙正中）
static func door_cells() -> Rect2i:
	return Rect2i(14, 24, 2, 2)


static func door() -> Dictionary:
	return {
		"id": "campus",
		"label": "回校园",
		"prompt": "推门出去（回校园）",
		"cells": door_cells(),
		"side": "down",
		"target_location": "college.campus",
		"target_spawn": "from_canteen",
		# ⚠️ 用户 2026-09-20："按 B 打开背包、用手机看看现在几点这个任务不应该允许角色离开食堂，
		#    做完才行" —— 08 里这一段是"吃完饭/打完工 → **打开背包看手机** →
		#    任务更新为前往教学楼"，顺序上手机必须**在食堂里**看。
		# ⚠️ 所以这扇门锁在 `QuestData.FLAG_PHONE_AFTER_MEAL`（出门前看过手机）上，
		#    而不是"吃过饭"：吃过饭就能走的话，玩家会直接走到教学楼，
		#    "看手机"这一步就被跳过了（而它还要写任务开关、给下一步的指引用）。
		#    锁着的台词见 `CanteenData.ENTRANCE_LOCKED` 的 `door` 那一条。
		"required_flag": QuestData.FLAG_PHONE_AFTER_MEAL,
		"locked_message": "（先看一眼手机吧：下午两点有课，别漏了。）",
	}


# ---------------------------------------------------------------- 查看文案


const EXAMINES := {
	"red": {
		"name": "红色回收桶",
		"prompt": "看看红色桶",
		"lines": [
			{"speaker": "", "text": "红色塑料桶，桶沿磨得发白，贴着「红盘」两个字。"},
			{"speaker": "周明远", "text": "（规矩很简单：看颜色。放错了重放，没人骂你，只是慢。）", "emotion": "自语"},
		],
	},
	"blue": {
		"name": "蓝色回收桶",
		"prompt": "看看蓝色桶",
		"lines": [
			{"speaker": "", "text": "蓝色桶里已经摞了半桶盘子，叮叮当当地响。"},
		],
	},
	"green": {
		"name": "绿色回收桶",
		"prompt": "看看绿色桶",
		"lines": [
			{"speaker": "", "text": "绿色桶是空的 —— 绿盘子今天大概没怎么用。"},
		],
	},
	"sink": {
		"name": "洗碗池",
		"prompt": "看看洗碗池",
		"lines": [
			{"speaker": "", "text": "不锈钢洗碗池，池底还留着上一趟的水。三个桶就摆在手边，伸手就能够到。"},
			{"speaker": "周明远", "text": "（一小时的活儿。听说按分完的个数结钱。）", "emotion": "认命"},
		],
	},
}


static func examine(kind: String) -> Dictionary:
	return EXAMINES.get(kind, {})
