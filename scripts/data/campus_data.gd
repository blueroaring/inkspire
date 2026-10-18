class_name CampusData
extends RefCounted
## 大学校园的分区数据（纯数据 + 纯函数，不碰节点）。
##
## 2026-09-19 二次大改，按用户要求重做：
##   ① **分场景放楼**（"可以不都放在同一个场景中，可以切换场景放下所有的楼"）
##   ② **降低密度**（8 栋楼塞一张图太挤）
##   ③ **多加点 NPC**
##   ④ **路的尽头用校门来表示尽头**
##
## 分区拓扑（每区都是 48x34 逻辑格 —— 尺寸与旧版一致，所以相机/边界/图块逻辑一行都不用改）：
##
##   college.campus           生活区：宿舍楼 + 食堂（**正对面**，用户唯一硬性要求）
##                                      + 教育超市 + 照相馆·复印店 + 南校门
##   college.campus_teaching  教学区：教学楼 + 图书馆 + 校医院 + 北校门（牌坊）
##   college.campus_sports    运动区：体育馆 + 操场（跑道环 + 内场）+ 南校门
##
## 区间连接：**摆在路的尽头**，走过去就换区（SceneDoor）：
##   生活区 东端(y=10..11) ⇄ 教学区 西端(y=10..11)
##   教学区 南端(x=24..25) ⇄ 运动区 北端(x=24..25)
## 对外边界：路的断头处立**校门**（只看不能过）—— 用户要求"路的尽头用校门来表示尽头"。
##
## ⚠️ 校门美术**尚未生成**：现在用墙砖搭出"两根柱子 + 横梁 + 空白匾额"的结构，
##    `gates` 里那份数据同时喂给结构生成与查看交互，将来换成整件精灵只改 scene 脚本一处。
##
## ------------------------------------------------------------------ 字段说明
##
##    buildings  [{id,label,tiles,texture}]                     建筑整件精灵
##    roads      [{tiles,material,kind}]                        kind: road=车行 walk=人行道
##    plazas     [Rect2i]                                       交叉口 4x4 视觉覆盖区（底层可行走）
##    playground Rect2i（可为空）                                操场：跑道环 + 内场
##    gates      [{tile,size,label,lines}]                      校门（路的尽头，只能看）
##    links      [{tile,size,label,prompt,target_location,target_spawn}]  区间门
##    green_lines/green_spots/npcs                              绿化排布 / 定点绿化 / NPC

const ZONE_LIFE := "life"
const ZONE_TEACHING := "teaching"
const ZONE_SPORTS := "sports"

const ZONE_IDS: Array[String] = [ZONE_LIFE, ZONE_TEACHING, ZONE_SPORTS]

## 每位校园 NPC 的专属四方向角色表。资源不存在时场景仍会回退到占位视觉。
const NPC_MODELS := {
	"canteen_queue_1": "res://assets/graphics/characters/generated/canteen_queue_1_walk/processed/sheet-transparent.png",
	"canteen_queue_2": "res://assets/graphics/characters/generated/canteen_queue_2_walk/processed/sheet-transparent.png",
	"supermarket_shopper": "res://assets/graphics/characters/generated/supermarket_aunt_walk/processed/sheet-transparent.png",
	"photo_customer": "res://assets/graphics/characters/generated/photo_customer_walk/processed/sheet-transparent.png",
	"dorm_neighbor": "res://assets/graphics/characters/generated/dorm_neighbor_walk/processed/sheet-transparent.png",
	"gate_guard": "res://assets/graphics/characters/generated/gate_guard_walk/processed/sheet-transparent.png",
	"teaching_student_1": "res://assets/graphics/characters/generated/teaching_student_walk/processed/sheet-transparent.png",
	"library_reader_1": "res://assets/graphics/characters/generated/library_reader_walk/processed/sheet-transparent.png",
	"library_reader_2": "res://assets/graphics/characters/generated/library_borrower_walk/processed/sheet-transparent.png",
	"clinic_nurse": "res://assets/graphics/characters/generated/clinic_student_walk/processed/sheet-transparent.png",
	"field_runner_1": "res://assets/graphics/characters/generated/athlete_male_walk/processed/sheet-transparent.png",
	"field_runner_2": "res://assets/graphics/characters/generated/athlete_female_walk/processed/sheet-transparent.png",
	"gym_player": "res://assets/graphics/characters/generated/gym_player_walk/processed/sheet-transparent.png",
	"field_walker": "res://assets/graphics/characters/generated/field_walker_walk/processed/sheet-transparent.png",
}

## 分区 -> 场景地点 id
const ZONE_LOCATIONS := {
	ZONE_LIFE: "college.campus",
	ZONE_TEACHING: "college.campus_teaching",
	ZONE_SPORTS: "college.campus_sports",
}

## ---------------------------------------------------------------- 建筑美术
const CANTEEN_TEXTURE := "res://assets/graphics/props/campus_canteen/processed/clean.png"
const SUPERMARKET_TEXTURE := "res://assets/graphics/props/campus_supermarket/processed/clean.png"
const TEACHING_TEXTURE := "res://assets/graphics/props/campus_teaching/processed/clean.png"
const DORM_TEXTURE := "res://assets/graphics/props/campus_dorm/processed/clean.png"
const LIBRARY_TEXTURE := "res://assets/graphics/props/campus_library/processed/clean.png"
const PHOTO_TEXTURE := "res://assets/graphics/props/campus_photo_copy/processed/clean.png"
const CLINIC_TEXTURE := "res://assets/graphics/props/campus_clinic/processed/clean.png"
const GYM_TEXTURE := "res://assets/graphics/props/campus_gym/processed/clean.png"

## 绿化素材目录（craftpix 免费包，已拷进项目）
const FLORA_DIR := "res://assets/graphics/props/campus_flora/"

## 校门美术（2026-09-19 用户出图）。没有这张图时 `_build_gate()` 会退回"墙砖搭结构"的老做法。
const GATE_MAIN_TEXTURE := "res://assets/graphics/props/campus_gate_main/processed/clean.png"
const GATE_ARCH_TEXTURE := "res://assets/graphics/props/campus_gate_arch/processed/clean.png"

## 校园街具（路灯 / 长椅 / 垃圾桶 / 自行车 / 停车架…）。
## 结构与绿化同源：占地逻辑格 + 落地碰撞 + 素材文件。
## ⚠️ 占地要**覆盖到素材的宽高比**：路灯素材是"细杆 + 伸出的灯臂"，给太窄的占地会被缩得很矮。
##
## 2026-09-19 第二批（用户按 07_CAMPUS_PROP_PROMPTS 的优先级 1 出图：长椅/垃圾桶/自行车/停车架）：
##   · 素材是不透明品红底 → 先过 `tools/normalize_campus_props.py` 抠底 + 缩到占地像素，
##     产物在 `<id>/processed/clean.png`（游戏只认这个路径）；
##   · "solid" 是**落地那一小块**，不是整张图：长椅只有椅子腿、垃圾桶只有桶底，
##     按整张图挡人会变成空气墙（路灯那次已经踩过）。
const PROP_KINDS := {
	"lamp": {
		"file": "campus_lamp/processed/clean.png",
		"tiles": Vector2i(2, 2),
		# 碰撞只挡灯杆底座：灯臂是悬空的，不该变成空气墙
		"solid": Rect2(0.30, 0.44, 0.40, 0.54),
		"label": "路灯",
	},
	# 长椅：60x48 的图缩进 3x2 格（96x64），可见内容在底部中间 → 只挡椅子腿那一条
	"bench": {
		"file": "campus_bench/processed/clean.png",
		"tiles": Vector2i(3, 2),
		"solid": Rect2(0.06, 0.66, 0.88, 0.30),
		"label": "长椅",
	},
	"bin": {
		"file": "campus_bin/processed/clean.png",
		"tiles": Vector2i(2, 2),
		"solid": Rect2(0.20, 0.46, 0.60, 0.48),
		"label": "分类垃圾桶",
	},
	"bike": {
		"file": "campus_bike/processed/clean.png",
		"tiles": Vector2i(2, 2),
		"solid": Rect2(0.18, 0.44, 0.64, 0.50),
		"label": "自行车",
	},
	# 停车架 + 共享单车排：占地从 6x3 缩到 **4x2 格**（用户实报"黄色自行车模型太大、挡住 npc"）。
	# 素材也跟着缩到 64x32（见 tools/normalize_campus_props.py）。
	# ⚠️ 这件是"三辆并排"的宽图，缩放倍率由宽度决定 —— 占地给多宽，车就有多大，
	#    所以"太大"要在这里改，不是调 collision。
	"bike_rack": {
		"file": "campus_bike_rack/processed/clean.png",
		"tiles": Vector2i(4, 2),
		"solid": Rect2(0.04, 0.58, 0.92, 0.38),
		"label": "停车架",
	},
	# ⚠️ 操场器材三件（球门/篮球架/单双杠）：2026-09-19 第三批终于拿到了**真器材图**
	#    （早前误把同名目录当成器材接进来，里面装的其实是宿舍家具，操场上摆出了床和椅子）。
	"goal": {
		"file": "field_goal/processed/clean.png",
		"tiles": Vector2i(6, 2),
		# 球门只有两根立柱落地：挡人只挡立柱那一条
		"solid": Rect2(0.04, 0.62, 0.92, 0.38),
		"label": "足球门",
	},
	"hoop": {
		"file": "field_hoop/processed/clean.png",
		"tiles": Vector2i(2, 4),
		"solid": Rect2(0.28, 0.70, 0.44, 0.30),
		"label": "篮球架",
	},
	"bars": {
		"file": "field_bars/processed/clean.png",
		"tiles": Vector2i(3, 3),
		"solid": Rect2(0.06, 0.58, 0.88, 0.42),
		"label": "单双杠",
	},
	"pingpong": {
		"file": "field_pingpong/processed/clean.png",
		"tiles": Vector2i(3, 2),
		"solid": Rect2(0.04, 0.50, 0.92, 0.50),
		"label": "乒乓球台",
	},
	"bleachers": {
		"file": "field_bleachers/processed/clean.png",
		"tiles": Vector2i(10, 4),
		"solid": Rect2(0.02, 0.52, 0.96, 0.48),
		"label": "看台",
	},
	"field_light": {
		"file": "field_light/processed/clean.png",
		"tiles": Vector2i(2, 6),
		"solid": Rect2(0.30, 0.74, 0.40, 0.26),
		"label": "高杆灯",
	},
	"sandpit": {
		"file": "field_sandpit/processed/clean.png",
		# 沙坑是"平铺在地上"的一条：素材比例 3.6:1（很扁）。
		# ⚠️ 占地给 6x2 格会出问题：`place_prop` 会按**较紧的那条边**缩放，
		#    2 格高（32px）反而把这条 3.6:1 的图撑成 12x4 图块格 → 比占地上沿还高，溢出到操场外。
		#    给 6x1（宽而扁）才对得上素材比例。
		"tiles": Vector2i(6, 1),
		"solid": Rect2(0.04, 0.30, 0.92, 0.70),
		"label": "跳远沙坑",
	},
	"fence": {
		"file": "field_fence/processed/clean.png",
		"tiles": Vector2i(2, 2),
		"solid": Rect2(0.06, 0.40, 0.88, 0.60),
		"label": "球场围网",
	},
	"scoreboard": {
		"file": "field_scoreboard/processed/clean.png",
		"tiles": Vector2i(3, 3),
		"solid": Rect2(0.10, 0.72, 0.80, 0.28),
		"label": "记分牌",
	},
	# ---- 校园杂物（07 的优先级 3）----
	"parcel_locker": {
		"file": "campus_parcel_locker/processed/clean.png",
		"tiles": Vector2i(4, 3),
		"solid": Rect2(0.04, 0.62, 0.92, 0.38),
		"label": "快递柜",
	},
	"vending": {
		"file": "campus_vending/processed/clean.png",
		"tiles": Vector2i(2, 3),
		"solid": Rect2(0.08, 0.70, 0.84, 0.30),
		"label": "自动售货机",
	},
	"water": {
		"file": "campus_water/processed/clean.png",
		"tiles": Vector2i(2, 2),
		"solid": Rect2(0.12, 0.56, 0.76, 0.44),
		"label": "直饮水台",
	},
	"notice": {
		"file": "campus_notice/processed/clean.png",
		"tiles": Vector2i(4, 3),
		"solid": Rect2(0.06, 0.70, 0.88, 0.30),
		"label": "公告栏",
	},
	"signpost": {
		"file": "campus_signpost/processed/clean.png",
		"tiles": Vector2i(2, 4),
		"solid": Rect2(0.30, 0.76, 0.40, 0.24),
		"label": "指示牌",
	},
	"mapboard": {
		"file": "campus_mapboard/processed/clean.png",
		"tiles": Vector2i(4, 3),
		"solid": Rect2(0.06, 0.70, 0.88, 0.30),
		"label": "校园导览图",
	},
	"flagpole": {
		"file": "campus_flagpole/processed/clean.png",
		"tiles": Vector2i(2, 6),
		"solid": Rect2(0.10, 0.78, 0.80, 0.22),
		"label": "国旗杆",
	},
	"statue": {
		"file": "campus_statue/processed/clean.png",
		"tiles": Vector2i(3, 3),
		"solid": Rect2(0.14, 0.62, 0.72, 0.38),
		"label": "雕塑",
	},
	"banner": {
		"file": "campus_banner/processed/clean.png",
		"tiles": Vector2i(4, 2),
		# 横幅是挂在墙上的，本身不该挡人；留一点点让人知道那儿有东西
		"solid": Rect2(0.10, 0.50, 0.80, 0.26),
		"label": "横幅",
	},
	"bike_shed": {
		"file": "campus_bike_shed/processed/clean.png",
		"tiles": Vector2i(8, 4),
		# 车棚是开敞的：只挡后墙与立柱那一条，别把整个棚子封死
		"solid": Rect2(0.04, 0.62, 0.92, 0.34),
		"label": "自行车棚",
	},
}

