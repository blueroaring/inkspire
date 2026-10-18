class_name ActorSprite
extends AnimatedSprite2D
## 角色行走精灵（俯视四方向）。
##
## 设计要点：
##   1. **没有素材也必须能跑**。sprite sheet 不存在时本节点什么都不做、直接隐藏，
##      调用方（ActorPlaceholder）会自动回退到程序化圆点占位视觉。
##      这样"素材没到位"永远不会变成崩溃或黑屏。
##   2. 动画命名固定为 walk_<方向> / idle_<方向>，方向取 down / left / right / up，
##      与下方 DIRECTIONS 一一对应；换成别的精灵表时只需改 SHEET 与帧数参数。
##   3. 朝向 + 是否在移动 = 当前该播哪个动画。这张"状态 → 动画"的映射只在 set_motion() 一处，
##      玩家与 NPC 共用，不需要各自写一遍。
##
## 精灵表约定（由 tools/process_walk_sheet.py 从手工/生成的大图处理后产出）
##   - 一行一个方向，顺序见 ROW_ORDER；每行 FRAMES_PER_DIR 帧；帧尺寸 FRAME_SIZE
##   - 脚底对齐：所有帧的角色脚底在同一条基线上（处理脚本已保证）
##   - 当前素材没有单独的"朝右"行，right 由 left 水平镜像写入（处理脚本完成）
## 换素材时若帧尺寸/帧数不同，只改下面两个常量即可，调用方不用动。
const DEFAULT_SHEET := "res://assets/graphics/characters/player_walk.png"
const FRAME_SIZE := Vector2i(48, 48)
const FRAMES_PER_DIR := 4
## 行序（自上而下）
const ROW_ORDER: Array[String] = ["down", "left", "right", "up"]

## 允许 NPC 等复用本节点时指定自己的精灵表；留空则用 DEFAULT_SHEET
@export_file("*.png") var sheet_path: String = ""
## 高清角色可指定源切格尺寸；默认仍为大学角色的 48×48。
@export var source_frame_size := Vector2i(48, 48)
## 开启时使用五列：第 0 列站立，第 1～4 列组成步态循环。
## 高中回映贴图由 tools/assemble_rewind_walk.py 按此布局组装。
@export var separate_idle_column := false
@export var airborne := false
@export var flight_height := 12.0
var _hover_clock := 0.0
var _sprite_base_y := 0.0
var _travel_speed := 0.0

## 一步的位移与动画周期匹配，慢走的人不会用奔跑的摆腿频率。
func set_travel_speed(pixels_per_second: float) -> void:
	_travel_speed = pixels_per_second
	if not airborne:
		speed_scale = clampf(pixels_per_second / 192.0, 0.4, 1.6)

## 「坐着」的精灵表（可缺）。**缺了什么都不发生**（与"没有行走素材"同一条纪律）。
##
## 格式与行走表**完全同构**：行 = 朝向（`ROW_ORDER`），列 = 帧；每格 `FRAME_SIZE`。
## 只用每行的**第 0 帧**（坐姿是静止的，没有帧序列）。
## 规范与出图 prompt 见 `request/11_CHARACTER_SIT_PROMPTS.md`。
##
## ⚠️ 2026-09-20 加它的原因（用户实报）："没有一个坐在椅子上的动作，目前看起来就是卡在那里"。
##    原来坐下只是"瞬移到椅子上 + 锁移动 + 压低 z"，人物还是**站着**的那一帧。
const DEFAULT_SIT_SHEET := "res://assets/graphics/characters/player_sit.png"

## 基准视觉放大倍数（只影响"看起来多大"，不影响碰撞体 —— 碰撞由角色自己的
## CollisionShape2D 决定）。素材原帧 48x48，但家具是按 16px 图块标尺绘制的：
## 1.75 倍会让角色比单人床还高大，伪 3D 空间比例会完全失真，所以基准取 0.75
## （48px 帧 → 约 36px），与 32x48px 的床、48x48px 的书桌处在同一尺度。
##
## ⚠️ 这是**基准值**，不是最终值：场景可以再乘一个倍率
## （`ActorSprite.set_visual_scale()`，入口在 `CollegeMap.character_scale`）——
## 露天校园的地图是 1:1 显示的，同一个 36px 的人在宿舍里看着够大、在校园里就偏小，
## 所以要按"场景"调，而不是在这里一刀切（用户 2026-09-19 要求"增大校园地图里的人物大小"）。
const BASE_SCALE := 0.75
@export var visual_scale: float = BASE_SCALE

## 占位：没有素材时禁用本节点
var _available := false
## 有没有可用的坐姿表（`_ready` 里探一次；立绘表本身是惰性加载的）
var _sit_available := false
## 坐着吗（`set_sitting()` 写的；`set_motion()` 在坐着时不抢动画）
var _sitting := false


func _sheet() -> String:
	return sheet_path if sheet_path != "" else DEFAULT_SHEET


