class_name ActorPlaceholder
extends CharacterBody2D
## 角色的视觉与朝向（占位实现 + 真实精灵的无缝切换）。
##
## 两种视觉，按"素材是否存在"自动选中，调用方完全不用管：
##   1. 有精灵表时：交给子节点 ActorSprite 播四方向行走动画，本脚本不再画。
##   2. 没有素材时：用 _draw() 画"头 + 身体 + 朝向标记"的程序化占位。
##
## 对外接口始终不变：face_direction(dir) 与 _update_facing_from_velocity(vel)，
## 所以玩家、NPC、以及任何调用方都不需要因为"素材到位了"而改代码。

const BODY_RADIUS := 13.0
const HEAD_RADIUS := 7.0

var facing: Vector2 = Vector2.DOWN
var body_color: Color = Palette.PLAYER_BODY
var head_color: Color = Palette.PLAYER_HEAD

var _sprite: ActorSprite = null
var _moving := false


func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as ActorSprite
	# 有真素材就不画占位圆点，避免两套视觉叠在一起
	queue_redraw()


func _process(_delta: float) -> void:
	# 每帧把"朝向 + 是否在动"同步给精灵，动画切换逻辑集中在 ActorSprite 内部
	if _sprite != null and _sprite.is_available():
		_sprite.set_motion(facing, _moving)


## 立即转向（场景切换传送后由 SceneRouter 调用）
func face_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	queue_redraw()


## 当前朝向名（down / left / right / up）。
##
## ⚠️ 这是**权威口径**：一切"按朝向取素材"的逻辑（如坐姿帧）都要读它，
##    而**不要**从 `AnimatedSprite2D.animation` 的名字反推 ——
##    `face_direction()` 只改 `facing`，动画要等下一帧 `set_motion()` 才切；
##    在那之间的空档里，动画名还是**旧**方向（实测：坐下瞬间会切到上一帧的坐姿朝向，
##    表现是"面朝下坐下、画面却坐着背对镜头"）。
func facing_name() -> String:
	if absf(facing.x) > absf(facing.y):
		return "right" if facing.x > 0.0 else "left"
	return "down" if facing.y >= 0.0 else "up"


## 朝向随移动方向更新，只有真正变了才重绘
func _update_facing_from_velocity(vel: Vector2) -> void:
	_moving = vel.length_squared() >= 1.0
	if _sprite != null and _sprite.separate_idle_column:
		_sprite.set_travel_speed(vel.length())
	if not _moving:
		return
	var dir := vel.normalized()
	# 取主导轴，避免斜向移动时朝向抖动
	if absf(dir.x) > absf(dir.y):
		dir = Vector2(signf(dir.x), 0.0)
	else:
		dir = Vector2(0.0, signf(dir.y))
	if dir != facing:
		facing = dir
		queue_redraw()


func _draw() -> void:
	# 有真素材时由 ActorSprite 负责画面，这里什么都不画
	if _sprite != null and _sprite.is_available():
		return
	# 阴影
	draw_circle(Vector2(0, BODY_RADIUS * 0.55), BODY_RADIUS * 0.95, Color(0, 0, 0, 0.25))
	# 身体
	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, Color(0.12, 0.12, 0.16), 2.0)
	# 头
	draw_circle(Vector2(0, -BODY_RADIUS * 0.75), HEAD_RADIUS, head_color)
	# 朝向标记
	var tip := facing * (BODY_RADIUS + 7.0)
	var side := Vector2(-facing.y, facing.x) * 5.0
	var base := facing * (BODY_RADIUS - 2.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(1, 1, 1, 0.85))


## 当前是否在使用真实精灵素材（自检/调试用）
func is_using_sprite() -> bool:
	return _sprite != null and _sprite.is_available()