## 图块材质（与 tools/build_tileset.gd 的 floor terrain 下标一致）
const FLOOR_STONE := 0
const FLOOR_TILE_CREAM := 2
const FLOOR_TILE_CYAN := 3
const FLOOR_BRICK_RED := 4
const FLOOR_ASPHALT := 5
const FLOOR_STONE_DARK := 6
const FLOOR_BRICK_DARK := 7

## 墙材质（仅在校门结构里用）
const WALL_BRICK := 1
const WALL_STONE := 2
const WALL_DARK := 3


# ================================================================== 分区数据


static func zone(id: String) -> Dictionary:
	var raw := {}
	match id:
		ZONE_LIFE:
			raw = _zone_life()
		ZONE_TEACHING:
			raw = _zone_teaching()
		ZONE_SPORTS:
			raw = _zone_sports()
	if raw.is_empty():
		return raw
	# 路口由**路网算出**，不手写（见 `plazas_for` 的说明：手写必然偏 1 格）
	raw["plazas"] = plazas_for(raw)
	return raw


## "她真的登场了"这条门槛，校园里所有"她入队那一段"的改写都用它。
##
## ------------------------------------------------------------------ 为什么使用 `STORY_ALYINA_MET`
##
## 用户 2026-09-20 连报两条："和校医院门口的同学说话**提早出现了**艾莉娜对话"、
## "和还书的同学说话也**提前出现**了艾莉娜对话"。
## 根因：`STORY_ALYINA_FOLLOWS` 只表示"她已经跟着你了"，而玩家**上课之前**
## 就能在教学区、运动区、生活区自由逛 —— 那时候她还没登场，可她的话已经接上了。
## （演出顺序是：食堂 → 看手机 → 进教学楼 → 301 门口那场戏写 `STORY_SKIPPED_CLASS`
##   → 下楼出楼才触发登场 CG 写 `STORY_ALYINA_FOLLOWS`。）
##
## `STORY_SKIPPED_CLASS` 只代表"课不上了"，发生在登场 CG 之前；必须等 CG 完成后
## 登场 CG 完成后会写入 `STORY_ALYINA_MET`，才能换成包含艾莉娜的后续台词。
## 但在"上课之前乱逛"这条路上只有前者仍为假 —— 提前出现的 bug 正是从这个缝里钻出来的。
##
## ⚠️ 新增"她入队那一段"的改写时，一律调用这个函数，不要直接写任务阶段开关。
static func she_joined_flag() -> String:
	return TeachingData.STORY_ALYINA_MET


## 校园夜间统一判据：跟环境光、路灯和 HUD 使用同一套时段划分。
## 不读 `GameState.phase`，因为它是剧情状态，不一定和当前时钟同步。
static func is_night() -> bool:
	return Daylight.period_at(GameState.in_game_minutes) == Daylight.PERIOD_NIGHT


static func zone_label(id: String) -> String:
	match id:
		ZONE_LIFE:
			return "生活区"
		ZONE_TEACHING:
			return "教学区"
		ZONE_SPORTS:
			return "运动区"
	return "校园"


static func location_of(zone_id: String) -> String:
	return String(ZONE_LOCATIONS.get(zone_id, "college.campus"))


## 世界尺寸：三个区一致（48x34 逻辑格 = 1536x1088px）
static func zone_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Grid.size_to_px(Grid.CAMPUS_SIZE))


static func zone_cells() -> Rect2i:
	return Grid.rect_to_cells(zone_rect())


static func playground_track_width_cells() -> int:
	return 4


# ---------------------------------------------------------------- 生活区