func _ready() -> void:
	_available = ResourceLoader.exists(_sheet())
	visible = _available
	if not _available:
		return
	_apply_scale()
	sprite_frames = _build_frames()
	_sit_available = not airborne and source_frame_size == FRAME_SIZE and ResourceLoader.exists(DEFAULT_SIT_SHEET)
	if _sit_available:
		_add_sit_frames(DEFAULT_SIT_SHEET)
	play("hover_down" if airborne else "idle_down")
	set_process(airborne)


## 从精灵表切出"每方向一组动画"。用 AtlasTexture 引用同一张贴图，
## 不需要把图切成 16 个文件（换素材只要换一张 PNG）。
func _build_frames() -> SpriteFrames:
	var sheet := load(_sheet()) as Texture2D
	var frames := SpriteFrames.new()
	if sheet == null:
		_available = false
		visible = false
		return frames

	frames.remove_animation("default")
	for row in ROW_ORDER.size():
		var dir: String = ROW_ORDER[row]
		var walk_name := "%s_%s" % ["fly" if airborne else "walk", dir]
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 8.0)
		frames.set_animation_loop(walk_name, true)
		for frame_index in FRAMES_PER_DIR:
			var col := frame_index + (1 if separate_idle_column else 0)
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(
				Vector2(col * source_frame_size.x, row * source_frame_size.y),
				Vector2(source_frame_size))
			frames.add_frame(walk_name, at)

		# 站立帧：每个方向取第一帧当 idle（素材若有专门的 idle 行再扩展）
		var idle_name := "%s_%s" % ["hover" if airborne else "idle", dir]
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 6.0 if airborne else 1.0)
		if airborne:
			for col in FRAMES_PER_DIR:
				frames.add_frame(idle_name, frames.get_frame_texture(walk_name, col))
			continue
		var idle_tex := AtlasTexture.new()
		idle_tex.atlas = sheet
		idle_tex.region = Rect2(Vector2(0, row * source_frame_size.y), Vector2(source_frame_size))
		frames.add_frame(idle_name, idle_tex)

	return frames


## 该节点是否真的用上了精灵素材（供 ActorPlaceholder 决定要不要画占位圆点）
func is_available() -> bool:
	return _available


## 当前视觉放大倍数（走查/自检用）
func current_visual_scale() -> float:
	return scale.x if _available else visual_scale


## 运行时改"人看起来多大"（场景级的倍率入口）。
##
## 为什么要有它：同一个 36px 的人在**宿舍**（相机 zoom≈3）里够大，在**校园**
## （48x34 格整张图 1:1 铺满视口，zoom≈0.99）里就偏小 —— 用户 2026-09-19
## 要求"增大校园地图里的人物大小"。倍率由场景声明（`CollegeMap.character_scale`），
## 玩家与 NPC 走同一条路，所以"人和 NPC 一样大"这件事不会被某一边漏掉。
##
## ⚠️ 只改**视觉**：碰撞体（Body 半径 8）与交互探测半径（12）一个都不动 ——
##    把碰撞一起放大，等于顺手改掉了"贴上去才能交互"的手感与所有相关断言。
func set_visual_scale(value: float) -> void:
	visual_scale = maxf(0.05, value)
	if not _available:
		return
	_apply_scale()


## 把"缩放 + 对齐"一次做完。两件事必须成对，否则会各错各的：
##   · scale                —— 视觉大小；
##   · position.y           —— **脚底对齐**。角色原点在脚底（Body 碰撞圆心是 y=+4），
##     而 AnimatedSprite2D 是以中心为原点缩放/贴图的，场景里写死的 position=(0,-8)
##     只对基准倍率成立：倍率一变，脚就会离地（放大→悬空、缩小→陷进地面）。
## 公式 = 帧高一半 × 倍率，再抬 4px 对齐脚下那颗 8px 半径的碰撞圆。
func _apply_scale() -> void:
	scale = Vector2(visual_scale, visual_scale)
	_sprite_base_y = -source_frame_size.y * 0.5 * visual_scale + 4.0 - (flight_height if airborne else 0.0)
	position.y = _sprite_base_y
	_shift_prompt_anchor()


func _process(delta: float) -> void:
	if airborne:
		_hover_clock += delta
		position.y = _sprite_base_y + sin(_hover_clock * 2.6) * flight_height * 0.22


## 交互提示框挂在"玩家头顶"，而头顶高度 = 角色画多高。放大后不跟着抬，
## 提示就会压到 sprite 身上（校园放大到 1.4 倍时很明显）。
## 基准倍率下 probe 的位置与场景里手写的一致（y=-8），所以不改动老场景的表现。
func _shift_prompt_anchor() -> void:
	var owner_node := get_parent()
	if owner_node == null or not (owner_node is Node2D):
		return
	var probe := owner_node.get_node_or_null("InteractionProbe") as Node2D
	if probe == null:
		return
	probe.position = Vector2(0.0, -source_frame_size.y * 0.5 * visual_scale)


