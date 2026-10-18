extends Node
## 背包系统（自动加载单例 Inventory）
##
## 职责很窄：只管"哪一册背包里有什么"的增删查，以及把"使用"转发给 ItemActions。
## 它**不认识 UI**（背包面板是 `Backpack` 单例）、**不认识场景**（地图上的拾取物是
## `ItemPickup`）、**不认识对话与剧情**（那些在 `ItemActions` 里）。
##
## 数据落在 `GameState.inventories` 里（纯字典，跟着存档走），
## 所以存档/读档不需要为背包写任何额外代码。
##
## 分册（scope）：大学（college）与高中（highschool）各一册，互不影响。
## 当前该操作哪一册由 `GameState.current_bag_scope()` 按章节推出来；
## 所有 API 都能显式传 scope，方便走查与将来的跨册操作。

## 单格上限（超过就提示"装不下了"）
const MAX_STACK := 99

signal item_added(id: String, count: int, scope: String)
signal item_removed(id: String, count: int, scope: String)
signal bag_changed(scope: String)
signal item_used(id: String, scope: String, ok: bool)


# ---------------------------------------------------------------- 查询

## 当前分册（大学 / 高中）
func scope() -> String:
	return GameState.current_bag_scope()


func scope_name(target: String = "") -> String:
	return GameState.bag_scope_name(target if target != "" else scope())


## 某一册的原始字典 {id: count}（**不要直接改它**，走 add/remove 才会发信号）
func bag(target: String = "") -> Dictionary:
	var key := target if target != "" else scope()
	var store: Dictionary = GameState.inventories.get(key, {})
	return store


func count(id: String, target: String = "") -> int:
	return int(bag(target).get(id, 0))


func has(id: String, amount: int = 1, target: String = "") -> bool:
	return count(id, target) >= amount


func is_empty(target: String = "") -> bool:
	return bag(target).is_empty()


## 这一册能不能再收下 [param amount] 个（不真的放进去）。
## 用途：**买东西之前先问一句** —— 付费成功但背包满了，就成了"花了钱没拿到货"。
## 与 add() 共用同一套上限/唯一道具判定，所以两边的结论永远一致。
func can_accept(id: String, amount: int = 1, target: String = "") -> bool:
	if id == "" or amount <= 0:
		return false
	var current := count(id, target)
	if current > 0 and ItemDb.is_unique(id):
		return false
	return current + amount <= MAX_STACK


func distinct_count(target: String = "") -> int:
	return bag(target).size()


func total_count(target: String = "") -> int:
	var total := 0
	for value in bag(target).values():
		total += int(value)
	return total


## 某一册的内容（按 ItemDb.ids() 的稳定顺序；未登记的道具排在最后）
func entries(target: String = "") -> Array[Dictionary]:
	var store := bag(target)
	var out: Array[Dictionary] = []
	for id: String in ItemDb.ids():
		if store.has(id):
			out.append({"id": id, "count": int(store[id])})
	for id: String in store.keys():
		if not ItemDb.has_item(id):
			out.append({"id": id, "count": int(store[id])})
	return out


# ---------------------------------------------------------------- 增删

## 放进背包；返回**实际**放进去了多少（0 = 没放进去，例如已满或 id 为空）
func add(id: String, amount: int = 1, target: String = "") -> int:
	if id == "" or amount <= 0:
		return 0
	var key := target if target != "" else scope()
	var store: Dictionary = GameState.inventories.get(key, {})
	var current := int(store.get(id, 0))
	# 唯一道具（手机、钥匙这类）：已经有一件就不再收第二件 ——
	# 这是"场景里的东西被复制"这类问题的最后一道保险。
	if current > 0 and ItemDb.is_unique(id):
		return 0
	var room: int = maxi(0, MAX_STACK - current)
	var added: int = mini(amount, room)
	if added <= 0:
		return 0
	store[id] = current + added
	GameState.inventories[key] = store
	item_added.emit(id, added, key)
	bag_changed.emit(key)
	return added


## 取出；数量不足时**什么都不做**并返回 false（避免"扣成负数"这类隐性 bug）
func remove(id: String, amount: int = 1, target: String = "") -> bool:
	if id == "" or amount <= 0:
		return false
	var key := target if target != "" else scope()
	var store: Dictionary = GameState.inventories.get(key, {})
	var current := int(store.get(id, 0))
	if current < amount:
		return false
	var left := current - amount
	if left <= 0:
		store.erase(id)
	else:
		store[id] = left
	GameState.inventories[key] = store
	item_removed.emit(id, amount, key)
	bag_changed.emit(key)
	return true


## 清空某一册（读档/调试用）
func clear(target: String = "") -> void:
	var key := target if target != "" else scope()
	GameState.inventories.erase(key)
	bag_changed.emit(key)


# ---------------------------------------------------------------- 使用

## 使用一件道具。真正的效果在 ItemActions 里；
## 返回 false 表示"这件东西现在用不了"（UI 据此给提示，不消耗）。
func use(id: String, target: String = "") -> bool:
	var key := target if target != "" else scope()
	if not has(id, 1, key):
		return false
	var action := ItemDb.action_of(id)
	if action == "":
		item_used.emit(id, key, false)
		return false
	var ok: bool = await ItemActions.run(action, id)
	item_used.emit(id, key, ok)
	return ok


# ---------------------------------------------------------------- 开发期驱动接口

## 直接塞一件道具（走查/调试用，等价于"捡到了"）
func debug_give(id: String, amount: int = 1, target: String = "") -> int:
	return add(id, amount, target)