static func _zone_life() -> Dictionary:
	return {
		"id": ZONE_LIFE,
		"label": "生活区",
		"buildings": [
			_b("canteen", "第一食堂", Vector2i(3, 4), Vector2i(10, 6), CANTEEN_TEXTURE),
			_b("dorm_building", "学生宿舍", Vector2i(3, 13), Vector2i(9, 6), DORM_TEXTURE),
			_b("supermarket", "教育超市", Vector2i(18, 4), Vector2i(6, 6), SUPERMARKET_TEXTURE),
			_b("photo_copy", "照相馆 · 复印店", Vector2i(17, 13), Vector2i(7, 4), PHOTO_TEXTURE),
		],
		"roads": [
			_r(Vector2i(2, 10), Vector2i(44, 2), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 12), Vector2i(44, 1), FLOOR_STONE, "walk"),
			_r(Vector2i(24, 2), Vector2i(2, 27), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 19), Vector2i(44, 1), FLOOR_STONE, "walk"),
			_r(Vector2i(2, 20), Vector2i(44, 2), FLOOR_ASPHALT, "road"),
		],
		# ⚠️ 路口不在这里写：由 `plazas_for()` 按路网算（见那个函数的说明）
		"playground": Rect2i(),
		"gates": [
			# 台词照 `request/08_DIALOG.md`（"看校门（南）对话"）：闸门关着、得请门卫开门，
			# 而主角今天不打算出去（一会要上课）。
			_gate(Vector2i(21, 29), Vector2i(8, 4), "校门（南）", GATE_MAIN_TEXTURE, [
				{"speaker": "",
					"text": "学校的南门。两根砖柱上各顶着一盏圆灯，铁栅栏门关着，得请门卫大爷开门。"},
				{"speaker": "周明远", "text": "今天就先不出校门了吧，一会要上课。", "emotion": "摆手"},
			], {
				"morning_lines": [
					{"speaker": "", "text": "这个门离你的高中不如运动场的门近。"},
					{"speaker": "周明远", "text": "和艾莉娜约好的不是这个门。"},
				],
				# 08 定稿（艾莉娜入队那一段）：**看校门（南）那几句整体改写**
				# ⚠️ 门槛是艾莉娜登场 CG 完成后的 `she_joined_flag()`。
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "艾莉娜", "text": "这里有门卫大爷唉！好可怕！", "emotion": "害怕"},
					{"speaker": "周明远", "text": "为什么会觉得门卫大爷可怕呢？", "emotion": "疑惑"},
					{"speaker": "艾莉娜", "text": "因为门卫大爷不应该都是会抓逃课的学生的吗？", "emotion": "认真"},
					{"speaker": "周明远", "text": "大学哪里有人管你逃不逃课唉。又不是高中。", "emotion": "无奈"},
					{"speaker": "艾莉娜", "text": "原来如此！那大学的门卫大爷是好人喽！", "emotion": "恍然"},
					{"speaker": "周明远", "text": "算是吧，我这几年都和大爷混个眼熟面熟了。", "emotion": "熟络"},
				],
			}),
		],
		"prop_lines": [
			# 路灯：**摆到人行道上**（主路南侧 y=12 / 次路北侧 y=19），再沿中央轴两侧补几根。
			# 人行道在街具的判空里是允许的（见 blocked_cells_for_props），
			# 所以不会像上一版那样只能挤在楼间缝与草坪中间（用户反馈"路灯位置不太对"）。
			{"kind": "lamp", "axis": "x", "at": 12, "from": 7, "to": 43, "step": 15},
			{"kind": "lamp", "axis": "x", "at": 19, "from": 7, "to": 43, "step": 15},
			{"kind": "lamp", "axis": "y", "at": 23, "from": 22, "to": 28, "step": 5},
		],
		# 街具定点（2026-09-19 第二批）：长椅/垃圾桶/自行车/停车架。
		# ⚠️ 这些坐标**不是随手写的**：先用 `tools/list_free_prop_cells.gd` 把"底座那一格是空的、
		#    且落在人行道/广场上"的候选格算出来，再照着填 —— 手猜很容易踩到绿化/路灯的占位，
		#    而 `props()` 遇到被占的格子是**静默跳过**的（数据里写了、图上没有）。
		"prop_spots": [
			# 长椅：宿舍楼门口、食堂门口、南校门内
			{"kind": "bench", "tile": Vector2i(22, 22)},
			{"kind": "bench", "tile": Vector2i(40, 15)},
			{"kind": "bench", "tile": Vector2i(20, 19)},
			{"kind": "bench", "tile": Vector2i(44, 15)},
			# 垃圾桶：食堂门口、超市门口
			{"kind": "bin", "tile": Vector2i(35, 15)},
			{"kind": "bin", "tile": Vector2i(26, 22)},
			{"kind": "bin", "tile": Vector2i(15, 15)},
			# 自行车：宿舍楼下零散停
			{"kind": "bike", "tile": Vector2i(18, 22)},
			# 停车架：宿舍楼门口 / 复印店门口（"停车架+共享单车排"是一整件）
			{"kind": "bike_rack", "tile": Vector2i(10, 22)},
			# ---- 优先级 3 的校园杂物（2026-09-19 第三批）----
			# ⚠️ 两条硬约束（用户实报"太密了""堆叠在一起"）：
			#   ① 街具的锚点在**贴图底边**且参与 y 排序 → 高物件站在 NPC 南边会把人整个盖住；
			#   ② 别在每一片草地上都塞东西 —— 拉开间距、留白比铺满好看。
			# 坐标取自 tools/list_free_prop_cells.gd（`-- --any` 看"哪里空"），间距 ≥5 格。
			{"kind": "parcel_locker", "tile": Vector2i(26, 15)},    # 快递柜（宿舍楼东侧草坪）
			{"kind": "notice", "tile": Vector2i(38, 15)},           # 公告栏
			{"kind": "banner", "tile": Vector2i(38, 22)},           # 横幅（挂墙前）
			{"kind": "vending", "tile": Vector2i(4, 22)},           # 售货机（食堂背面）
			{"kind": "signpost", "tile": Vector2i(6, 22)},          # 宿舍楼下路口指示牌
		],
		"links": [
			_door(Vector2i(44, 10), Vector2i(2, 2), "东门 · 往教学区", "往教学区走",
					"college.campus_teaching", "from_life"),
		],
		"green_lines": [
			{"axis": "x", "at": 3, "from": 4, "to": 43, "step": 8,
					"kinds": ["tree_big", "tree_flower", "tree_dark"]},
			{"axis": "x", "at": 2, "from": 6, "to": 42, "step": 8, "kind": "bush_pink"},
			{"axis": "x", "at": 17, "from": 26, "to": 43, "step": 7, "kind": "bush_blue"},
			{"axis": "x", "at": 23, "from": 3, "to": 20, "step": 7, "kind": "bush_orange"},
			{"axis": "y", "at": 45, "from": 5, "to": 17, "step": 6, "kind": "tree_small2"},
			{"axis": "y", "at": 28, "from": 5, "to": 9, "step": 3, "kind": "bush_plain"},
		],
		"green_spots": [
			{"kind": "bush_orange", "tile": Vector2i(5, 9)}, {"kind": "bush_orange", "tile": Vector2i(11, 9)},
			{"kind": "bush_blue", "tile": Vector2i(5, 12)}, {"kind": "bush_blue", "tile": Vector2i(11, 12)},
			{"kind": "rock", "tile": Vector2i(22, 13)}, {"kind": "bush_pink", "tile": Vector2i(27, 13)},
			{"kind": "palm", "tile": Vector2i(45, 3)}, {"kind": "tree_autumn", "tile": Vector2i(28, 3)},
		],
		"npcs": [
			# 08 定稿：这位是"**刚从食堂出来**的同学"（原来写的是"排队的同学"）。
			# 台词照 08 原文（她得是**出来**的人，才能回答"里面人多吗"）。
			#
			# ⚠️ id / 显示名都**保持原样**（`canteen_queue_1` / "排队的同学"）：
			#    用户在 `data/layout_patch.json` 里手动挪过这个 NPC，
			#    补丁是按 **id** 点名的（`life|npc:0|canteen_queue_1@26,2`）——
			#    改 id 会让那条移位变成"要移位的 id 不存在"，她就被弹回生成期坐标
			#    （实测：改完之后自检里立刻多一条 `LayoutPatch[life]: 要移位的 id 不存在`）。
			#    要做"真的改名"得同时改补丁并让用户确认，先不动。
			# ⚠️ 她**只在第一次进校园时出现**（用户 2026-09-20：
			#    "离开食堂后食堂排队的同学 npc 应该删除"）：`canteen_visited` 在**进食堂那一刻**
			#    写上，于是"从食堂出来再回生活区"她就不在了。
			#    用的是校园 NPC 那套 `vanish_after`（一次性开关 + 不再生成，见
			#    `campus.gd::_wire_vanish()`）；她的台词是一次性的"问食堂人多不多"，
			#    所以走的时候不用再补旁白（`vanish_line` 留空）。
			#    ⚠️ 调用方（`vanish_after` 非空）在**交互之后**会把她收掉 —— 但那要等玩家
			#    真的问过她；"进过食堂"这条判据是**进场景**就成立，所以两条路都覆盖到了。
			_npc("canteen_queue_1", "排队的同学", Vector2i(26, 2), Vector2i(0, 1), [
				{"speaker": "周明远", "text": "食堂里人多吗？", "emotion": "试探"},
				{"speaker": "排队的同学", "text": "还好，现在羊肉面窗口人最少。", "emotion": "随口"},
			], {
				"vanish_after": "canteen_visited",
				"morning_visible": false,
			}),
			_npc("canteen_queue_2", "端着饭盒的同学", Vector2i(28, 2), Vector2i(0, 1), [
				{"speaker": "端着饭盒的同学", "text": "别排了，一楼窗口只剩土豆丝了。", "emotion": "惨笑"},
				{"speaker": "周明远", "text": "……那也比我宿舍那包泡面强。", "emotion": "自嘲"},
			]),
			# 08 定稿：由"买文具的同学"改为"**在超市外促销的阿姨**"
			_npc("supermarket_shopper", "促销的阿姨", Vector2i(20, 10), Vector2i(0, 1), [
				{"speaker": "促销的阿姨",
					"text": "今天抽纸促销！买一送一！买两扎以上赠送额外小礼品！",
					"emotion": "吆喝"},
			], {
				"night_visible": true,
				"night_lines": [
					{"speaker": "促销的阿姨", "text": "超市要关门了，要买东西的抓紧买东西。", "emotion": "催促"},
				],
			}),
			# 08 定稿（艾莉娜入队那一段）："**艾莉娜加入后删除取复印件的 Npc**"
			#    —— 所以他的 `vanish_also_after` 挂在"她已入队"上，
			#    进这一区时直接不再生成（不是"玩家还得先问他一句"）。
			_npc("photo_customer", "取复印件的同学", Vector2i(20, 17), Vector2i(0, -1), [
				{"speaker": "周明远", "text": "呦，中午好！这是来取什么？", "emotion": "打招呼"},
				{"speaker": "取复印件的同学", "text": "（指着拿着的一大摞）毕业论文。", "emotion": "平静"},
				{"speaker": "周明远（内心）", "text": "怎么大家毕业论文都写完了……", "emotion": "沮丧"},
			], {
				"vanish_after": "",
				"vanish_also_after": [TeachingData.STORY_SKIPPED_CLASS],
			}),
			# 08 定稿（艾莉娜入队那一段）："和同层的同学说话此事改成**不认识的同宿舍楼同学**"
			#    —— 她入队后这个 NPC 还在场，但主角不认识他、也就没必要搭话：
			#    台词整体换成一句旁白，**名字也跟着换**（`name_after`：
			#    白天/上课前还是"同层的同学"，那之后才是"同宿舍楼的同学"）。
			#    ⚠️ 用户 2026-09-20 实报："和同宿舍楼的同学说话也改早了，白天应该是同层的同学"
			#       —— 点名要改的地方就是**名字**：只换台词不换名字，白天撞见他就成了
			#       "一个我根本不认识的人却报着'同层'的名号"。
			_npc("dorm_neighbor", "同层的同学", Vector2i(12, 22), Vector2i(0, 1), [
				{"speaker": "同层的同学", "text": "三楼水房的热水器又坏了，我下来打水。", "emotion": "无奈"},
				{"speaker": "同层的同学", "text": "你们寝室那个考研的，今早六点就出门了。", "emotion": "佩服"},
			], {
				"rewrite_after": she_joined_flag(),
				"name_after": "同宿舍楼的同学",
				"lines_after": [
					{"speaker": "", "text": "你并不认识这位同学，因此也没有什么必要打招呼。"},
				],
			}),
			# 门卫大爷：08 的台词 + 用户"位置改一下，目前比较难触发对话"。
			# ⚠️ 他从 (26,26) 挪到 **(24,27)**（南门内的人行道上、主路边）：
			#    原来那格在广场角落里，玩家沿主路走不会经过 —— 现在贴着校门内的必经之路。
			# ⚠️ 08 后来把这段**整体改写**成"大爷：出门记得别丢东西。"（艾莉娜入队那一段），
			#    所以同样走 `rewrite_after`：她入队之后是这一句，之前还是原来那两句。
			_npc("gate_guard", "门卫大爷", Vector2i(24, 27), Vector2i(0, -1), [
				{"speaker": "门卫大爷", "text": "出门吃饭？记得贵重物品别丢了。", "emotion": "例行公事"},
				{"speaker": "周明远", "text": "我就过来看看，不出去。", "emotion": "摆手"},
			], {
				"rewrite_after": she_joined_flag(),
				"morning_lines": [
					{"speaker": "门卫大爷", "text": "出门注意安全。", "emotion": "叮嘱"},
				],
				"lines_after": [
					{"speaker": "门卫大爷", "text": "出门记得别丢东西。", "emotion": "叮嘱"},
				],
				"night_visible": true,
				"night_lines": [
					{"speaker": "门卫大爷", "text": "晚上了，别出门了，注意安全。", "emotion": "叮嘱"},
				],
			}),
		],
		# ---- 经济系统（2026-09-19）：**商店在街上，打工在食堂里面** ----
		# 用户 2026-09-19 明确要求："把食堂打工作为进入食堂场景后可以选择的小游戏"，
		# 所以食堂那个工位从街上搬进了 `college.canteen` 场景（见 CanteenData.works()），
		# 这里只剩**商店**入口（楼体是整块碰撞，交互区必须摆在门前人行道上）。
		"jobs": [],
		"shops": [
			{"id": "supermarket", "shop_id": "campus_supermarket", "tile": Vector2i(21, 12)},
			{"id": "photo_copy", "shop_id": "campus_photo", "tile": Vector2i(21, 19)},
		],
	}


# ---------------------------------------------------------------- 教学区

