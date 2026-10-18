class_name SitSpot
extends Interactable
## **可坐的地方**（长椅、食堂凳子……）：按 E 坐下 / 再按 E 站起来。
##
## 2026-09-20 从 `BenchSpot` 抽出来（用户要求："这个坐顺便用于在食堂的凳子坐"）。
## 抽之前 `BenchSpot` 里那套逻辑与"长椅"没有半点关系 —— 它管的全是**座位状态**：
##   ① 同一个交互点的提示词（"坐下" ↔ "站起来"）；
##   ② 别的座位在这种情况下也能把人叫起来（不然在 A 坐下、走到 B 按 E 会又"坐下"一次）；
##   ③ 这个状态要**进存档**（离开场景再回来，人还坐在那儿）。
## 所以它本来就是个通用件，只是名字叫成了长椅。现在名字归位：
##   `SitSpot`（通用） + `BenchSpot`（长椅，只负责补默认提示词/物件名）。
##
## ⚠️ 状态存在 `story_flags`（跟着存档走）而不是节点上的 `_used`：
##    座位是**每次进场景现建**的，节点级状态一换场景就没了（这条坑撞过很多次）。
##    键由场景脚本给（`seat_key`），要求**唯一且稳定**（`bench.<区>.<序号>` /
##    `canteen.seat.<i>`）。
## ⚠️ "现在坐在哪"是**全局唯一**的，但每个座位是独立节点 —— 所以这里维护一张
##    **本进程见过的座位键**表（`_known_seats`），用"那张键还开着吗"反查当前座位
##    （`GameState` 里存的就是普通开关，不额外加一个"走查要遍历"的数组）。
## ⚠️ 坐着时**只锁移动、保留交互**（`set_movement_enabled(false)`，不是
##    `set_control_enabled(false)`）：后者会连交互一起锁死 —— 而"站起来"
##    正是靠交互触发的，那样就彻底坐死在椅子上了。

const SEAT_PREFIX := "bench."

## 本进程见过的座位键（键 -> true）。用来反查"现在坐在哪张椅子上"。
static var _known_seats: Dictionary = {}

## ⚠️ 坐着时**不再压 z**（老实现会把整个人藏到椅子后面）。
##
## 老代码把 sprite 的 `z_index` 压到 -6，本意是"人陷进椅子里"—— 那是在**没有坐姿素材**、
## 人物还是站着那一帧的年代的糊弄办法。现在有真坐姿帧了，压 z 只会让**整个角色**
## 被长椅挡住（连同坐姿一起消失）。所以这里不再碰 z：让 y 排序按脚底正常决定前后 ——
## 玩家坐在座位点上（脚底在椅子前沿），y 比椅子大 ⇒ 画在椅子之上，正是想要的。
##
## 坐下时的默认朝向。
##
## ⚠️ **不要用"玩家走到座位前那一刻的朝向"**：那取决于最后一步往哪走，
##    于是同一张长椅会随机出现"面朝下"或"背对镜头"。座位自己知道该朝哪边。
##    长椅：面朝下（背靠椅背、面向镜头）—— 与坐姿素材的第一行对应。
const SIT_FACING := Vector2.DOWN

## 坐下时**整条家具换成哪张图**（人 + 家具一体的成品；空串 = 不换图）。
##
## ⚠️ 这是 2026-09-20 用户定的做法："坐的时候替换为这个图，站的时候恢复正常的长椅图"。
##    为什么不再"把玩家角色叠到空家具上"：坐姿素材在 96x48 的长椅旁边只有约 36px 高，
##    而长椅座面本身就有 17px 厚 —— 四档偏移都不像（`screenshots/35_坐长椅_偏移对比.png`）。
##    换图这条路**没有对齐问题**：两条图共用同一个 root（占地下沿），落地线天然一致。
##
## ⚠️ 换图之后必须把玩家自己的立绘**藏起来**，否则图里的人和玩家会变成两个。
@export var sit_texture: String = ""

