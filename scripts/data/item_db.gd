class_name ItemDb
extends RefCounted
## 道具表：**新增道具只改这一个文件**。
##
## 定位：纯数据，不认识 UI、对话、场景或任何系统。
## "这件道具用下去会发生什么"写在 `scripts/data/item_actions.gd` 里，
## 两边靠 `action` 字符串对应 —— 于是 ItemDb 可以整体换成外部 JSON 而不牵动逻辑。
##
## 背包分册（scope）：需求 `01_GOALS.md` 第 3 条要求
## **大学与高中的背包互相独立**，所以道具数量按分册分别存在 `GameState.inventories[分册]`。
## 这里的 `scope` 只表示"这件道具**默认**属于哪一册"（拾取时用它决定进哪个包），
## **不是硬限制** —— 将来做"把东西带进高中""交给别人"时允许跨册移动。

## 分册 ID（与 GameState.BAG_* 一致；常量放在 GameState 是因为它管存档格式）
const SCOPE_COLLEGE := "college"
const SCOPE_HIGHSCHOOL := "highschool"

## 分类 -> 中文名（详情面板显示用）
const KIND_NAMES := {
	"key": "关键道具",
	"tool": "可用道具",
	"battle_consumable": "战斗消耗品",
	"material": "素材",
	"clue": "线索",
	"money": "钱",
}

## 金钱在背包里的道具 id。
##
## 用户 2026-09-19 明确要求：**经济系统要作为"类似人民币的物件"显示在背包里，
## 而不是直接显示在界面上**（原来的右上角钱包 HUD 已删除）。
##
## 实现要点：它是**虚拟条目** —— 数量**不存在** `GameState.inventories` 里，
## 而是每次打开背包时从 `Currency.amount()` 现取（真身在 `GameState.money`）。
## 这样"钱包"只有一个数据源，不会出现"背包里的钱和实际余额对不上"。
## ⚠️ 凡是"能改变钱包"的地方（买/卖/打工）都不需要管背包 —— 两边天然一致。
const WALLET_ID := "money"

## 图标目录：没写 icon 的道具按 `<id>.png` 在这里找；找不到就退回占位色块。
const ICON_DIR := "res://assets/graphics/items/"