static func _zone_teaching() -> Dictionary:
	return {
		"id": ZONE_TEACHING,
		"label": "教学区",
		"buildings": [
			_b("teaching", "教学楼", Vector2i(3, 4), Vector2i(14, 6), TEACHING_TEXTURE),
			_b("clinic", "校医院", Vector2i(36, 4), Vector2i(8, 6), CLINIC_TEXTURE),
			_b("library", "图书馆", Vector2i(4, 18), Vector2i(10, 6), LIBRARY_TEXTURE),
		],
		"roads": [
			_r(Vector2i(2, 10), Vector2i(44, 2), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 12), Vector2i(44, 1), FLOOR_STONE, "walk"),
			_r(Vector2i(24, 4), Vector2i(2, 29), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 24), Vector2i(44, 1), FLOOR_STONE, "walk"),
			_r(Vector2i(2, 25), Vector2i(44, 2), FLOOR_ASPHALT, "road"),
		],
		# ⚠️ 路口不在这里写：由 `plazas_for()` 按路网算（见那个函数的说明）
		"playground": Rect2i(),
		"gates": [
			_gate(Vector2i(22, 1), Vector2i(5, 3), "校门（北）· 牌坊", GATE_ARCH_TEXTURE, [
				{"speaker": "", "text": "北门。牌坊的瓦檐上落着一层灰，匾额是空白的，铁门半掩着。"},
				{"speaker": "周明远", "text": "（大一报到那天，就是从这道门进来的。）", "emotion": "怀念"},
			]),
		],
		"prop_lines": [
			{"kind": "lamp", "axis": "x", "at": 12, "from": 7, "to": 43, "step": 15},
			{"kind": "lamp", "axis": "x", "at": 24, "from": 7, "to": 43, "step": 15},
			{"kind": "lamp", "axis": "y", "at": 23, "from": 12, "to": 22, "step": 5},
		],
		"prop_spots": [
			# 教学楼门口 / 图书馆门口 / 校医院门口（坐标取自 tools/list_free_prop_cells.gd 的可用格清单）
			{"kind": "bench", "tile": Vector2i(2, 12)},
			{"kind": "bench", "tile": Vector2i(32, 12)},
			{"kind": "bench", "tile": Vector2i(30, 12)},
			# 垃圾桶：教学楼门口、图书馆门口、北门内
			{"kind": "bin", "tile": Vector2i(40, 12)},
			# 自行车 + 停车架：教学楼旁（学生骑车上课）
			{"kind": "bike", "tile": Vector2i(42, 12)},
			{"kind": "bike_rack", "tile": Vector2i(20, 12)},
			{"kind": "bike_rack", "tile": Vector2i(44, 12)},
			# ---- 优先级 3：教学区（中轴广场 + 门口），间距拉开 ----
			{"kind": "flagpole", "tile": Vector2i(21, 15)},         # 中轴国旗杆
			{"kind": "statue", "tile": Vector2i(28, 15)},           # 雕塑（中轴东侧）
			{"kind": "mapboard", "tile": Vector2i(28, 12)},         # 西门内导览图
			{"kind": "banner", "tile": Vector2i(40, 24)},           # 横幅
			{"kind": "notice", "tile": Vector2i(30, 24)},            # 图书馆门口公告栏
			{"kind": "water", "tile": Vector2i(36, 24)},            # 直饮水台
		],
		"links": [
			_door(Vector2i(2, 10), Vector2i(2, 2), "西门 · 往生活区", "往生活区走",
					"college.campus", "from_teaching"),
			_door(Vector2i(24, 31), Vector2i(2, 2), "南门 · 往运动区", "往运动区走",
					"college.campus_sports", "from_teaching"),
		],
		"green_lines": [
			{"axis": "x", "at": 3, "from": 20, "to": 43, "step": 7,
					"kinds": ["tree_dark", "tree_flower", "tree_big"]},
			{"axis": "x", "at": 2, "from": 22, "to": 42, "step": 9, "kind": "bush_pink"},
			{"axis": "y", "at": 30, "from": 4, "to": 9, "step": 3, "kind": "bush_orange"},
			{"axis": "y", "at": 33, "from": 13, "to": 22, "step": 4, "kind": "bush_blue"},
			{"axis": "x", "at": 14, "from": 3, "to": 15, "step": 6, "kind": "bush_plain"},
			{"axis": "x", "at": 22, "from": 30, "to": 43, "step": 6, "kind": "bush_pink"},
		],
		"green_spots": [
			# 大草坪（轴线以东那片留白）—— 教学区的"空"就是它的气质
			{"kind": "tree_big", "tile": Vector2i(34, 15)}, {"kind": "tree_flower", "tile": Vector2i(40, 20)},
			{"kind": "rock", "tile": Vector2i(31, 18)}, {"kind": "rock2", "tile": Vector2i(43, 15)},
			{"kind": "bush_orange", "tile": Vector2i(35, 21)}, {"kind": "bush_pink", "tile": Vector2i(29, 22)},
			{"kind": "tree_autumn", "tile": Vector2i(45, 5)}, {"kind": "palm", "tile": Vector2i(19, 3)},
		],
		"npcs": [
			# 08 定稿：抱着课本的同学 = **一句话都不说，急匆匆进教学楼然后消失**。
			#   · `lines` 留空 = 对话为空（`Npc._talk()` 直接返回，不会弹一个空对话框）；
			#   · `vanish_line` 是走之前那句旁白；
			#   · `vanish_after` 同时当"一次性开关"用：拿过之后她不再出现。
			# ⚠️ 08 里紧跟着还有一句"周明远：这么早就去占座，真卷。"——
			#    它属于**她消失之后**的独白，所以放在 `vanish_line` 里由场景脚本补播。
			# ⚠️ **`vanish_also_after`：翘过课 = 也该走**（用户 2026-09-20：
			#    "和抱着课本的同学说话的 npc 不应该在艾莉娜加入后还在"）。
			#    她本来是"去占座的学生"，主角都上完课出来了（`skipped_thesis_class`），
			#    她还站在楼门口就不合逻辑了 —— 而且玩家这时正带着艾莉娜逛，
			#    一个早该进楼的人杵在那儿很出戏。
			#    所以除了"跟她说过话"之外，**进过教学楼/翘过课**也把她收掉。
			_npc("teaching_student_1", "抱着课本的同学", Vector2i(8, 11), Vector2i(0, -1), [], {
				"vanish_after": "teaching_student_gone",
				"vanish_also_after": [TeachingData.STORY_SKIPPED_CLASS],
				"vanish_line": [
					{"speaker": "", "text": "抱着课本的同学急匆匆地进入了教学楼。"},
					{"speaker": "周明远", "text": "这么早就去占座，真卷。", "emotion": "感叹"},
				],
			}),
			# 08："和抄板书的同学说话的 Npc 删除" —— 这一位整条删掉（她原来站在教学楼门口）。
			# ⚠️ 删除后**教学区的 NPC 从 5 个变成 4 个**：走查里"NPC 数量与数据一致"
			#    是按数据算的，所以数据删了它也跟着对。
			# 08 定稿：刚出图书馆的同学改成"我记得你，你昨天就坐在我对面…"
			# ⚠️ 第二段（`talk_order`）只在**食堂那一步做完之后**才轮得到
			#    （08："食堂完成前不应该能有进入教学楼的交互选项"）：
			#    在此之前他只是个路过的同学，不会主动提"两点那节课"。
			# 08 定稿（艾莉娜入队那一段）：**全部改写**（"刚出图书馆的同学(全部修改)"）
			#   "同学：哟 bro，又来图书馆了？/ 昨天看你一直到闭馆才离开。" ——
			#   而且这一段是**她入队之后**才轮到的（她要跟着一起夸主角勤奋）。
			# ⚠️ 用 `lines_after` 整体替换，不是 `talk_order` 追加：
			#    08 标的是"(全部修改)"，原来那两段（"我记得你…" / "两点那节…占座"）整段作废。
			#    判据是 `she_joined_flag()`（艾莉娜登场 CG 已完成）。
			_npc("library_reader_1", "刚出图书馆的同学", Vector2i(34, 21), Vector2i(0, 1), [
				{"speaker": "刚出图书馆的同学",
					"text": "我记得你，你昨天就坐在我对面，一直到图书馆闭馆才离开。", "emotion": "打量"},
				{"speaker": "周明远", "text": "我昨天那么用功吗？", "emotion": "意外"},
			], {
				"require_flag": QuestData.FLAG_ATE,
				"morning_visible": false,
				"talk_order": [[
					{"speaker": "刚出图书馆的同学",
						"text": "下午两点那节毕业论文写作，你还不去占座？", "emotion": "随口"},
					{"speaker": "周明远", "text": "……这就去。", "emotion": "心虚"},
				]],
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "刚出图书馆的同学", "text": "哟 bro，又来图书馆了？", "emotion": "熟络"},
					{"speaker": "刚出图书馆的同学", "text": "昨天看你一直到闭馆才离开。", "emotion": "感慨"},
					{"speaker": "艾莉娜", "text": "粥粥好勤奋！", "emotion": "佩服"},
					{"speaker": "周明远",
						"text": "都是被毕业论文 ddl 逼的，就这样我还愿意花时间陪你逛一个下午呢。",
						"emotion": "自嘲"},
					{"speaker": "艾莉娜", "text": "呜呜……好感动！粥粥最好了！", "emotion": "感动"},
				],
			}),
			# 08 定稿：还书的同学 —— 艾莉娜入队后接一段（"+"= 在原来的对话后加入）
			# 08 定稿：还书的同学 —— 她登场后接一段（"+"= 在原来的对话后加入）
			# ⚠️ 门槛是 `she_joined_flag()`（艾莉娜登场 CG 已完成）：
			#    写成"基座里直接带上她的话"会**提前出现** —— 玩家可以在上课之前
			#    就逛到图书馆，那时她还没登场（用户 2026-09-20 实报的正是这一类）。
			_npc("library_reader_2", "还书的同学", Vector2i(21, 24), Vector2i(0, -1), [
				{"speaker": "还书的同学", "text": "我一次借了八本，一本都没看完就到期了。", "emotion": "自嘲"},
			], {
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "还书的同学", "text": "我一次借了八本，一本都没看完就到期了。", "emotion": "自嘲"},
					{"speaker": "艾莉娜", "text": "粥粥在图书馆借过书吗？", "emotion": "好奇"},
					{"speaker": "周明远", "text": "我不借书，感觉不如手机上看柿子免费小说。", "emotion": "随口"},
					{"speaker": "艾莉娜", "text": "什么什么……柿子？小说？", "emotion": "疑惑"},
					{"speaker": "艾莉娜", "text": "我也要看小说！", "emotion": "兴奋"},
					{"speaker": "周明远（内心）", "text": "（但是你没法操作手机刷小说呀。）", "emotion": "无奈"},
				],
			}),
			# 08 定稿：校医院门口的同学 —— 她登场后接一段（门槛用 `she_joined_flag()`）
			_npc("clinic_nurse", "校医院门口的同学", Vector2i(26, 21), Vector2i(0, 1), [
				{"speaker": "周明远", "text": "你来校医院打点滴了？", "emotion": "意外"},
				{"speaker": "校医院门口的同学", "text": "对呀，感冒了，你也小心。", "emotion": "沙哑"},
				{"speaker": "周明远", "text": "还真是，再毕业论文熬几天估计我也要倒下了。", "emotion": "认命"},
			], {
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "周明远", "text": "你来校医院打点滴了？", "emotion": "意外"},
					{"speaker": "校医院门口的同学", "text": "对呀，感冒了，你也小心。", "emotion": "沙哑"},
					{"speaker": "周明远", "text": "还真是，再毕业论文熬几天估计我也要倒下了。", "emotion": "认命"},
					{"speaker": "艾莉娜", "text": "这个同学生病了，好可怜……粥粥千万不要生病呀！", "emotion": "担心"},
					{"speaker": "周明远", "text": "谢谢你的关心。我已经几乎一年没感冒过了。", "emotion": "安心"},
					{"speaker": "艾莉娜", "text": "哇！粥粥的体质真好！", "emotion": "惊叹"},
					{"speaker": "周明远", "text": "可能体育素质不是很好，但是抗病性是挺强的。", "emotion": "谦虚"},
				],
			}),
		],
		# 经济系统的商店/工位目前只在生活区（食堂 + 教育超市 + 复印店）——
		# 教学区、运动区暂时没有商店，所以这两项留空（留键是为了数据形状统一，
		# 将来在图书馆/体育馆门口加一家店只要往这里加一行）。
		"jobs": [],
		"shops": [],
	}


# ---------------------------------------------------------------- 运动区