## 坐下时人物**相对座位点**的像素偏移（默认"不动"）。
##
## 坐姿素材自带一条坐凳（画在人物臀部下面），而座位点是长椅/凳子的**前沿**；
## 理论上可以用这个偏移把两者对齐，但**实际别乱动**：
##
## ⚠️ 校园里角色与道具的前后关系靠 **y 排序**（脚底 y 比大小）。
##    把人往上抬（负 y）会让他排到长椅**前面** —— 整条腿被椅子挡住，
##    实测用户实报"人坐在了长椅后面"。所以这里保持 0：
##    座面那点高度差（实测约 9px）远比"被椅子挡住"轻得多。
## ⚠️ 真要调也必须 ≤ 0 以外的小幅正数（往下），而且要连同 y 排序一起想清楚。
@export var sit_offset: Vector2 = Vector2.ZERO

## 站起来时相对交互点的落点偏移。
## 长椅的交互点在占地中线偏后（北侧），如果直接留在这里，玩家恢复立绘后
## 会被椅子挡住。长椅由 `BenchSpot` 提供朝南的前方偏移；普通座位默认不偏移。
@export var stand_offset: Vector2 = Vector2.ZERO

## 坐下/站起来那两句旁白（措辞在数据里）
@export var sit_lines: Array = []
@export var stand_lines: Array = []

## 存档里那条键（由场景脚本按"区 + 序号"给，保证唯一且稳定）
@export var seat_key: String = ""

## 补丁 id（对话编辑器按 `campus.<区>.bench.<i>.sit` / `.stand` 登记）
@export var dialogue_id: String = ""

## 坐下时的默认提示词（长椅是"在长椅上坐下"，食堂凳子由场景改成"在凳子上坐下"）
@export var sit_prompt: String = "坐下"
@export var stand_prompt: String = "站起来"
## 默认物件名（自检/日志里显示成"坐在什么上"）
@export var seat_kind: String = "座位"


static func forget_known_seats() -> void:
	## 走查用：场景重来时清掉"见过哪些座位"，避免上一条用例的残留影响判断
	_known_seats.clear()


func _ready() -> void:
	if custom_prompt == "":
		custom_prompt = sit_prompt
	if object_kind == "物件":
		object_kind = seat_kind
	if seat_key != "":
		_known_seats[seat_key] = true
	super._ready()


## 提示词随"我是不是正坐在这张座位上"变
func get_prompt() -> String:
	if _is_sitting_here():
		return stand_prompt
	return super.get_prompt()


## 坐着的时候**这张座位**永远排在前面（否则站起来要多按一次 Tab）
func interaction_priority() -> int:
	return 12 if _is_sitting_here() else 0


func _interact() -> void:
	# 两种情况：
	#   ① 正坐在这张座位上（或别的座位上）→ 站起来；
	#   ② 没坐着 → 坐下。
	if _is_sitting_here() or _sitting_seat() != "":
		await _stand_up()
		return
	await _sit_down()


func _sit_down() -> void:
	var player := get_player()
	if player == null or seat_key == "":
		return
	# ⚠️ 只锁移动、保留交互：站起来还要靠按 E（见文件头最后一条）。
	if player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", false)
	GameState.set_flag(seat_key, true)
	# 视觉上往座位中心靠一点；
	# 有坐姿立绘的（`ActorSprite` 侧）同时切成坐姿帧 —— 没有素材时那一步是空操作。
	(player as Node2D).global_position = global_position + sit_offset
	if player.has_method("set_sitting"):
		player.call("set_sitting", true, SIT_FACING)
	_apply_seat_art(true)
	if not sit_lines.is_empty():
		await DialogueBox.play_script(
				DialoguePatch.apply("%s.sit" % dialogue_id, sit_lines))


func _stand_up() -> void:
	var player := get_player()
	GameState.set_flag(_sitting_seat(), false)
	if player != null:
		if player.has_method("set_movement_enabled"):
			player.call("set_movement_enabled", true)
		if player.has_method("set_sitting"):
			player.call("set_sitting", false)
		# 先把玩家放到座位前方，再显示立绘；否则站起的一帧会出现在椅背后，
		# 之后即使玩家能走开，视觉上仍像是从椅子里面站出来。
		if stand_offset != Vector2.ZERO:
			(player as Node2D).global_position = global_position + stand_offset
	_apply_seat_art(false)
	if not stand_lines.is_empty():
		await DialogueBox.play_script(
				DialoguePatch.apply("%s.stand" % dialogue_id, stand_lines))


