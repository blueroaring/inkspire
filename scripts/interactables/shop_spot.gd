class_name ShopSpot
extends Interactable
## 商店入口（地图上"按 E 买东西"的那个交互区）。
##
## 职责边界：只做三件事 —— 报出商店 id、播一句进店话、把面板打开。
## 卖什么 / 多少钱在 `ShopDb`，钱怎么扣在 `Currency`，界面在 `ShopPanel`。
## 所以同一个脚本可以挂在任何建筑门前：换一家店只改数据里的 `shop_id`。
##
## 节点由场景脚本按数据建出来（见 `campus.gd::_build_shops()`），走查按
## 节点名 `Shop_<id>` 找它。
##
## ⚠️ 2026-09-20 起它**也能挂在街具上**：08 要的"自动售货机的购买交互"就是
##    `campus.gd::_build_prop_interact()` 在一台自动售货机的位置建一个本脚本
##    （`ShopDb.campus_vending`，比教育超市贵三成）。

## `ShopDb.SHOPS` 里的商店 id
@export var shop_id: String = ""

## 进店第一句（空 = 不播，直接开面板）
@export var greeting: String = ""

## 店员名（说话人；空则用 ShopDb 里登记的）
@export var clerk: String = ""

## 进店话之后要不要让艾莉娜插一句（见 `AlyinaBanter`）。
##
## ⚠️ 只有**街具上的商店**（自动售货机）会开它：08 里她那句
##    "我发现自动售货机卖的饮品价格普遍比教育超市贵唉"是冲着这台机器说的。
##    楼门口的店（教育超市/复印店）有自己的店员，接一段她的话反而抢戏。
@export var banter: bool = false


func _ready() -> void:
	if custom_prompt == "":
		custom_prompt = "在%s买东西" % ShopDb.shop_name(shop_id)
	super._ready()


func _interact() -> void:
	if not ShopDb.has_shop(shop_id):
		push_warning("ShopSpot: 未登记的商店 '%s'（节点 %s）" % [shop_id, name])
		return
	var was_moving := begin_dialogue_lock()
	var line := greeting if greeting != "" else ShopDb.greeting_of(shop_id)
	var lines: Array = []
	if line != "":
		var speaker := clerk if clerk != "" else ShopDb.clerk_of(shop_id)
		# 进店话也能被对话补丁覆盖（id `shop.greeting.<商店 id>`）
		lines = DialoguePatch.apply("shop.greeting.%s" % shop_id,
				[{"speaker": speaker, "text": line}])
	# "鬼才的赚钱方式"那句：它是这台机器的**风味文案**，与进店话分开（售货机没有店员）
	if banter:
		lines = AlyinaBanter.with_banter(object_kind, lines)
	if not lines.is_empty():
		await DialogueBox.play_script(lines)
	end_dialogue_lock(was_moving)
	# 面板自己管输入（ESC / 「离开」关闭），所以这里不做额外的锁
	Shop.open(shop_id)
	# 打开当帧就抢输入焦点：玩家刚按完 E，紧接着的↑↓/回车应该落在面板上
	await get_tree().process_frame
	if Shop.is_open() and Shop.panel_rect().size.x > 0.0:
		Shop.debug_focus_first()


## 供走查断言"这个交互区指向的商店真的存在"
func is_valid_shop() -> bool:
	return ShopDb.has_shop(shop_id)