static func _zone_sports() -> Dictionary:
	return {
		"id": ZONE_SPORTS,
		"label": "运动区",
		"buildings": [
			_b("gym", "体育馆", Vector2i(32, 12), Vector2i(10, 7), GYM_TEXTURE),
		],
		"roads": [
			_r(Vector2i(24, 2), Vector2i(2, 28), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 8), Vector2i(44, 2), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 10), Vector2i(44, 1), FLOOR_STONE, "walk"),
			_r(Vector2i(2, 28), Vector2i(44, 2), FLOOR_ASPHALT, "road"),
			_r(Vector2i(2, 27), Vector2i(44, 1), FLOOR_STONE, "walk"),
			# 从竖路往西接操场的一段人行道（操场西移到 x=4..19 之后照样接得上）
			_r(Vector2i(20, 11), Vector2i(4, 1), FLOOR_STONE, "walk"),
		],
		# ⚠️ 操场**必须和路留出草地边距**（2026-09-20 用户实报"操场右侧占据了道路"）。
		#    原来写 `Rect2i(4, 13, 20, 12)` = x 4..23，而竖路正好从 x=24 起：
		#    **右沿与路面零间距**（画面上跑道边缘直接贴到沥青上）。
		#    现在 x 4..21（宽 18）、y 13..24（高 12）：右边留 **2 格草地**、
		#    与上下两条路各留 3 格 —— 场地比原来小了 2 格宽，但跑道环仍是 2 格宽、
		#    内场 14x8 格，形状比例反而更像操场。
		#    ⚠️ 2026-09-20 用户又要求"操场再大一点"：当时为了留边距把它从 20 格宽收到 16，
		#       收过头了（跑道只剩 2 格宽、内场 12x8）；现在回到 18 格宽，
		#       边距仍够（2 格草地），是"够大"与"不贴路"之间的平衡点。
		"playground": Rect2i(4, 13, 18, 12),
		"gates": [
			_gate(Vector2i(21, 29), Vector2i(8, 4), "校门（南）· 运动场", GATE_MAIN_TEXTURE, [
				{"speaker": "", "text": "运动场这头的小门，铁栅栏锈了一半，门轴上挂着一把早就没锁的锁。"},
				{"speaker": "周明远", "text": "（从这里出去就是后街。以前夜跑完，我们会翻出去买烤串。）", "emotion": "怀念"},
			]),
		],
		"prop_lines": [
			{"kind": "lamp", "axis": "x", "at": 10, "from": 6, "to": 43, "step": 15},
			{"kind": "lamp", "axis": "x", "at": 27, "from": 6, "to": 43, "step": 15},
			{"kind": "lamp", "axis": "y", "at": 26, "from": 12, "to": 28, "step": 5},
		],
		"prop_spots": [
			# 街具定点：操场西侧与南门内（运动区最空，靠这几件撑起"有人来过"的生活感）
			# 坐标取自 tools/list_free_prop_cells.gd 的可用格清单。
			{"kind": "bench", "tile": Vector2i(44, 12)},
			{"kind": "bench", "tile": Vector2i(32, 10)},
			{"kind": "bench", "tile": Vector2i(22, 11)},
			{"kind": "bin", "tile": Vector2i(35, 10)},
			{"kind": "bin", "tile": Vector2i(2, 12)},
			{"kind": "bike", "tile": Vector2i(44, 22)},
			{"kind": "bike", "tile": Vector2i(30, 12)},
			# ---- 优先级 2：操场器材（2026-09-19 第三批）----
			# 场内器材：操场 = 逻辑格 Rect2i(4,13,18,12)，跑道外圈 4 格 + 内场。
			# ⚠️ 用户实报"操场的物件都放到道路上了，不在操场中" —— 场内器材必须落在这个范围里。
			# 占地越大越难放进 20x12 的场：所以只保留球门/沙坑/记分牌三件，
			# **看台不放**（10x4 格塞进场里会横跨大半个场，反而更乱）。
			{"kind": "goal", "tile": Vector2i(9, 17)},              # 足球门（场内西侧）
			{"kind": "sandpit", "tile": Vector2i(8, 20)},          # 跳远沙坑（场内西侧，完整落在跑道范围内）
			{"kind": "scoreboard", "tile": Vector2i(18, 21)},       # 记分牌（场内东南）
			# 街具：沿操场**外侧**的草坪/路肩，间距拉开（坐标取自落位工具的可用格清单，
			# 避开路灯底座 —— 路灯沿人行道等距摆，占了 10/20/30/40 这些格）
			{"kind": "bike_shed", "tile": Vector2i(30, 15)},        # 车棚（操场北侧草坪）
			{"kind": "pingpong", "tile": Vector2i(20, 15)},          # 乒乓球台
			{"kind": "hoop", "tile": Vector2i(42, 15)},             # 篮球架（南侧路旁）
			{"kind": "field_light", "tile": Vector2i(4, 11)},       # 高杆灯（操场角）
			{"kind": "water", "tile": Vector2i(44, 24)},            # 直饮水台
		],
		"links": [
			_door(Vector2i(24, 2), Vector2i(2, 2), "北门 · 往教学区", "往教学区走",
					"college.campus_teaching", "from_sports"),
		],
		"green_lines": [
			{"axis": "x", "at": 3, "from": 2, "to": 43, "step": 9,
					"kinds": ["tree_big", "tree_dark", "palm"]},
			{"axis": "x", "at": 31, "from": 4, "to": 43, "step": 9,
					"kinds": ["tree_flower", "tree_big", "tree_autumn"]},
			{"axis": "y", "at": 27, "from": 13, "to": 24, "step": 4, "kind": "bush_plain"},
			{"axis": "x", "at": 26, "from": 4, "to": 20, "step": 6, "kind": "bush_blue"},
			{"axis": "x", "at": 11, "from": 30, "to": 42, "step": 5, "kind": "bush_orange"},
		],
		"green_spots": [
			{"kind": "rock", "tile": Vector2i(28, 20)}, {"kind": "rock2", "tile": Vector2i(28, 24)},
			{"kind": "bush_pink", "tile": Vector2i(30, 22)}, {"kind": "bush_orange", "tile": Vector2i(44, 20)},
			{"kind": "tree_flower", "tile": Vector2i(45, 24)}, {"kind": "palm", "tile": Vector2i(2, 20)},
		],
		"npcs": [
			# 08 定稿：跑步的同学 —— 艾莉娜入队后接一段（08 标"+"）
			# ⚠️ 基座是**原文**，"+" 那段只放在 `lines_after` 里：写成"基座已含新增"会造成
			#    两份内容重叠、`lines_after` 又整体替换 —— 一旦哪天要改原文就得改两处。
			_npc("field_runner_1", "跑步的同学", Vector2i(12, 15), Vector2i(1, 0), [
				{"speaker": "", "text": "一个男生沿着跑道内侧匀速跑着，呼吸很稳。"},
				{"speaker": "跑步的同学", "text": "……外圈四百米，我一般跑五圈。", "emotion": "喘"},
			], {
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "", "text": "一个男生沿着跑道内侧匀速跑着，呼吸很稳。"},
					{"speaker": "跑步的同学", "text": "……外圈四百米，我一般跑五圈。", "emotion": "喘"},
					{"speaker": "艾莉娜", "text": "粥粥你看！我飞得比他跑步快多了！", "emotion": "得意"},
					{"speaker": "周明远", "text": "艾莉娜会飞，更省力，快是必然的。", "emotion": "无语"},
				],
				"night_visible": true,
				"night_name": "夜跑的同学",
				"night_lines": [
					{"speaker": "艾莉娜", "text": "这么晚了，竟然还有夜跑的同学呀！", "emotion": "惊讶"},
					{"speaker": "周明远", "text": "夜跑是我们学校的一项传统。过段时间还有音乐夜跑呢！", "emotion": "怀念"},
					{"speaker": "艾莉娜", "text": "音乐夜跑！粥粥后面带我去跑！", "emotion": "期待"},
					{"speaker": "周明远", "text": "你用飞的方式，到时候我可追不上你。", "emotion": "无奈"},
				],
			}),
			# 08 定稿：拉伸的同学 —— 艾莉娜入队后接一段（08 标"+"）
			_npc("field_runner_2", "拉伸的同学", Vector2i(8, 22), Vector2i(0, 1), [
				{"speaker": "拉伸的同学", "text": "刚跑完别马上坐下，腿会废的。", "emotion": "热心"},
				{"speaker": "周明远（内心）", "text": "我只是想找个地方坐一会儿。", "emotion": "心虚"},
			], {
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "拉伸的同学", "text": "刚跑完别马上坐下，腿会废的。", "emotion": "热心"},
					{"speaker": "周明远（内心）", "text": "我只是想找个地方坐一会儿。", "emotion": "心虚"},
					{"speaker": "艾莉娜", "text": "这位同学四肢好灵活！", "emotion": "惊叹"},
					{"speaker": "周明远（内心）", "text": "（你会飞，似乎应该是你更灵活吧。）", "emotion": "腹诽"},
				],
			}),
			_npc("gym_player", "刚打完球的学生", Vector2i(36, 20), Vector2i(0, 1), [
				{"speaker": "刚打完球的学生", "text": "羽毛球场地早被约完了，下周的也满了。", "emotion": "喘"},
				{"speaker": "刚打完球的学生", "text": "你要打就加个群，每天中午十二点抢。", "emotion": "随口"},
			]),
			# 08 定稿：沿着跑道走的同学 —— 艾莉娜入队后接一段（08 标"+"）
			_npc("field_walker", "沿着跑道走的同学", Vector2i(20, 24), Vector2i(-1, 0), [
				{"speaker": "沿着跑道走的同学", "text": "我不跑，就是走几圈。毕竟马上要体测了。", "emotion": "平淡"},
				{"speaker": "周明远", "text": "要体测了？唉，我后面也得练了。", "emotion": "心虚"},
			], {
				"rewrite_after": she_joined_flag(),
				"lines_after": [
					{"speaker": "沿着跑道走的同学", "text": "我不跑，就是走几圈。毕竟马上要体测了。", "emotion": "平淡"},
					{"speaker": "周明远", "text": "要体测了？唉，我后面也得练了。", "emotion": "心虚"},
					{"speaker": "艾莉娜", "text": "粥粥很担心体测吗？", "emotion": "关心"},
					{"speaker": "周明远", "text": "对呀，要是不及格，可是没有毕业证的。", "emotion": "认命"},
					{"speaker": "艾莉娜", "text": "艾莉娜相信粥粥一定能过的！", "emotion": "鼓劲"},
				],
			}),
		],
		"jobs": [],
		"shops": [],
	}


# ================================================================== 建筑牌子（08 定稿）

## 楼 id -> 牌子上的话（`request/08_DIALOG.md` 里"看 XX 的牌子"那几处）。
##
## ⚠️ 为什么搬到数据里（原来是 `campus.gd::_sign_text()` 的一个 `match`）：
##    "改一句牌子上的字"不该动场景脚本，而且那份 `match` 对话编辑器登记不到 ——
##    搬过来之后牌子与 NPC 台词走同一条数据通路，也能被对话补丁覆盖。
## ⚠️ 每条都是**一段台词**（数组），不是一行字符串：08 的牌子文案本身可能带情绪/分行。
const SIGN_LINES := {
	"canteen": [
		{"speaker": "", "text": "第一食堂。一层快餐，二层小炒。每到中午都会人挤人。"},
	],
	"supermarket": [
		{"speaker": "", "text": "教育超市。日用品，文具，泡面，都能在这里买到。"},
	],
	"teaching": [
		{"speaker": "", "text": "教学楼。你这四年都是在这里上课的。"},
	],
	"dorm_building": [
		{"speaker": "", "text": "学生宿舍。你的宿舍在这栋楼的三层。"},
	],
	"library": [
		{"speaker": "", "text": "图书馆。你昨晚就是在这里赶文献综述，赶到关灯。"},
	],
	"photo_copy": [
		{"speaker": "", "text": "照相馆 · 复印店。拍证件照、复印、装订论文，都能在这儿办。"},
	],
	"clinic": [
		{"speaker": "", "text": "校医院。感冒发烧来这儿拿药。晚上只有值班医生。"},
	],
	"gym": [
		{"speaker": "", "text": "体育馆。羽毛球场和篮球场都要提前约，散场后归体育部管。"},
	],
}

## 艾莉娜入队之后，牌子上**接在后面**的那段（`request/08_DIALOG.md` 里标 `+` 的几处）。
##
## 为什么不直接并进 `SIGN_LINES`：那几段只在"她已经在队里"时出现，
## 而 `SIGN_LINES` 是纯数据（没有开关概念）—— 并进去的话，开局看牌子就会
## 冒出一个玩家还不认识的角色说话。
## ⚠️ 与 `AlyinaBanter` 的分工：那边是"按物件名匹配"的通用池子（长椅/垃圾桶…），
##    这里每栋楼**各写一段**（钟会不会响 / 消毒水味 / 抢不到场子…），
##    所以不走通用池子、也不会被"一个话题只说一次"的规矩影响。
const SIGN_BANTER := {
	"teaching": [
		{"speaker": "艾莉娜", "text": "这就是大学的教学楼吗，好气派！", "emotion": "惊叹"},
		{"speaker": "艾莉娜", "text": "楼顶上的钟会真的响起来吗！", "emotion": "好奇"},
		{"speaker": "周明远", "text": "会的，就是和高中一样的上课下课铃而已。", "emotion": "平淡"},
	],
	"clinic": [
		{"speaker": "艾莉娜", "text": "这里消毒水味道好重，我不喜欢！", "emotion": "嫌弃"},
		{"speaker": "周明远", "text": "你都忘了先前的记忆了，为什么会不喜欢消毒水味呢？", "emotion": "疑惑"},
		{"speaker": "艾莉娜", "text": "不知道，可能是生理上的抵触吧？", "emotion": "困惑"},
		{"speaker": "周明远（内心）", "text": "（这难道是小精灵这个种族的特性吗？）", "emotion": "琢磨"},
	],
	"gym": [
		{"speaker": "周明远", "text": "这里的场子我疑似从来没有抢到过。", "emotion": "感慨"},
		{"speaker": "艾莉娜", "text": "真的吗，这么火爆呀！", "emotion": "惊讶"},
		{"speaker": "周明远", "text": "大学这么多人，总会有很多喜欢运动的。", "emotion": "平淡"},
	],
	"dorm_building": [
		{"speaker": "艾莉娜", "text": "这就是你的宿舍楼吗？看起来好新鲜！", "emotion": "好奇"},
		{"speaker": "周明远（内心）", "text": "（新鲜的是你，我在这待了四年了，已经看腻了。）", "emotion": "无奈"},
	],
}


## 某栋楼的牌子台词（没登记的返回空数组，场景脚本会退回只写楼名）。
##
## ⚠️ 她入队之后，这里会把 `SIGN_BANTER` 里那一段**接在后面**（08 标 `+` 的语义）。
static func sign_lines(building_id: String) -> Array:
	var out := (SIGN_LINES.get(building_id, []) as Array).duplicate(true)
	if GameFlow.has_flag(StoryData.FLAG_MORNING) and building_id == "library":
		out = [{"speaker": "", "text": "你昨天没来这里，而是收获了丰富多彩的一天。"}]
	# 第二天早晨四处建筑牌子只保留当天的牌子说明，不再追加艾莉娜插话。
	if GameFlow.has_flag(StoryData.FLAG_MORNING):
		return out
	if out.is_empty():
		return out
	# 夜间建筑仍可查看基础牌子说明，但不再触发任何艾莉娜追加段落。
	if is_night():
		return out
	if not GameFlow.has_flag(she_joined_flag()):
		return out
	out.append_array((SIGN_BANTER.get(building_id, []) as Array).duplicate(true))
	return out


