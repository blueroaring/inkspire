class_name ShopDb
extends RefCounted
## 商店与价目表（**纯数据**，不碰节点、不碰 UI、不碰钱）。
##
## 为什么单独一个文件：`ItemDb` 回答"这件东西是什么"，
## 而"它在哪家店、卖多少钱、有没有货"是**市场**的事，不该塞进道具表里
## （同一个笔记本在大学卖 3 块、在高中门口卖 5 块，那是两个市场的差价，不是道具的属性）。
##
## 分工：
##   `ItemDb`   道具是什么（名字/描述/图标/效果）
##   `ShopDb`   哪家店卖哪些道具、卖多少钱（本文件）
##   `Currency` 钱怎么加减、买不买得起
##   `ShopPanel` 怎么摆界面、点了买之后调 `Currency.spend` + `Inventory.add`
##
## 加一件商品 = ItemDb 加一条（没有的话）+ 这里 `ITEMS` 加个价 + 挂到某家店的 `stock`。
## 加一家店   = 这里 `SHOPS` 加一段 + 在场景数据里指到这个 shop id（见 CampusData.shops()）。

## 价钱一律用**分**（int），与 `Currency` 的口径一致：浮点数进 JSON 会变成 39.999999，
## 而"买得起吗"必须精确。
const ITEMS := {
	"tissue":       180,    # 1.80
	"pen":          300,    # 3.00
	"notebook":     450,    # 4.50
	"energy_drink": 650,    # 6.50
	"postcard":     250,    # 2.50
}

## 商店表：id -> {name, clerk, greeting, stock}
##   clerk    店员名（对话里的说话人；""=旁白）
##   greeting 进店第一句（旁白/店员都行）
##   stock    在售的道具 id 列表（顺序即列表顺序）
const SHOPS := {
	"campus_supermarket": {
		"name": "教育超市",
		"clerk": "收银台后的阿姨",
		# 收银台这一句同时兼任经济系统的教学：告诉玩家钱从哪来（食堂/复印店能打工）
		"greeting": "货架上的东西都能拿，先看价钱。手头紧就去食堂帮工，一个钟头四十。",
		"stock": ["tissue", "pen", "notebook", "energy_drink", "postcard"],
	},
	"campus_photo": {
		"name": "照相馆 · 复印店",
		"clerk": "复印店老板",
		"greeting": "复印两毛一张，装订另算。要买什么自己看。",
		"stock": ["pen", "notebook"],
	},
	# 08 定稿："加入公告牌和自动售货机的交互文本和**自动售货机的购买交互**"。
	# ⚠️ 它是**真的能买**的商店（不是一句台词）：只卖喝的，而且比教育超市贵 ——
	#    这正好是艾莉娜那句"我发现自动售货机卖的饮品价格普遍比教育超市贵唉"的依据。
	"campus_vending": {
		"name": "自动售货机",
		"clerk": "",
		"greeting": "",
		# 比教育超市贵三成 —— 艾莉娜那句吐槽就是冲着这个差价说的
		"markup": 1.3,
		"stock": ["energy_drink"],
	},
}


static func has_shop(shop_id: String) -> bool:
	return SHOPS.has(shop_id)


static func shop(shop_id: String) -> Dictionary:
	return SHOPS.get(shop_id, {})


static func shop_name(shop_id: String) -> String:
	return String(shop(shop_id).get("name", shop_id))


static func clerk_of(shop_id: String) -> String:
	return String(shop(shop_id).get("clerk", ""))


static func greeting_of(shop_id: String) -> String:
	return String(shop(shop_id).get("greeting", ""))


## 在售列表（已过滤掉没登记价钱的：宁可不显示，也别让"￥0.00"混进去）
static func stock_of(shop_id: String) -> Array:
	var out: Array = []
	for id_variant in shop(shop_id).get("stock", []):
		var id := String(id_variant)
		if ITEMS.has(id) and ItemDb.has_item(id):
			out.append(id)
	return out


## 价钱（分）；没登记返回 -1（调用方据此判定"这东西不卖"）。
##
## [param shop_id] **同一件东西在不同店可以不同价** —— 08 里艾莉娜那句
##   "我发现自动售货机卖的饮品价格普遍比教育超市贵唉"要成立，就得真的贵一点。
##   所以价格规则分两层：
##     · `ITEMS` 是**基准价**（大学这一册的行情）；
##     · 某家店可以带 `markup`（倍率，1.3 = 贵三成）—— 售货机就是靠它比超市贵。
##   ⚠️ 别把"贵"做进 `ITEMS`：那是道具的**市场均价**，
##      改它会连带改掉教育超市的价（一台机器贵不该让整条街都贵）。
static func price_of(item_id: String, shop_id: String = "") -> int:
	var base := int(ITEMS.get(item_id, -1))
	if base < 0:
		return -1
	if shop_id == "":
		return base
	# 四舍五入到分：倍率乘积出现 8.449999 时不能截断成 8.44
	return int(round(float(base) * float(shop(shop_id).get("markup", 1.0))))


static func is_sold(item_id: String) -> bool:
	return ITEMS.has(item_id)


## 全部在售道具 id（走查断言"卖的东西都登记过"用）
static func item_ids() -> Array:
	var out: Array = ITEMS.keys()
	out.sort()
	return out


## 商店 id 列表（稳定排序）
static func shop_ids() -> Array:
	var out: Array = SHOPS.keys()
	out.sort()
	return out
