class_name Player
extends ActorPlaceholder
## 玩家角色（周明远）。
##
## 职责：像素级自由移动、朝向、探测可交互物并交互。
## 交互探测用 Area2D（InteractionProbe），因为地图上可交互物是各种形状的区域，
## 用"范围重叠 + 距离排序"比射线更省事，也更好加"最近优先"。
##
## 碰撞层掩码见 scripts/layers.gd：InteractionProbe 的 mask 必须是
## ACTORS | INTERACTABLE（= 6），只写 INTERACTABLE（= 4）会探不到 NPC。
##
## 场景接入约定：节点必须放进 "player" 组，否则 SceneRouter 找不到它。

const SPEED := 220.0
const ACCEL := 2400.0
const FRICTION := 2600.0

## 场景可以按世界尺寸调整移动速度；普通场景仍使用 220px/s。
var movement_speed: float = SPEED

## 交互探测半径（与 player.tscn 里 InteractionProbe 的碰撞形状半径保持一致）。
## 用户三次要求收紧 → 44 → 30 → 22 → **12**，最后一次的要求是
## "碰撞箱碰到了再显示交互"：玩家身体半径 8，所以 12 ≈ 身体边缘再放宽 4px。
## 命中条件是"探测圆与物件自身交互区**相交**"（不是包含），
## 所以物件自己的交互区才是手感的主要来源（家具=占地、门=往房间内一点点）。
## ⚠️ 只有手机拾取物例外：它自带很大的半径（见 dorm.gd 的 PICKUP_RADIUS），
##    否则开场"锁着移动"时够不到手机就是硬卡死。
const PROBE_RADIUS := 12.0

## 落地后强制刷新交互候选的帧数。
## 为什么需要：切场景时玩家是被"摆"到出生点的，那一刻物理空间刚建好，
## Area2D 的进出信号还没派发，若玩家原地不动就永远拿不到候选 ——
## 表现就是"站在物件上按 E 没反应"。头几帧每帧主动查一次即可覆盖这个窗口。
const SPAWN_REFRESH_FRAMES := 5
var _spawn_refresh_left := SPAWN_REFRESH_FRAMES

## 稳定期的候选刷新间隔（物理帧）。
##
## ⚠️ 这里必须**定时重查**，不能只靠 `InteractionProbe` 的进出信号（2026-09-19 用户实报：
##    "发现了新交互但不点击，移动时也没捕捉到新交互，于是脱离了范围还一直可交互"）。
##    根因：`_refresh_candidates()` 原来只在 `area_entered/area_exited` 与"候选里有已释放实例"时才跑，
##    而 Area2D 的进出信号是**物理步进里派发的事件**，与"探测圆此刻是否真的相交"并不同步：
##      · 探测半径 12px 很小，快速走动时可能整段重叠都发生在两次物理步之间；
##      · 交互物的判定区往往比它看起来小（或反过来包住玩家），进出与视觉范围不一致；
##      · 玩家被传送 / 物件被挪走时也不一定有 exited 事件。
##    一旦漏掉一次 exited，`_candidates` 里就一直留着那件东西 → `_target` 不变 → 提示框一直挂着。
##    实测：每 2 个物理帧重查一次（60fps 下 30Hz）已经跟手，且 `intersect_shape` 的代价可忽略。
const REFRESH_EVERY_PHYSICS_FRAMES := 2
var _refresh_countdown := 0

var can_move: bool = true
## 可选的场景级可行走判定。普通校园/室内场景不设置时保持原有物理行为；
## 废弃校园会把道路和桥的白名单传进来，避免角色走上草地或水面。
var walkable_test: Callable = Callable()
## 可旋转场景把屏幕方向换回原来的地面坐标；其他场景保持默认输入。
var movement_direction_transform: Callable = Callable()
## 交互总开关。与 can_move 分开：剧情锁移动时玩家仍然应该能交互（例如开场看手机）。
## 一般由对话/交互物在"锁住操作"时置位，避免交互被打断或重复触发。
var _interaction_locked: bool = false

var _probe: Area2D
var _prompt: Label
var _candidates: Array[Node] = []
var _target: Node = null