## 道具表：id -> 定义
##
##   name / desc      显示名与描述（desc 支持换行）
##   kind             分类，见 KIND_NAMES
##   scope            默认归属的背包分册
##   action           可用道具的效果 ID，见 scripts/data/item_actions.gd（没有 = 不可用）
##   droppable        能否丢弃（关键道具一律 false）
##   unique           唯一道具：已经有一件就不再收第二件（防复制；手机/钥匙这类）
##   prompt           地图上的拾取提示，缺省用"捡起<name>"
##   pickup_line      拾取时的一句旁白（可省）
##   icon             图标路径（可省，按约定推导）
const ITEMS := {
	"clinic_key_copy": {"name": "医务室钥匙（复制品）", "kind": "key", "scope": SCOPE_HIGHSCHOOL,
		"desc": "艾莉娜与周明远通过时序回溯之桥复制的过去的钥匙。原件仍留在医务室抽屉中，可作为夜间医务室调查的凭证。",
		"unique": true, "droppable": false, "usable": false},
	"highschool_boxing_note": {
		"name": "厕所角落的纸条", "kind": "clue", "scope": SCOPE_HIGHSCHOOL,
		"desc": "正面：WCB（厕所拳击联赛）正式开赛！弱者，就该被踩在脚下！\n背面：好害怕……谁来救救我……\n潦草的批注：幽闭恐惧症！",
		"action": "read_item", "droppable": false, "unique": true,
		"icon": "res://assets/graphics/items/generated/highschool_boxing_note/processed/note-1.png",
	},
	"highschool_anya_photo": {
		"name": "李安雅托人送来的合影", "kind": "clue", "scope": SCOPE_HIGHSCHOOL,
		"desc": "李安雅托闺蜜送来的合影。后来搬大学宿舍时丢失的那张，与用来穿越的冲印照片并不是同一张。",
		"action": "read_item", "droppable": false, "unique": true,
	},
	"highschool_timetable": {
		"name": "校园时刻表", "kind": "clue", "scope": SCOPE_HIGHSCHOOL,
		"desc": "艾莉娜在仓库旁公示栏记下的校园作息。\n16:30后的课程与晚自习，学生自愿参加，不强制。",
		"action": "read_timetable", "unique": true, "droppable": false,
		"icon": "res://assets/graphics/ui/highschool_timetable.png",
	},
	"ink_fragment": {
		"name": "墨痕碎片",
		"kind": "clue",
		"scope": SCOPE_HIGHSCHOOL,
		"desc": "从夜间怪物身上掉落的黑色纸片，边缘仍残留着紫色的光。",
		"droppable": true,
		"unique": false,
		"prompt": "拾取墨痕碎片",
	},
	"highschool_warehouse_key": {
		"name": "地下仓库的钥匙", "kind": "key", "scope": SCOPE_HIGHSCHOOL,
		"desc": "略有锈迹的旧钥匙，应该能打开地下仓库的门。", "droppable": false, "unique": true,
		"prompt": "拿起地下仓库的钥匙",
	},
	"flashlight": {
		"name": "手电筒", "kind": "tool", "scope": SCOPE_HIGHSCHOOL,
		"desc": "能照亮前方一小片黑暗。", "action": "use_flashlight", "droppable": false, "unique": true,
		"prompt": "拿起手电筒",
	},
	"phone": {
		"name": "手机",
		"kind": "tool",
		"scope": SCOPE_COLLEGE,
		"desc": "周明远的手机。右上角有一道裂纹，是高中那年从课桌上摔的。\n可以看时间。",
		"action": "use_phone",
		"droppable": false,
		"unique": true,
		"prompt": "捡起手机",
		"pickup_line": "手机就搁在桌面上，屏幕还亮着。",
	},
	# ---- 教育超市在卖的东西（价格在 scripts/data/shop_db.gd，别在这里写价钱）----
	# ⚠️ 加一件"能买的东西"= 这里加一条 + ShopDb 里挂个价，其余（图标/详情/买进背包）全自动。
	"energy_drink": {
		"name": "能量饮料",
		"kind": "tool",
		"scope": SCOPE_COLLEGE,
		"desc": "一罐冰过的能量饮料，标签上写着一行小字：不建议连续饮用。\n喝了大概能多撑两个小时。",
		"action": "use_energy_drink",
		"prompt": "拿起能量饮料",
	},
	"notebook": {
		"name": "笔记本",
		"kind": "material",
		"scope": SCOPE_COLLEGE,
		"desc": "横线本。上一本写到第三页就停了，这本不知道能写几页。\n（可以用来记点东西。）",
		"action": "read_item",
	},
	"pen": {
		"name": "中性笔",
		"kind": "material",
		"scope": SCOPE_COLLEGE,
		"desc": "黑色 0.5。大学四年丢掉的笔，大概能铺满一张课桌。",
		"action": "read_item",
	},
	"tissue": {
		"name": "抽纸",
		"kind": "material",
		"scope": SCOPE_COLLEGE,
		"desc": "一提三包的抽纸。宿舍里最容易被借走、也最容易被忘记还的东西。",
		"action": "read_item",
	},
	"postcard": {
		"name": "旧明信片",
		"kind": "clue",
		"scope": SCOPE_COLLEGE,
		"desc": "印着学校北门牌坊的明信片，背面空白，边角有点卷。\n（不知道是谁塞在货架最里层的。）",
		"action": "read_item",
		"droppable": false,
	},
	# 剧情道具（`01_GOALS.md` 后半段）：晚间去照相馆取的、一周前送去洗的那卷照片。
	# ⚠️ `unique` + `droppable=false`：它是剧情钥匙，丢了/重复了都会让后面的链子断掉。
	"photo_print": {
		"name": "洗好的照片",
		"kind": "clue",
		"scope": SCOPE_COLLEGE,
		"desc": "照相馆的牛皮纸信封，里面是一小摞照片。\n楼下的猫、食堂的窗口、下雨的操场……全是他一个人拍的。\n最后一张上并排站着两个人。",
		"action": "read_item",
		"droppable": false,
		"unique": true,
		"prompt": "取走洗好的照片",
		"pickup_line": "信封上用圆珠笔写着他的姓。",
	},
	# 钱：虚拟条目，数量 = 钱包余额（见 WALLET_ID 的注释）。
	# 它**不可用、不可丢**，也不会被 Inventory.add/remove 碰到。
	WALLET_ID: {
		"name": "钱",
		"kind": "money",
		"scope": SCOPE_COLLEGE,
		"desc": "出门前我妈塞给我的生活费，还有打工挣的。\n买东西、坐车、请人吃饭，都靠它。",
		"droppable": false,
		"unique": true,
	},
}