# ---------------------------------------------------------------- 换图（坐下/站起来）
#
# 见 `sit_texture` 的说明：坐下时整条家具换成"人 + 家具"的成品图、站起来换回空家具。
#
# ⚠️ 两张图是 `tile_room.place_prop()` 在**同一个 root** 下建的两兄弟
#    （`Sprite` = 空家具 / `AltSprite` = 带人的），共用"占地下沿中点"这条基线，
#    所以互换时落地线不动 —— 这是"换图"能替代"对齐偏移"的根本原因。
# ⚠️ 记录要从 `prop_records()` 里**按占地下沿反查**：座位节点自己不持有那两条精灵
#    （它在建家具之后才由场景脚本摆上来，见 `campus.gd::_build_prop_interact`）。
#    反查用"同一格 + 最近"两个条件，因为它和家具根节点的坐标是同一个点。


## 找到"我这张座位所对应的那件家具"的精灵记录（找不到返回空字典）
##
## ⚠️ 认"地图节点"要用 `has_method("prop_records")` 而不是 `get("prop_records")`：
##    后者拿到的是**方法引用（Callable）**，迭代它会报
##    `Unable to iterate on object of type 'Callable'`（实测踩过）。
func _seat_record() -> Dictionary:
	var map: Node = get_parent()
	while map != null and not map.has_method("prop_records"):
		map = map.get_parent()
	if map == null:
		return {}
	var mine := global_position
	var best := {}
	var best_d := 48.0   # 半格多一点：座位点与家具 root 就是同一个点，超过这个距离肯定不是它
	for record_variant in map.call("prop_records"):
		var record: Dictionary = record_variant
		if String(record.get("kind", "")) != "bench":
			continue
		var visual: Rect2 = record.get("visual", Rect2())
		var base := Vector2(visual.get_center().x, visual.end.y)
		var d := base.distance_to(mine)
		if d < best_d:
			best_d = d
			best = record
	return best


## 把"空家具 ↔ 带人的家具"两张图切成该显示的那一张。
##
## [param sitting] = true 表示现在坐下了。
##
## ⚠️ **只对给了 `sit_texture` 的座位做事**：没给的话两张图里的备用图压根没建
##    （`alt_sprite == null`），这时保持"角色叠在家具上"的老行为，什么都不用改。
func _apply_seat_art(sitting: bool) -> void:
	if sit_texture == "":
		return
	var record := _seat_record()
	if record.is_empty():
		push_warning("座位 '%s' 找不到对应的家具记录，坐下时不换图" % seat_key)
		return
	var main_sprite := record.get("main_sprite") as Sprite2D
	var alt_sprite := record.get("alt_sprite") as Sprite2D
	if alt_sprite == null:
		# 备用图没建出来（素材缺失之类）——退回老行为，别把主图藏了就什么都不剩
		push_warning("座位 '%s' 没有备用图（%s），继续用玩家立绘" % [seat_key, sit_texture])
		return
	if main_sprite != null:
		main_sprite.visible = not sitting
	alt_sprite.visible = sitting
	# ⚠️ 带人的那张图里**已经画了坐着的人**，所以要把玩家自己的立绘藏起来。
	#    不藏就是"两个人"（一个在图里、一个叠在上面）。
	var player := get_player()
	if player != null and player.has_method("set_avatar_visible"):
		player.call("set_avatar_visible", not sitting)


## 我这张座位是不是"当前坐着的那张"
func _is_sitting_here() -> bool:
	return seat_key != "" and GameState.get_flag(seat_key, false)


## 现在坐在哪张座位上（没坐返回空串）
func _sitting_seat() -> String:
	for key_variant in _known_seats:
		var key := String(key_variant)
		if GameState.get_flag(key, false):
			return key
	return ""


# ---------------------------------------------------------------- 走查用
#
# ⚠️ 这三条是**给自检**的：座位的"坐着"是玩家可见的长期状态，
#    只读节点属性判断不出来（`can_move` 会被剧情锁干扰），所以由本节点自己回答。

## 现在坐在座位上吗
func is_sitting() -> bool:
	return _sitting_seat() != ""


## 我是被坐着的那张吗
func is_sitting_here() -> bool:
	return _is_sitting_here()


## 坐/站两句台词（自检断言"这两段真的配上了"）
func has_lines() -> bool:
	return not sit_lines.is_empty() and not stand_lines.is_empty()