## 楼门口"现在还不能去"的台词（`<楼 id>` -> 一段话）。
##
## 目前只有教学楼：08 要求"**食堂完成前不应该能有进入教学楼的交互选项**"，
## 于是那道门挂了 `required_flag = QuestData.FLAG_ATE`（吃过饭），
## 没打开时就把下面这段播出来（而不是一句"门锁着"）。
##
## ⚠️ 放在**数据**里（而不是场景脚本的 const）：对话编辑器要能改它 ——
##    `/`键是楼 id，编辑器按它登记成 `campus.entrance.<楼 id>.locked`。
const ENTRANCE_LOCKED := {
	"teaching": [
		{"speaker": "周明远（内心）", "text": "教学楼那边……饭还没吃呢。", "emotion": "肚子叫"},
		{"speaker": "周明远（内心）", "text": "先去食堂把饭吃了，顺便看看能不能打个工。", "emotion": "认命"},
	],
}


static func entrance_locked(building_id: String) -> Array:
	return (ENTRANCE_LOCKED.get(building_id, []) as Array).duplicate(true)


# ================================================================== 查询与工具


## 取某区的建筑（找不到返回空字典）
static func building(zone_dict: Dictionary, id: String) -> Dictionary:
	for b_variant in zone_dict.get("buildings", []):
		var b: Dictionary = b_variant
		if String(b["id"]) == id:
			return b
	return {}


## 硬性要求判据：某区里食堂与宿舍楼是否"隔着一条东西向主路正对"。
##   ① 两栋楼的 x 带必须**重叠** —— 同一列带上才叫"正对"，斜对角不算；
##   ② 两者之间必须有一条**横向车行路**，且它横向覆盖了这两栋楼。
static func canteen_faces_dorm(zone_dict: Dictionary) -> bool:
	var canteen: Rect2i = building(zone_dict, "canteen").get("tiles", Rect2i())
	var dorm: Rect2i = building(zone_dict, "dorm_building").get("tiles", Rect2i())
	if canteen.size.x <= 0 or dorm.size.x <= 0:
		return false
	if maxi(canteen.position.x, dorm.position.x) >= mini(canteen.end.x, dorm.end.x):
		return false
	var between_lo := canteen.end.y
	var between_hi := dorm.position.y
	for road_variant in zone_dict.get("roads", []):
		var road: Dictionary = road_variant
		if String(road["kind"]) != "road":
			continue
		var t: Rect2i = road["tiles"]
		if t.size.x <= t.size.y:
			continue
		if t.position.y >= between_lo and t.end.y <= between_hi \
				and t.position.x <= canteen.position.x and t.end.x >= dorm.end.x:
			return true
	return false


## 舞台自检 / 走查共用的"这一区有哪些硬性契约"
static func zone_summary(zone_dict: Dictionary) -> Dictionary:
	return {
		"id": String(zone_dict.get("id", "")),
		"label": String(zone_dict.get("label", "")),
		"buildings": zone_dict.get("buildings", []).size(),
		"roads": zone_dict.get("roads", []).size(),
		"plazas": zone_dict.get("plazas", []).size(),
		"links": zone_dict.get("links", []).size(),
		"gates": zone_dict.get("gates", []).size(),
		"npcs": zone_dict.get("npcs", []).size(),
		"jobs": zone_dict.get("jobs", []).size(),
		"shops": zone_dict.get("shops", []).size(),
		"has_playground": zone_dict.get("playground", Rect2i()).size.x > 0,
	}


# ================================================================== 经济系统（工位 / 商店）
#
# 数据形状（两条都只有"我在这儿、我是哪一家"这几个字段，规则与价钱分别在
# `WorkDb` / `ShopDb` 里）：
#
#   jobs   [{id, job_id, tile}]   id = 场景节点名后缀/记账键；job_id = WorkDb.JOBS 的键
#   shops  [{id, shop_id, tile}]  id = 场景节点名后缀；  shop_id = ShopDb.SHOPS 的键
#
# 位置一律是**逻辑格**，且必须是玩家走得到的地方（门前人行道），
# 因为建筑楼体是整块碰撞 —— 交互区摆在楼体里面 = 永远按不到（校门那次踩过同类坑）。
# `size` 可选（逻辑格，默认 3x2），用来给交互区一个明确的"门口台阶"范围。


## 本区的打工工位（每条都补齐 size / prompt，场景脚本直接用）
static func jobs(zone_dict: Dictionary) -> Array:
	return _spots(zone_dict, "jobs")


## 本区的商店入口
static func shops(zone_dict: Dictionary) -> Array:
	return _spots(zone_dict, "shops")


static func _spots(zone_dict: Dictionary, key: String) -> Array:
	var out: Array = []
	for entry_variant in zone_dict.get(key, []):
		var entry: Dictionary = (entry_variant as Dictionary).duplicate()
		if not entry.has("size"):
			entry["size"] = Vector2i(3, 2)
		out.append(entry)
	return out


## 一个交互区（逻辑格中心 + 尺寸）-> 世界像素矩形。
## 为什么用"中心 + 尺寸"而不是"左上角 + 尺寸"：数据里写 tile 时想的是
## "我就摆在这一格"，所以中心和那一格的中心对齐最不容易写错（少一次心算偏移）。
static func spot_rect(tile: Vector2i, size_tiles: Vector2i) -> Rect2:
	var center := Grid.tile_to_px(tile)
	var size := Grid.size_to_px(size_tiles)
	return Rect2(center - size * 0.5, size)


## 位置重合检查（同一格上摆了两个交互区 = 玩家按 E 永远只碰到一个）
static func spot_overlap(zone_dict: Dictionary) -> Array:
	var out: Array = []
	var all: Array = jobs(zone_dict) + shops(zone_dict)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Vector2i = (all[i] as Dictionary)["tile"]
			var b: Vector2i = (all[j] as Dictionary)["tile"]
			if a == b:
				out.append("%s×%s@%s" % [String((all[i] as Dictionary)["id"]),
						String((all[j] as Dictionary)["id"]), str(a)])
	return out


## 宿舍楼门口（图块坐标）：门板摆在这栋楼南沿正中
static func dorm_door_tiles(zone_dict: Dictionary) -> Vector2i:
	var dorm: Rect2i = building(zone_dict, "dorm_building").get("tiles", Rect2i())
	if dorm.size.x <= 0:
		return Vector2i.ZERO
	return Vector2i(dorm.position.x + dorm.size.x / 2 - 1, dorm.end.y - 1)


## 食堂门口（图块坐标）：同上，摆在食堂楼体南沿正中。
## 用户 2026-09-19 要求"食堂打工要进食堂场景"，所以生活区的食堂多了一道能进去的门。
static func canteen_door_tiles(zone_dict: Dictionary) -> Vector2i:
	var canteen: Rect2i = building(zone_dict, "canteen").get("tiles", Rect2i())
	if canteen.size.x <= 0:
		return Vector2i.ZERO
	return Vector2i(canteen.position.x + canteen.size.x / 2 - 1, canteen.end.y - 1)