static func has_item(id: String) -> bool:
	return ITEMS.has(id) or FightEquipmentData.CONSUMABLES.has(id)


## 取道具定义；未登记时返回空字典（调用方用 display_name 兜底显示 id）
static func get_item(id: String) -> Dictionary:
	if FightEquipmentData.CONSUMABLES.has(id): return FightEquipmentData.item(id)
	if not ITEMS.has(id):
		return {}
	return ITEMS[id]


static func display_name(id: String) -> String:
	var def := get_item(id)
	return String(def.get("name", id))


static func description(id: String) -> String:
	if FightEquipmentData.CONSUMABLES.has(id): return FightEquipmentData.description(id)
	return String(get_item(id).get("desc", ""))


static func kind_name(id: String) -> String:
	var kind := String(get_item(id).get("kind", ""))
	return String(KIND_NAMES.get(kind, kind))


static func scope_of(id: String) -> String:
	return String(get_item(id).get("scope", SCOPE_COLLEGE))


static func action_of(id: String) -> String:
	return String(get_item(id).get("action", ""))


static func is_usable(id: String) -> bool:
	return action_of(id) != ""


static func can_drop(id: String) -> bool:
	return bool(get_item(id).get("droppable", true))


## 唯一道具：背包里已经有一件时，Inventory.add 会拒收第二件（防复制）
static func is_unique(id: String) -> bool:
	return bool(get_item(id).get("unique", false))


static func pickup_prompt(id: String) -> String:
	var prompt := String(get_item(id).get("prompt", ""))
	if prompt != "":
		return prompt
	return "捡起%s" % display_name(id)


static func pickup_line(id: String) -> String:
	return String(get_item(id).get("pickup_line", ""))


## 图标纹理；没有素材时返回 null（UI 会自动退回占位色块 —— 素材没到位不该崩）
static func icon(id: String) -> Texture2D:
	var path := String(get_item(id).get("icon", ""))
	if path == "":
		path = ICON_DIR + id + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 登记的 id 列表（稳定排序，UI 与走查都用它，保证顺序可预期）
static func ids() -> Array:
	var out: Array = ITEMS.keys() + FightEquipmentData.CONSUMABLES.keys()
	out.sort()
	return out


# ---------------------------------------------------------------- 金钱（虚拟条目）


## 这个 id 是不是"钱包"那条虚拟道具
static func is_wallet(id: String) -> bool:
	return id == WALLET_ID


## 这个 id 的数量是不是**实时**的（不来自 GameState.inventories）。
## UI（背包面板）据此决定"数量问谁要"：普通道具问 Inventory，钱包问 Currency。
## 把这条判断收在这里，是为了让"哪些道具是虚拟的"只有一个出处。
static func is_virtual(id: String) -> bool:
	return is_wallet(id)


## 虚拟道具当前的显示数量（普通道具返回 -1 = "不是虚拟的，去问 Inventory"）
static func virtual_count(id: String) -> int:
	if is_wallet(id):
		return Currency.amount(scope_of(id))
	return -1