func _ready() -> void:
	add_to_group("player")
	body_color = Palette.PLAYER_BODY
	head_color = Palette.PLAYER_HEAD
	super._ready()

	_probe = get_node_or_null("InteractionProbe") as Area2D
	if _probe == null:
		push_warning("Player: 缺少 InteractionProbe 节点，无法交互。")
	else:
		_probe.area_entered.connect(_on_probe_changed)
		_probe.area_exited.connect(_on_probe_changed)
		_probe.body_entered.connect(_on_probe_changed)
		_probe.body_exited.connect(_on_probe_changed)

	# 交互提示框住在 HUD（画布空间）里，延后一帧解析：
	# 兄弟节点 Hud 的 _ready 还没跑（它要先把自己加进 overworld_hud 组、再建出 Prompt 节点）。
	_resolve_prompt.call_deferred()

	# 关键：物理重叠的 area_entered 信号依赖于"状态变化"，
	# 而玩家出生时若**本来就站在交互区里**、之后又不动，就永远没有进出事件，
	# _target 会一直是空 —— 表现就是"站着不动按 E 没反应"（真实踩过）。
	# 所以等第一帧物理步进跑完，主动刷新一次候选。
	_refresh_candidates.call_deferred()


## 解析交互提示框（Player 只管写文字与显隐，位置由 HUD 每帧跟着头顶算）。
##
## ⚠️ 它**不在玩家节点下**了：世界空间的 Label 会被相机缩放放大 ——
## 实测同一句提示在校园 15px、宿舍 46px、卫生间 63px（用户实报"卫生间交互字太大"）。
## 先找 HUD，找不到才退回旧写法（保持对老场景的兼容）。
func _resolve_prompt() -> void:
	_prompt = get_node_or_null("Prompt") as Label
	if _prompt == null:
		var hud := get_tree().get_first_node_in_group("overworld_hud")
		if hud != null:
			_prompt = hud.get_node_or_null("Prompt") as Label
	if _prompt != null:
		_prompt.visible = false