## 每帧调用：根据"朝向 + 是否在移动"切换动画。
## moving=false 时播 idle；朝向变化时立即换动画，不需要调用方自己判断。
##
## ⚠️ 坐着时**直接不动**：坐着不能走，也不该被 `set_motion` 切回 idle/walk
##    （那会把坐姿帧顶掉）。朝向也锁在"坐下的那一刻"（见 `set_sitting`）。
func set_motion(facing: Vector2, moving: bool) -> void:
	if not _available or sprite_frames == null or _sitting:
		return
	var dir := _dir_name(facing)
	var prefix := ("fly" if moving else "hover") if airborne else ("walk" if moving else "idle")
	var want := "%s_%s" % [prefix, dir]
	if not airborne:
		speed_scale = clampf(_travel_speed / 192.0, 0.4, 1.6) if moving and _travel_speed > 0 else 1.0
	if sprite_frames.has_animation(want) and animation != want:
		# 转弯时保留当前迈腿阶段，避免每一段路线都重新迈同一只脚。
		var keep_step := separate_idle_column and moving and String(animation).begins_with("walk_")
		var step_frame := frame
		var step_progress := frame_progress
		play(want)
		if keep_step:
			set_frame_and_progress(step_frame, step_progress)


## 坐下 / 站起来。
##
## 坐着 = 停掉当前动画、**只显示 `sit_<朝向>` 的第 0 帧**（坐姿没有帧序列）；
## 站起来 = 回到 `idle_<朝向>`。
##
## ⚠️ **没有坐姿素材时这是空操作**（`_sit_available == false`）：不报错、不改画面，
##    于是"素材没到位"的表现与今天完全一致（还是站着那一帧），不会更坏。
func set_sitting(value: bool) -> void:
	_sitting = value
	if not _available or sprite_frames == null or not _sit_available:
		return
	if value:
		# ⚠️ 朝向**从角色节点读**（`facing_name()`），不要从 `animation` 的名字反推：
		#    `face_direction()` 只改 `facing`，动画要等下一帧 `set_motion()` 才切 ——
		#    在这之间的空档里动画名还是**旧**方向。实测过一次：按到座位的瞬间
		#    动画还停在 `idle_up`，于是切成 `sit_up`（面朝下坐下、却背对镜头坐着）。
		var dir := _facing_name_of_owner()
		var sit_name := "sit_%s" % dir
		if not sprite_frames.has_animation(sit_name):
			return
		stop()
		animation = sit_name
		frame = 0
		return
	var want := "idle_%s" % _facing_name_of_owner()
	if sprite_frames.has_animation(want):
		play(want)


## 问角色节点要朝向名（`ActorPlaceholder.facing_name()`）；
## 拿不到（节点不是那种角色）时退回 `animation` 名里的方向，最后兜 "down"。
func _facing_name_of_owner() -> String:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("facing_name"):
		var name := String(owner_node.call("facing_name"))
		if name != "":
			return name
	return _current_dir()


## 现在是不是坐着（场景脚本/自检用）
func is_sitting() -> bool:
	return _sitting


## 当前朝向（没在播动画时按动画名反推，再不行按 down）
func _current_dir() -> String:
	var anim := String(animation)
	if anim.contains("_"):
		return anim.get_slice("_", 1)
	return "down"


## 把坐姿表接成 `sit_<方向>` 动画（每方向取第 0 帧）。
##
## 为什么要单独一个 `SpriteFrames` 再合并：坐姿表与行走表是**两张图**，
## 而一个 `AnimatedSprite2D` 只有一个 `sprite_frames` —— 所以把坐姿那几帧
## 追加进同一份 `SpriteFrames` 里，`set_motion` / `set_sitting` 就能按名字切。
##
## ⚠️ 表里每行**四格都是同一个坐姿**（出图时要求这么画，见 11 号 prompt）：
##    这里只取第 0 帧，多画的几格不会被用到 —— 但"每行四格都有内容"
##    能让现有切图流程原样复用。表不存在时本函数什么都不做。
func _add_sit_frames(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var sheet := load(path) as Texture2D
	if sheet == null:
		return
	# 坐姿表可以画成 4x4（与行走表同构），也可以画成 1 行 4 格
	var rows := 4 if sheet.get_height() >= FRAME_SIZE.y * 4 else 1
	for row in mini(rows, ROW_ORDER.size()):
		var dir := ROW_ORDER[row]
		var name := "sit_%s" % dir
		if sprite_frames.has_animation(name):
			sprite_frames.remove_animation(name)
		sprite_frames.add_animation(name)
		sprite_frames.set_animation_speed(name, 1.0)
		sprite_frames.set_animation_loop(name, false)
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(Vector2(0, row * FRAME_SIZE.y), Vector2(FRAME_SIZE))
		sprite_frames.add_frame(name, at)
	_sit_available = true


## 把任意朝向向量归到四个方向名之一（取主导轴，避免斜向抖动）
static func _dir_name(facing: Vector2) -> String:
	if facing == Vector2.ZERO:
		return "down"
	if absf(facing.x) > absf(facing.y):
		return "right" if facing.x > 0.0 else "left"
	return "down" if facing.y > 0.0 else "up"