## 出生点（逻辑格）。命名规则：**`from_<来源>` = 从那个区进来时落地的位置**。
##
## 为什么跨区算而不是各区自己写：门是"单向声明"（本区的 links 只说"我通向谁"），
## 但"从谁那儿进来要站在哪"得由**目标区**知道。这里扫全部分区，谁有门通向我就给我加一个
## `from_<那个区>` 的落点，落在我这边那道门的内侧 2 格 —— 两边永远不会对不上。
static func spawns(zone_dict: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var my_id := String(zone_dict.get("id", ""))
	var my_location := location_of(my_id)

	# ① 宿舍门口（只有生活区有宿舍楼）
	var door := dorm_door_tiles(zone_dict)
	if door != Vector2i.ZERO:
		out["from_dorm"] = Vector2i(door.x, door.y + 1)

	# ② 来自其他区的入口
	for other_id in ZONE_IDS:
		if other_id == my_id:
			continue
		var other := zone(other_id)
		var comes_here := false
		for l_variant in other.get("links", []):
			if String((l_variant as Dictionary)["target_location"]) == my_location:
				comes_here = true
				break
		if not comes_here:
			continue
		var spot := _inward_spot(zone_dict, location_of(other_id))
		if spot != Vector2i.ZERO:
			out["from_%s" % other_id] = spot

	# ③ 默认落点：优先"从生活区进来"（主入口），其次宿舍门口，最后任一门的内侧
	if out.has("from_%s" % ZONE_LIFE):
		out["default"] = out["from_%s" % ZONE_LIFE]
	elif out.has("from_dorm"):
		out["default"] = out["from_dorm"]
	else:
		var fallback := _inward_spot(zone_dict, "")
		out["default"] = fallback if fallback != Vector2i.ZERO else Grid.CAMPUS_SIZE / 2
	if out.has("from_dorm") and not out.has("from_%s" % ZONE_LIFE):
		out["default"] = out["from_dorm"]
	return out


## 找本区那道通向 [param target_location] 的门，返回它**往地图中心内侧** 2 格的落点。
## target_location 传空串表示"任取第一道门"。
static func _inward_spot(zone_dict: Dictionary, target_location: String) -> Vector2i:
	var links: Array = zone_dict.get("links", [])
	if links.is_empty():
		return Vector2i.ZERO
	var center := Grid.CAMPUS_SIZE / 2
	for l_variant in links:
		var l: Dictionary = l_variant
		if target_location != "" and String(l["target_location"]) != target_location:
			continue
		var t: Vector2i = l["tile"]
		var inward := Vector2i(signi(center.x - t.x), signi(center.y - t.y))
		return t + inward * 2
	return Vector2i.ZERO


# ================================================================== 绿化


## 绿化种类：占地（逻辑格）与落地碰撞
const GREEN_KINDS := {
	"tree_big":    {"file": "tree_broadleaf_big.png", "tiles": 4, "solid": Rect2(0.36, 0.62, 0.28, 0.34)},
	"tree_dark":   {"file": "tree_dark_big.png", "tiles": 4, "solid": Rect2(0.36, 0.62, 0.28, 0.34)},
	"tree_flower": {"file": "tree_flower_big.png", "tiles": 4, "solid": Rect2(0.36, 0.62, 0.28, 0.34)},
	"tree_autumn": {"file": "tree_autumn_big.png", "tiles": 4, "solid": Rect2(0.36, 0.62, 0.28, 0.34)},
	"palm":        {"file": "palm_big.png", "tiles": 4, "solid": Rect2(0.40, 0.62, 0.22, 0.34)},
	"tree_small":  {"file": "tree_broadleaf_small.png", "tiles": 2, "solid": Rect2(0.34, 0.56, 0.32, 0.40)},
	"tree_small2": {"file": "tree_dark_small.png", "tiles": 2, "solid": Rect2(0.34, 0.56, 0.32, 0.40)},
	"tree_sakura": {"file": "tree_flower_small.png", "tiles": 2, "solid": Rect2(0.34, 0.56, 0.32, 0.40)},
	"palm_small":  {"file": "palm_small.png", "tiles": 2, "solid": Rect2(0.38, 0.56, 0.26, 0.40)},
	"bush":        {"file": "bush_plain.png", "tiles": 1, "solid": Rect2(0.14, 0.28, 0.72, 0.62)},
	"bush_pink":   {"file": "bush_pink.png", "tiles": 1, "solid": Rect2(0.14, 0.28, 0.72, 0.62)},
	"bush_orange": {"file": "bush_orange.png", "tiles": 1, "solid": Rect2(0.14, 0.28, 0.72, 0.62)},
	"bush_blue":   {"file": "bush_blue.png", "tiles": 1, "solid": Rect2(0.14, 0.28, 0.72, 0.62)},
	"rock":        {"file": "rock_a.png", "tiles": 1, "solid": Rect2(0.14, 0.34, 0.72, 0.58)},
	"rock2":       {"file": "rock_b.png", "tiles": 1, "solid": Rect2(0.14, 0.34, 0.72, 0.58)},
	"rock3":       {"file": "rock_c.png", "tiles": 1, "solid": Rect2(0.14, 0.34, 0.72, 0.58)},
}

## 网格撒点的间距（逻辑格）。比旧版稀疏：用户要求"密度降低一些"。
## 2026-09-19 从 6 加到 9：用户又报"东西放得太密了" —— 撒点是**全局兜底**，
## 间距一小，草坪上就全是灌木石头，和街具挤在一起。
const SCATTER_STEP := 9


static func green_texture(kind: String) -> String:
	var def: Dictionary = GREEN_KINDS.get(kind, {})
	return FLORA_DIR + String(def.get("file", "bush_plain.png"))


## 生成某区全部绿化（沿线 + 定点 + 网格兜底）
static func greenery(zone_dict: Dictionary) -> Array:
	var out: Array = []
	var blocked := blocked_cells(zone_dict)
	for line_variant in zone_dict.get("green_lines", []):
		emit_green_line(out, blocked, line_variant)
	for spot_variant in zone_dict.get("green_spots", []):
		var spot: Dictionary = spot_variant
		var tile: Vector2i = spot["tile"]
		var cells := green_footprint_cells(tile, String(spot["kind"]))
		if is_free(cells, blocked) and not is_too_close(out, cells, 1):
			out.append(make_green_item(String(spot["kind"]), cells))
	fill_green_scatter(out, blocked)
	return out


## ⚠️ 本函数与下面几个内部小工具（`is_free` / `is_too_close` / `make_green_item` /
## `fill_green_scatter` / `mark_dict` / `cells_overlap_any`）**改名时属于公开 API**：
## `CampusLayout` 逐行复刻了生成过程（为了给每件产出打稳定 id），它直接调用这些函数。
## 改签名要同步 `scripts/data/campus_layout.gd`，并跑 `tools/check_campus_layout.gd` 逐件比对。
static func emit_green_line(out: Array, blocked: Dictionary, line_variant: Variant) -> void:
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
		var cells := green_footprint_cells(tile, kind)
		if is_free(cells, blocked):
			out.append(make_green_item(kind, cells))
			placed += 1
		t += step


## 网格撒点：稀疏间距（SCATTER_STEP），落在建筑/道路/广场/操场上的跳过。
## 这是"密度"的旋钮：间距调大 → 校园更空；调小 → 更热闹。
static func fill_green_scatter(out: Array, blocked: Dictionary) -> void:
	var kinds := ["bush_pink", "rock", "bush_blue", "tree_small", "bush_orange", "rock2",
			"bush_plain", "tree_sakura", "bush_plain", "rock3"]
	var idx := 0
	var size := Grid.CAMPUS_SIZE
	for ty in range(3, size.y - 2, SCATTER_STEP):
		var odd_row := (ty / SCATTER_STEP) % 2 == 1
		for tx in range(3, size.x - 2, SCATTER_STEP):
			var tile := Vector2i(tx + (SCATTER_STEP / 2 if odd_row else 0), ty)
			if tile.x >= size.x - 2:
				continue
			var kind: String = kinds[idx % kinds.size()]
			var cells := green_footprint_cells(tile, kind)
			if not is_free(cells, blocked) or is_too_close(out, cells, 1):
				kind = "bush_plain" if kind.begins_with("tree") else kinds[(idx + 4) % kinds.size()]
				cells = green_footprint_cells(tile, kind)
				if not is_free(cells, blocked) or is_too_close(out, cells, 1):
					continue
			out.append(make_green_item(kind, cells))
			idx += 1


## 绿化占地图块格：以 [param tile] 为"落地格"（脚底中心），按素材尺寸向上/左右铺开。
## 大树立绘 128x128 → 8x8 格、小树 64x64 → 4x4、灌木石头 32x32 → 2x2。
static func green_footprint_cells(tile: Vector2i, kind: String) -> Rect2i:
	var def: Dictionary = GREEN_KINDS.get(kind, {})
	var cells: int = int(def.get("tiles", 1)) * Grid.CELLS_PER_TILE
	var x0 := tile.x * Grid.CELLS_PER_TILE - (cells / 2 - 1)
	var y0 := (tile.y + 1) * Grid.CELLS_PER_TILE - cells
	return Rect2i(x0, y0, cells, cells)


static func make_green_item(kind: String, cells: Rect2i) -> Dictionary:
	var def: Dictionary = GREEN_KINDS.get(kind, {})
	return {
		"kind": kind,
		"cells": cells,
		"texture_path": green_texture(kind),
		"whole_sprite": true,
		"collision": def.get("solid", Rect2(0.2, 0.4, 0.6, 0.5)),
		"foliage": true,
	}


## 被建筑/道路/广场/操场/校门/区间门占掉的图块格（绿化排布时跳过）
static func blocked_cells(zone_dict: Dictionary) -> Dictionary:
	var blocked: Dictionary = {}
	for b_variant in zone_dict.get("buildings", []):
		_mark(blocked, _tiles_to_cells((b_variant as Dictionary)["tiles"]))
	for r_variant in zone_dict.get("roads", []):
		_mark(blocked, _tiles_to_cells((r_variant as Dictionary)["tiles"]))
	for p_variant in zone_dict.get("plazas", []):
		_mark(blocked, _tiles_to_cells(p_variant))
	for g_variant in zone_dict.get("gates", []):
		var g: Dictionary = g_variant
		_mark(blocked, _tiles_to_cells(Rect2i(g["tile"], g["size"])))
	for l_variant in zone_dict.get("links", []):
		var l: Dictionary = l_variant
		_mark(blocked, _tiles_to_cells(Rect2i(l["tile"], l["size"])))
	var pg: Rect2i = zone_dict.get("playground", Rect2i())
	if pg.size.x > 0:
		_mark(blocked, _tiles_to_cells(pg))
	return blocked


static func _tiles_to_cells(tiles: Rect2i) -> Rect2i:
	return Rect2i(tiles.position * Grid.CELLS_PER_TILE, tiles.size * Grid.CELLS_PER_TILE)


## 街具专用的"不能摆"集合：**比绿化宽松得多** —— 人行道**与车行路都允许摆**，
## 草坪也允许（`props()` 只查 `blocked` + `occupied(绿化)`，不查草地）。
##
## 2026-09-19 修正（用户实报"东西放得太密了""操场的物件都放到道路上了，不在操场中"）：
##   原来这里把 `kind == "road"`（车行路）也标成障碍，于是**凡是跨路的东西都摆不上**，
##   而操场器材的占地又高（看台 4 格、沙坑 2 格），能摆的地方只剩人行道 ——
##   结果就是"器材全堆在人行道上、还互相挤"。现在只把**会给玩家带来语义冲突**的东西算障碍：
##   建筑（走不进去）、广场（留给人流）、校门、区间门。
##   路本身不需要禁：路口摆长椅/垃圾桶是很自然的，真正要避免的是"长在楼里"。
static func blocked_cells_for_props(zone_dict: Dictionary) -> Dictionary:
	var blocked: Dictionary = {}
	for b_variant in zone_dict.get("buildings", []):
		_mark(blocked, _tiles_to_cells((b_variant as Dictionary)["tiles"]))
	for p_variant in zone_dict.get("plazas", []):
		_mark(blocked, _tiles_to_cells(p_variant))
	for g_variant in zone_dict.get("gates", []):
		var g: Dictionary = g_variant
		_mark(blocked, _tiles_to_cells(Rect2i(g["tile"], g["size"])))
	for l_variant in zone_dict.get("links", []):
		var l: Dictionary = l_variant
		_mark(blocked, _tiles_to_cells(Rect2i(l["tile"], l["size"])))
	# ⚠️ **操场与道路都不算障碍**：
	#    操场器材本来就要摆在场内（标成障碍会让 prop_spots 里的器材全被跳过 —— 实踩）；
	#    道路则如上所述，禁了会把所有大件挤到人行道上。
	return blocked


static func _mark(blocked: Dictionary, cells: Rect2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			blocked[Vector2i(x, y)] = true


static func is_free(cells: Rect2i, blocked: Dictionary) -> bool:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			if blocked.has(Vector2i(x, y)):
				return false
	return true


static func is_too_close(items: Array, cells: Rect2i, gap: int) -> bool:
	var probe := Rect2i(cells.position - Vector2i(gap, gap), cells.size + Vector2i(gap * 2, gap * 2))
	for item_variant in items:
		if probe.intersects((item_variant as Dictionary)["cells"]):
			return true
	return false


# ================================================================== 构造小工具


static func _b(id: String, label: String, tile_pos: Vector2i, size_tiles: Vector2i,
		texture: String) -> Dictionary:
	return {
		"id": id, "label": label, "kind": "building",
		"tile_pos": tile_pos, "size_tiles": size_tiles,
		"tiles": Rect2i(tile_pos, size_tiles),
		"texture": texture,
	}


## 路口占地常量：4x4 逻辑格（`request/10` §4 那张整图就是按它出的）
const PLAZA_SIZE := 4


static func _r(tile_pos: Vector2i, size_tiles: Vector2i, material: int, kind: String) -> Dictionary:
	return {"tiles": Rect2i(tile_pos, size_tiles), "material": material, "kind": kind}


## 由路网**算出**每个十字路口的 4x4 占地（逻辑格）。
##
## ⚠️ 为什么不再手写（2026-09-20 用户实报"十字路口和周围的道路并不协调"）：
##    路口原来是手写坐标（`Rect2i(23, 9, 4, 4)` 这种），而它是"4x4 的广场盖在
##    **2x2 的交叉**上"—— 手写必然会偏 1 格。实测三个区**全都偏了**：
##      · 生活区 (23,9)：它的交叉在 y=10，广场下沿落在 y=12（压到了另一条路上）；
##      · 教学区 (23,9)：交叉在 y=9..10，广场却从 y=9 起（上沿差 1）；
##      · 运动区 (23,26)：交叉在 y=28..29，广场上沿差 1。
##    表现就是"路口那块地砖和路面接缝对不上"。现在由**道路数据**直接算：
##    `(交叉中心 - 1, 4x4)` —— 交叉占 2 格、四周各留 1 格边，正好 4x4。
##
## ⚠️ **有两条很近的车行道时，算出来的两块 4x4 可能重叠**。这里**不合并、也不拉伸**，
##    只做去重；合并成 4x5/4x6 会把 512x512 的方图拉歪。人行道不参与交叉计算，
##    避免生活区/教学区中紧贴车道的人行道把路口中心提前。
##
## ⚠️ 曾经试过"挪路迁就路口"（把两条横路拉开到 ≥4 格）—— 那是反的：
##    路的位置是场景设计（谁挨着谁、人行道贴哪栋楼），不该为了路口让路。
static func plazas_for(zone_dict: Dictionary) -> Array:
	var roads: Array = zone_dict.get("roads", [])
	var v_roads: Array = []
	var h_roads: Array = []
	for road_variant in roads:
		var road: Dictionary = road_variant
		# 只有车行道才定义十字路口中心；人行道紧贴车道时不能参与计算，
		# 否则会把下方真正的车行道交点提前，导致整块路口贴图错位。
		if String(road.get("kind", "")) != "road":
			continue
		var t: Rect2i = road["tiles"]
		if t.size.y > t.size.x:
			v_roads.append(t)
		elif t.size.x > t.size.y:
			h_roads.append(t)
	var out: Array = []
	for v_variant in v_roads:
		var v: Rect2i = v_variant
		for h_variant in h_roads:
			var h: Rect2i = h_variant
			var cx := v.position.x + v.size.x / 2
			var cy := h.position.y + h.size.y / 2
			if cx < h.position.x or cx >= h.end.x or cy < v.position.y or cy >= v.end.y:
				continue
			var rect := Rect2i(cx - PLAZA_SIZE / 2, cy - PLAZA_SIZE / 2, PLAZA_SIZE, PLAZA_SIZE)
			# ⚠️ 两条横路只隔 1 格时（road y=10..11 / walk y=12），两处交叉各自算出的 4x4
			#    会**重叠 3 行** —— 同一个路口被摆两块整图。贪心去重：与已有的重叠就跳过，
			#    只留一块（那两处交叉本来就近得连成同一个路口）。
			#    ⚠️ 不能"合并成 4x5/4x6"：那张 512x512 的方图一拉就歪（像素画非等比缩放），
			#       斑马线与路缘全对不上 —— 实测过。
			var overlaps := false
			for existing_variant in out:
				if (existing_variant as Rect2i).intersects(rect):
					overlaps = true
					break
			if not overlaps:
				out.append(rect)
	return out


## 校门（含它的台词，以及"某个开关成立后整体换一段"的可选项，见 `_gate` 的说明）。
static func _gate(tile_pos: Vector2i, size_tiles: Vector2i, label: String, texture: String,
		lines: Array, extra: Dictionary = {}) -> Dictionary:
	var out := {"tile": tile_pos, "size": size_tiles, "label": label, "texture": texture,
			"lines": lines}
	# `rewrite_after` + `lines_after`：08 里"看校门（南）"那几句是**整体改写**的
	# （她入队之后换成"门卫大爷"那一段），所以做成"换成哪一段"而不是追加。
	for key in ["rewrite_after", "lines_after", "morning_lines"]:
		if extra.has(key):
			out[key] = extra[key]
	return out


## 街具里**可以交互**的那几种（按 E 有一段台词 / 能买东西）。
## 08 定稿："在全时段加入公告牌和自动售货机的交互文本和自动售货机的购买交互，
## 同时加入艾莉娜的文本在该阶段"。
##
## 玩法：
##   · `公告栏`：一段旁白 + 主角吐槽（**一直有**），她入队后由 `AlyinaBanter`
##     按物件名（"公告栏"）接上她"为什么很少看公告牌"那一段；
##   · `自动售货机`：先播一句"鬼才的赚钱方式"（一直有），再走**真的购买**
##     （`ShopSpot` + `ShopDb` 里的 `campus_vending`），她的"比超市贵"那段同样走插话池。
## ⚠️ 交互区比占地**往南多伸一格**：售货机/公告栏是贴着墙的整件精灵，
##    玩家中心进不去实体，只贴原地的话按 E 够不到（食堂打饭窗口踩过同一个坑）。
const PROP_EXAMINES := {
	"notice": {
		"name": "公告栏",
		"prompt": "看看公告栏",
		"lines": [
			{"speaker": "", "text": "公告牌上贴满了各种社团招新、学术报告等海报。"},
			{"speaker": "周明远", "text": "这堆海报一层堆着一层贴，也就领导来了才可能有人清理吧。",
				"emotion": "吐槽"},
		],
	},
	"vending": {
		"name": "自动售货机",
		"prompt": "用自动售货机",
		"lines": [
			{"speaker": "", "text": "自动售货机真是鬼才的赚钱方式，总是会出现在你最想要买饮品的时刻。"},
		],
		"shop_id": "campus_vending",
	},
	# 08 定稿："**全时段**给长椅加上坐和站起来的交互"。
	# 与上面两件不同：长椅要的是"一个能保持的状态"，所以由 `BenchSpot` 承载
	# （见那个脚本的文件头：提示词会变、别的长椅要能把人叫起来、状态要进存档）。
	"bench": {
		"name": "长椅",
		"prompt": "在长椅上坐下",
		"interact": "bench",
		# ⚠️ **坐下时整条长椅换成的图**（人 + 椅一体的成品，用户 2026-09-20 出的）。
		#    坐下的观感靠"换图 + 把玩家角色藏起来"，不再靠把角色叠到空长椅上 ——
		#    后者试过四档偏移都不像（坐姿角色只有 ~36px 高，而长椅座面就有 17px 厚；
		#    对比图见 `screenshots/35_坐长椅_偏移对比.png`）。
		#    接线在 `campus.gd::SIT_BENCH_DISPLAY_H` 与 `sit_spot.gd::_apply_seat_art()`。
		"sit_texture": "res://assets/graphics/props/campus_bench_sit/processed/clean.png",
		"lines": [
			{"speaker": "", "text": "坐了下来，后背靠在椅背上。"},
		],
		"stand_lines": [
			{"speaker": "", "text": "站起来，拍了拍裤子。"},
		],
	},
}


## 某件街具"坐下时换成哪张图"（没登记返回空串 = 坐下时不换图）
##
## 见 `PROP_EXAMINES["bench"]["sit_texture"]` 的说明：坐下的观感靠**换整张图**
## （人 + 椅一体的成品），而不是把玩家角色叠到空家具上。
static func prop_sit_texture(kind: String) -> String:
	return String(PROP_EXAMINES.get(kind, {}).get("sit_texture", ""))


## 某件街具的交互定义（没登记返回空字典 = 这件街具不可交互）
static func prop_examine(kind: String) -> Dictionary:	return PROP_EXAMINES.get(kind, {})


## 可交互街具的**交互区占格**：占地整体 + 往南（下）一格。
## ⚠️ 与 `spot_rect()` 的"3x2 格"不同：这两件是**贴墙的整件精灵**，
##    交互区必须比占地更靠外（玩家站在它前面的地板上才够得到）。
static func prop_interact_cells(cells: Rect2i) -> Rect2i:
	return Rect2i(cells.position, Vector2i(cells.size.x, cells.size.y + 1))


## 街具素材路径
static func prop_texture(kind: String) -> String:
	var def: Dictionary = PROP_KINDS.get(kind, {})
	return "res://assets/graphics/props/" + String(def.get("file", ""))


## 生成某区的街具（沿 `prop_lines` 等距摆）。[param occupied] 传绿化已占的格子，
## 避免路灯长在树上（两套排布各自都不重叠，但彼此会撞）。
static func props(zone_dict: Dictionary, occupied: Dictionary) -> Array:
	var out: Array = []
	var blocked := blocked_cells_for_props(zone_dict)
	# ⚠️ 已经摆下的街具**要记进 occupied**（只记**底座那一格**）：
	#    不记的话第二件只要底座躲开就能叠上去，于是出现"长椅和路灯共用一个底座"。
	#    但**不能记整块占地**：路灯的灯头是悬空的（4x8 格里有 6 格是灯臂），
	#    按整块占地记会把整条人行道锁死 —— 实测 25 件定点只剩 11 件摆得上。
	var taken: Dictionary = occupied.duplicate()
	for line_variant in zone_dict.get("prop_lines", []):
		var line: Dictionary = line_variant
		var kind := String(line.get("kind", "lamp"))
		var def: Dictionary = PROP_KINDS.get(kind, {})
		if def.is_empty():
			continue
		var size_tiles: Vector2i = def["tiles"]
		var t := int(line["from"])
		var to := int(line["to"])
		var step: int = maxi(1, int(line["step"]))
		var axis := String(line["axis"])
		var at := int(line["at"])
		while t <= to:
			var tile := Vector2i(t, at) if axis == "x" else Vector2i(at, t)
			var cells := prop_footprint_cells(tile, size_tiles)
			# ⚠️ 判空只看**底座那一格**，不是整个占地：路灯的灯头是悬空的（会伸到路上方），
			#    按整个占地判空的话，路边一格都摆不下（实踩：南区草坪一根灯都排不出来）。
			var base := Rect2i(tile * Grid.CELLS_PER_TILE,
					Vector2i(Grid.CELLS_PER_TILE, Grid.CELLS_PER_TILE))
			if zone_cells().encloses(cells) and is_free(base, blocked) \
					and not cells_overlap_any(base, taken):
				out.append({
					"kind": kind,
					"cells": cells,
					"texture_path": prop_texture(kind),
					"whole_sprite": true,
					"collision": def.get("solid", Rect2(0.3, 0.6, 0.4, 0.35)),
					"street_prop": true,
					"base_tile": tile,
				})
				mark_dict(taken, base)
			t += step
	# 定点器材（操场上的球门/篮球架/单双杠…）：位置由数据点明，不走等距排布
	for spot_variant in zone_dict.get("prop_spots", []):
		var spot: Dictionary = spot_variant
		var kind := String(spot["kind"])
		var def: Dictionary = PROP_KINDS.get(kind, {})
		if def.is_empty():
			continue
		var tile: Vector2i = spot["tile"]
		var size_tiles: Vector2i = def["tiles"]
		var cells := prop_footprint_cells(tile, size_tiles)
		var base := Rect2i(tile * Grid.CELLS_PER_TILE,
				Vector2i(Grid.CELLS_PER_TILE, Grid.CELLS_PER_TILE))
		if not zone_cells().encloses(cells) or not is_free(base, blocked):
			continue
		# 只避让**底座**（`taken` 里存的就是各件的底座格）：灯臂/椅背可以重叠，
		# 但两件东西的"落地那一格"不能同格 —— 那就是"堆在一起"了。
		if cells_overlap_any(base, taken):
			continue
		out.append({
			"kind": kind,
			"cells": cells,
			"texture_path": prop_texture(kind),
			"whole_sprite": true,
			"collision": def.get("solid", Rect2(0.3, 0.6, 0.4, 0.35)),
			"street_prop": true,
			"base_tile": tile,
		})
		mark_dict(taken, cells)
	return out


## 把一块格子标进"已占"字典（与绿化共用同一种键：图块格 Vector2i）
static func mark_dict(target: Dictionary, cells: Rect2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			target[Vector2i(x, y)] = true


## 通用占地：以 [param tile] 为"落地格"（脚底中心），向上铺 [param size_tiles] 个逻辑格
static func prop_footprint_cells(tile: Vector2i, size_tiles: Vector2i) -> Rect2i:
	var w := size_tiles.x * Grid.CELLS_PER_TILE
	var h := size_tiles.y * Grid.CELLS_PER_TILE
	var x0 := tile.x * Grid.CELLS_PER_TILE - (w / 2 - 1)
	var y0 := (tile.y + 1) * Grid.CELLS_PER_TILE - h
	return Rect2i(x0, y0, w, h)


static func cells_overlap_any(cells: Rect2i, occupied: Dictionary) -> bool:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			if occupied.has(Vector2i(x, y)):
				return true
	return false


static func _door(tile_pos: Vector2i, size_tiles: Vector2i, label: String, prompt: String,
		target_location: String, target_spawn: String) -> Dictionary:
	return {
		"tile": tile_pos, "size": size_tiles, "label": label, "prompt": prompt,
		"target_location": target_location, "target_spawn": target_spawn,
	}


static func _npc(id: String, display_name: String, tile: Vector2i, face: Vector2i,
		lines: Array, extra: Dictionary = {}) -> Dictionary:
	var out := {
		"id": id, "name": display_name, "tile": tile, "face": face,
		"prompt": "和%s说话" % display_name, "lines": lines,
	}
	if NPC_MODELS.has(id):
		out["model_path"] = NPC_MODELS[id]
	# 可选项（08 里用到的那几件）：
	#   `talk_order`   多阶段对话：一次交互播一段，最后一段永远重复（见 `Npc.dialogue_sequence`）
	#   `vanish_after` 说完就走（"急匆匆地进入了教学楼"那位）——
	#                  用同一个键名当**一次性开关**记进 `story_flags`，下次进这一区她不再出现
	#   `vanish_also_after` 除了"跟她说过话"之外，**还要**收掉她的别的开关（数组）——
	#                  例：抱着课本的同学在主角翘课出来之后也该走（见那一处的注释）
	#   `vanish_line`  走之前最后一句旁白
	#   `require_flag` 需要某个剧情开关，之后才走 `talk_order` 的第二段起
	#                  （08："食堂完成前不应该能有进入教学楼的交互选项"）
	#   `rewrite_after` 某个开关成立之后，这个 NPC 的台词**整体换成** `lines_after`
	#                  （08 里标"（全部修改）"的那几位，例如刚出图书馆的同学）
	#   `lines_after`   换了之后用哪一段（与 `rewrite_after` 配对）
	#   `name_after`    换了之后**名字也换**（同宿舍楼的同学：白天是"同层的同学"）
	for key in ["talk_order", "vanish_after", "vanish_also_after", "vanish_line", "require_flag",
			"rewrite_after", "lines_after", "name_after", "night_visible", "night_name", "night_lines",
			"morning_visible", "morning_lines"]:
		if extra.has(key):
			out[key] = extra[key]
	return out