func _physics_process(delta: float) -> void:
	# 落地头几帧持续刷新候选，避免"被摆到出生点后原地不动就按不动"（见常量注释）
	if _spawn_refresh_left > 0:
		_spawn_refresh_left -= 1
		_refresh_candidates()
	else:
		# 稳定期：**定时重查**，不依赖 Area2D 的进出信号（见 REFRESH_EVERY_PHYSICS_FRAMES 的说明）。
		# 这一条同时修掉"脱离范围了提示还挂着"和"走到新交互物旁边没反应"两个方向的问题。
		_refresh_countdown -= 1
		if _refresh_countdown <= 0:
			_refresh_countdown = REFRESH_EVERY_PHYSICS_FRAMES
			_refresh_candidates()

	# 目标/候选中出现"已释放实例"时的兜底刷新（每帧一次，极便宜）。
	# ⚠️ 不能只看 _target：拾取物消失时会 set_deferred("monitoring", false)，
	#    玩家**收不到 area_exited**，_candidates 里会留下已释放的实例 ——
	#    结果是提示框永远挂着"捡起手机"，调试打印还会因为把死对象传给类型化参数而报错。
	if _has_dead_candidate():
		_refresh_candidates()
	# 提示框自愈：只要当前没有目标，就绝不能留着上一句提示文字
	if _prompt != null and _prompt.visible and _target == null:
		_prompt.visible = false

	var input_dir := Vector2.ZERO
	if can_move and not DialogueBox.is_active() and not Backpack.is_open() \
			and not Shop.is_open() and not PlateGame.is_active():
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if movement_direction_transform.is_valid():
			input_dir = movement_direction_transform.call(input_dir)

	var target_vel := input_dir * movement_speed
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(target_vel, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	# 可行走白名单只限制下一步位置，保留 CharacterBody2D 的正常滑动与
	# 建筑/树/河流实体碰撞。斜向撞到边界时先尝试单轴移动，避免把玩家
	# 粘死在道路边缘。
	if walkable_test.is_valid() and velocity.length_squared() > 0.0:
		var wanted := global_position + velocity * delta
		if not _is_walkable_position(wanted):
			var x_only := global_position + Vector2(velocity.x * delta, 0.0)
			var y_only := global_position + Vector2(0.0, velocity.y * delta)
			if _is_walkable_position(x_only):
				velocity.y = 0.0
			elif _is_walkable_position(y_only):
				velocity.x = 0.0
			else:
				velocity = Vector2.ZERO

	move_and_slide()
	_update_facing_from_velocity(velocity)


func set_walkable_test(test: Callable) -> void:
	walkable_test = test


func set_movement_speed(value: float) -> void:
	movement_speed = maxf(1.0, value)


func _is_walkable_position(at: Vector2) -> bool:
	if not walkable_test.is_valid():
		return true
	return bool(walkable_test.call(at))


func _unhandled_input(event: InputEvent) -> void:
	# 注意：这里**不能**用 can_move 把关。
	# 踩过的坑：开场"从床上醒来"时锁住了移动（can_move=false），当时把这个开关也用来拦交互，
	# 结果连唯一能解锁的手机都按不动 —— 玩家直接卡死在宿舍。
	# 移动与交互是两件事：锁移动（剧情约束）不等于禁止交互（玩家操作）。
	# 真正需要禁止交互的场景（例如正在播剧情）用 _interaction_locked。
	if _interaction_locked:
		return
	if DialogueBox.is_active():
		return
	# 背包打开时不许再触发地图交互：B 键由 Backpack 自己消费，
	# 但 E / Tab 会落到这里，不拦住的话会出现"面板开着还能捡东西/开门"。
	# 商店面板（E 打开、ESC 关闭）与打工小游戏（限时叠层）同理：它们自己吃输入，
	# 地图交互必须让位，否则小游戏里按数字键会同时触发旁边的工位/NPC。
	if Backpack.is_open() or Shop.is_open() or PlateGame.is_active():
		return
	if event.is_action_pressed("interact") and _target != null:
		_target.call("interact")
		get_viewport().set_input_as_handled()
		return
	# 附近有多个可交互物时，用 Tab 切换目标
	if event.is_action_pressed("cycle_target") and _candidates.size() > 1:
		_cycle_target()
		get_viewport().set_input_as_handled()


## 探测范围内可交互物变化
func _on_probe_changed(_node: Node) -> void:
	_refresh_candidates()


func _refresh_candidates() -> void:
	_candidates.clear()

	# 为什么用"直接物理空间查询"而不是 get_overlapping_areas()：
	# 后者返回的是**信号缓存**（只在进出事件时更新），玩家站着不动、或刚被传送进某个区域时
	# 可能还没刷新，表现就是"明明站在物件上，按 E 却没反应"（真实踩过）。
	# intersect_shape 是当场查询，任何时刻都反映真实重叠状态。
	var space := get_world_2d().direct_space_state
	if space != null:
		var params := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = PROBE_RADIUS
		params.shape = shape
		params.transform = Transform2D(0.0, global_position)
		params.collide_with_areas = true
		params.collide_with_bodies = true
		params.collision_mask = Layers.PROBE_MASK
		for hit in space.intersect_shape(params, 32):
			# 存**解析后**的交互节点：探到的可能只是它身上的 Area2D 子节点
			var target := _resolve_interactable(hit.get("collider") as Node)
			if target != null and not _candidates.has(target):
				_candidates.append(target)

	# 兜底：探测区自己报的重叠也一并收进来（覆盖查询漏掉的边缘情况）。
	# ⚠️ 必须先看 `monitoring`：`monitoring = false` 时 `get_overlapping_*()` 会**报错**
	#    （"Can't find overlapping areas when monitoring is off."）—— 拾取物消失时会走这条，
	#    实测刷出一屏红字。反正这种时候它也没有有效的重叠列表可报。
	if _probe != null and _probe.monitoring:
		for area in _probe.get_overlapping_areas():
			var t1 := _resolve_interactable(area)
			if t1 != null and not _candidates.has(t1):
				_candidates.append(t1)
		for body in _probe.get_overlapping_bodies():
			var t2 := _resolve_interactable(body)
			if t2 != null and not _candidates.has(t2):
				_candidates.append(t2)

	_update_target()


## 判断某个被探到的节点能否交互；**探不到就沿父链往上找**。
##
## 为什么需要向上找：NPC 的"可交谈区"是它下面的一个 Area2D 子节点，
## 而 interact() / get_prompt() 实现在 NPC（父节点）上。
## 探针探到的是 TalkArea，若只看它自己有没有 interact()，候选就是空的
## —— 表现是"站在室友旁边按 E 没反应"。
## 手机那种把交互脚本**挂在 Area2D 自己身上**的写法不受影响（自己就命中）。
func _resolve_interactable(node: Node) -> Node:
	var cur := node
	var hops := 0
	while cur != null and hops < 4:
		if cur != self and cur is Node:
			if cur is Interactable:
				# ⚠️ 是 Interactable 但**当前不可交互**（剧本开关没打开、已经用过的一次性物件）
				#    → 直接跳过它继续往上找，**不要**落到下面那个 has_method("interact") 上：
				#    落到那儿会把它收进候选表，于是"调试看到的候选"里多出一个玩家实际按不了的东西
				#    （提示框不显示是因为 `_ordered_candidates()` 又过滤了一次，
				#     但两份清单从此对不上，排查"为什么按不了"时最容易误判）。
				if (cur as Interactable).can_interact():
					return cur
			elif cur.has_method("interact"):
				# 非 Interactable 的可交互节点：NPC 的交互实现在**父节点**上，
				# 而探针探到的是它下面的 TalkArea（见上面那段说明）
				return cur
		cur = cur.get_parent()
		hops += 1
	return null


func _is_interactable(node: Node) -> bool:
	return _resolve_interactable(node) != null


## 目标或候选里有没有已经释放的实例（有就把当前目标一并清掉）
func _has_dead_candidate() -> bool:
	if _target != null and not is_instance_valid(_target):
		_target = null
		return true
	for node in _candidates:
		if not is_instance_valid(node):
			return true
	return false


func _update_target() -> void:
	var valid := _ordered_candidates()
	if valid.is_empty():
		_target = null
	else:
		# 保留玩家手动切换的结果（只要它仍在范围内）
		if _target != null and is_instance_valid(_target) and valid.has(_target):
			pass
		else:
			_target = valid[0]
	_refresh_prompt()


## 当前候选按"**优先级降序 → 距离升序**"排好序。
##
## 为什么不是纯按距离：光看距离的话，"剧情上必须先做的事"（开局要拿的手机）
## 会被旁边一件可查看的家具挤到第二位，玩家得先按 Tab 才找得到 —— 很反直觉。
## Tab 轮换、提示里的 `n/m` 计数、默认目标都走这一份顺序，三处永远一致。
func _ordered_candidates() -> Array[Node]:
	var valid: Array[Node] = []
	for node in _candidates:
		if not is_instance_valid(node):
			continue
		if node is Interactable and not (node as Interactable).can_interact():
			continue
		valid.append(node)
	valid.sort_custom(_comes_first)
	return valid


func _comes_first(a: Node, b: Node) -> bool:
	var pa := _priority_of(a)
	var pb := _priority_of(b)
	if pa != pb:
		return pa > pb
	return global_position.distance_squared_to((a as Node2D).global_position) \
			< global_position.distance_squared_to((b as Node2D).global_position)


## 取交互优先级；不是 Interactable 的（例如 NPC）算 0
func _priority_of(node: Node) -> int:
	if node is Interactable:
		return (node as Interactable).interaction_priority()
	if node.has_method("interaction_priority"):
		return int(node.call("interaction_priority"))
	return 0


## 在候选之间轮换交互目标（公开给输入与开发期驱动接口使用）
func cycle_target() -> void:
	_cycle_target()


## 在候选之间轮换交互目标（按"优先级 → 距离"排好序后取下一个）
func _cycle_target() -> void:
	var valid := _ordered_candidates()
	if valid.size() < 2:
		return
	var idx := valid.find(_target)
	_target = valid[(idx + 1) % valid.size()]
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if _interaction_locked:
		_prompt.visible = false
		return
	if _target != null and not is_instance_valid(_target):
		_target = null
	if _target == null:
		_prompt.visible = false
		return
	var text := "交互"
	if _target is Interactable:
		text = (_target as Interactable).get_prompt()
	elif _target.has_method("get_prompt"):
		text = String(_target.call("get_prompt"))
	_prompt.text = "[E] %s" % text
	# 附近有多个可交互物时给出切换提示（序号与 Tab 顺序同源，见 _ordered_candidates）
	var valid := _ordered_candidates()
	if valid.size() > 1:
		_prompt.text += "　（Tab 切换 %d/%d）" % [maxi(0, valid.find(_target)) + 1, valid.size()]
	_prompt.visible = true


## 当前目标在候选中的序号（仅用于提示文字）
func _target_index() -> int:
	return maxi(0, _ordered_candidates().find(_target))


## 供外部（剧情脚本 / 交互物）临时锁住操作。
## 同时锁住移动与交互，用于"正在播剧情"这类场合；
## 只想锁移动（例如开场醒来）请用 set_movement_enabled()。
func set_control_enabled(enabled: bool) -> void:
	set_movement_enabled(enabled)
	_interaction_locked = not enabled
	if not enabled and _prompt != null:
		_prompt.visible = false


## 只锁移动，保留交互能力（开场醒来时必须保留，否则连手机都看不了 → 卡死）
func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled
	if not enabled:
		velocity = Vector2.ZERO
		if _prompt != null:
			_prompt.visible = false


## 坐下 / 站起来（`SitSpot` 调；长椅与食堂凳子共用）。
##
## [param facing] 坐下时的朝向（`Vector2.DOWN / LEFT / RIGHT / UP`）。
##   ⚠️ **由调用方给**，不是"读玩家当前朝向"：座位知道该朝哪边（长椅多半朝下、
##      食堂凳子朝桌子），而玩家走到座位前的那一刻朝向是随机的（最后一步的方向），
##      照它切帧会出现"背对镜头坐在长椅上"。
##
## 会转给 `ActorSprite`，由它切到 `sit_<朝向>` 那一帧。
## ⚠️ **没有坐姿素材时是空操作**：调用方不需要先查素材（与"没有行走素材也不崩"同一条纪律）。
func set_sitting(value: bool, facing: Vector2 = Vector2.ZERO) -> void:
	if value:
		# 坐着不能再转身：把朝向定下来、速度清零。
		# `_update_facing_from_velocity()` 在速度为 0 时**不改** `facing`，
		# 所以这里定下之后它不会被走动逻辑覆盖。
		#
		# ⚠️ **顺序要紧**：先 `face_direction()` 再 `_sprite.set_sitting(true)` ——
		#    反过来的话 `is_sitting()` 已经为真，上面那个"坐着忽略转向"的守卫
		#    会把这一次**该生效**的转向也一起挡掉（坐下瞬间朝向就定不下来了）。
		velocity = Vector2.ZERO
		if facing != Vector2.ZERO:
			face_direction(facing)
	if _sprite != null:
		_sprite.set_sitting(value)


## 现在是不是坐着（自检/调试用）
func is_sitting() -> bool:
	return _sprite != null and _sprite.is_sitting()


## 整个角色立绘显示/隐藏。
##
## 用途（2026-09-20 用户："坐的时候替换为这个图，站的时候恢复正常的长椅图"）：
## 有些座位坐下时换的是**人 + 家具一体的成品图**（见 `PROP_EXAMINES.bench.sit_texture`），
## 那张图里**已经画了坐着的人** —— 这时必须把玩家自己的立绘藏起来，
## 否则会出现两个人。
##
## ⚠️ 只藏**立绘**，不碰碰撞体/交互区/提示框：座位仍要能按 E 站起来，
##    而"站起来"靠的是交互（`Interactable`），不是看得见的人。
func set_avatar_visible(value: bool) -> void:
	if _sprite != null:
		_sprite.visible = value


## ⚠️ 坐着时**忽略转向请求**：坐姿帧是按朝向取的，坐下之后再被 `face_direction`
##    转一次就会出现"朝向变了、画面还是旧的那一帧"（看着像卡住）。
##    谁会在这个时机调它：`SceneRouter._place_player()`（切场景后摆朝向）与
##    调试瞬移。正常游玩不会命中，但这是一行代价换掉一类"看不出来"的 bug。
func face_direction(dir: Vector2) -> void:
	if is_sitting():
		return
	super.face_direction(dir)


# ---------------------------------------------------------------- 开发期驱动接口

## 当前交互目标的**名字**（调试/走查用；空串表示附近没有可交互物）。
##
## 为什么返回名字而不是节点：目标被销毁后（例如把地上的东西捡走了），
## 把"已释放的实例"交给调用方，会在对方赋值那一刻直接报
## `Trying to assign invalid previously freed instance` —— 报错点在调用方，
## 排查起来会以为是调用方的问题。返回字符串从根上断掉这条路径。
func debug_current_target_name() -> String:
	if _target == null or not is_instance_valid(_target):
		return ""
	return String(_target.name)


## 当前探测到的**全部**可交互物名字（按探测顺序）。
## 用途：像"开场在床边够不够得到手机"这种断言，真正要问的是"它在不在候选里"，
## 而不是"它是不是当前选中的那个"（床边还摆着可查看的家具，最近的不一定是手机）。
func debug_candidate_names() -> Array[String]:
	var out: Array[String] = []
	for node in _candidates:
		if is_instance_valid(node):
			out.append(String(node.name))
	return out


## 直接触发当前交互目标（等价于按下交互键），用于无人操作环境下的走查
func debug_interact_target() -> void:
	_refresh_candidates()
	# 首帧物理步进还没跑时重叠查询会返回空，等一帧再试一次，避免"明明站在物件上却按不动"
	if _target == null:
		await get_tree().physics_frame
		_refresh_candidates()
	if _target == null:
		push_warning("Player: 附近没有可交互物")
		return
	_target.call("interact")


## 打印交互探测的原始数据（排查"按 E 没反应"用）
func debug_dump_probe() -> void:
	print("[probe] 玩家位置 = %s" % str(global_position))
	if _probe == null:
		print("[probe] 没有 InteractionProbe")
		return
	print("[probe] probe layer=%d mask=%d monitoring=%s" % [
		_probe.collision_layer, _probe.collision_mask, str(_probe.monitoring)])
	var areas := _probe.get_overlapping_areas()
	print("[probe] 重叠 Area2D 共 %d 个：" % areas.size())
	for a in areas:
		var owner_name := "?"
		if a.get_parent() != null:
			owner_name = String(a.get_parent().name)
		print("[probe]   - %s（父节点 %s，layer=%d，有 interact=%s）" % [
			a.name, owner_name, a.collision_layer, str(a.has_method("interact"))])
	var bodies := _probe.get_overlapping_bodies()
	print("[probe] 重叠 Body 共 %d 个：" % bodies.size())
	for b in bodies:
		print("[probe]   - %s（%s，layer=%d）" % [b.name, b.get_class(), b.collision_layer])
	# 列表里可能残留已释放实例（见 _has_dead_candidate），所以名字要逐个判存活再取
	var candidate_names: Array[String] = []
	for node in _candidates:
		candidate_names.append(String(node.name) if is_instance_valid(node) else "<已释放>")
	print("[probe] 候选列表 = %s，当前目标 = %s" % [
		str(candidate_names),
		str(_target.name) if _target != null and is_instance_valid(_target) else "无"])
	if _prompt != null:
		print("[probe] 交互提示框 visible=%s text=%s" % [str(_prompt.visible), _prompt.text])

	# 顺带把"场景里的 NPC/Body"自身参数打出来，确认 layer/mask 是否如预期
	var scene := get_tree().root.get_node_or_null("CurrentScene")
	if scene != null:
		for child in scene.get_children():
			if child is CollisionObject2D:
				var co := child as CollisionObject2D
				print("[probe] 场景直属 %s（%s）layer=%d mask=%d 位置=%s 形状数=%d" % [
					co.name, co.get_class(), co.collision_layer, co.collision_mask,
					str(co.global_position), _count_shapes(co)])

	# 直接问物理空间：玩家当前位置有哪些对象
	var space_state := get_viewport().world_2d.direct_space_state
	var query_shape := CircleShape2D.new()
	query_shape.radius = 50.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = query_shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF
	for hit in space_state.intersect_shape(params, 16):
		var obj := hit.get("collider") as Node
		if obj == null:
			continue
		print("[probe] 物理空间命中：%s（%s）layer=%d" % [
			obj.name, obj.get_class(),
			(obj as CollisionObject2D).collision_layer if obj is CollisionObject2D else -1])


func _count_shapes(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			count += 1
	return count
