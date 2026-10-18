class_name CameraFollow
extends Camera2D
## 跟随玩家的相机，并且**按世界尺寸自动决定缩放**，保证整个房间始终完整可见。
##
## 为什么需要自动缩放（踩过的坑）：
##   zoom = 1 时，"相机视野"就等于**视口分辨率**的世界单位。
##   如果房间比视口小（本项目宿舍 640x512、视口 960x540），Godot 的 limit 会把相机
##   卡在房间内、再把画面放大去填满屏幕 → **房间被裁切，看不全**；
##   如果房间比视口大，又只能看到房间一角。
##   所以不能让 zoom 固定为 1，而要按"世界尺寸 / 视口尺寸"算出来。
##
## 职责边界：本脚本只管"怎么看"，不管"场景有什么"。
## 地图脚本只调用 configure_world() 声明世界多大，剩下的交给这里。

@export var follow_speed: float = 8.0
@export var snap_on_ready: bool = true
## 预留边距（世界单位）：留一点空间给墙顶/装饰，避免贴着屏幕边
@export var margin: float = 0.0
## true = 保证整个世界可见（可能留边）；false = 填满屏幕（可能裁切）
@export var fit_whole_world: bool = true
## 是否跟随玩家。小房间（相机正好铺满世界）不需要跟随，跟随反而会把房间推偏、露出外面。
@export var follow_player: bool = true
## 手动指定缩放；留 0 表示按世界尺寸自动算（见 _apply_zoom）
@export var fixed_zoom: float = 0.0

var world_rect: Rect2 = Rect2()
var _target: Node2D


func _ready() -> void:
	add_to_group("camera")
	make_current()
	_target = _find_player()
	if _target != null and snap_on_ready and follow_player:
		global_position = _target.global_position
	get_viewport().size_changed.connect(_on_viewport_resized)


## 由地图脚本调用：声明世界大小，并按它算出合适的缩放与位置
func configure_world(rect: Rect2) -> void:
	world_rect = rect
	_apply_zoom()
	_apply_limits()
	if not follow_player:
		# 不跟随时把相机钉在世界中心
		global_position = world_rect.get_center()


## 依据世界与视口尺寸算缩放：
##   fixed_zoom > 0        → 用手动值（例如小房间想放大到铺满屏幕高度）
##   fit_whole_world=true  → 取较小比例，保证长边也能装下（可能出现留边）
##   fit_whole_world=false → 取较大比例，填满屏幕（可能裁掉边缘）
func _apply_zoom() -> void:
	if fixed_zoom > 0.0:
		zoom = Vector2(fixed_zoom, fixed_zoom)
		return
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var world := world_rect.size + Vector2(margin, margin) * 2.0
	var sx := vp.x / world.x
	var sy := vp.y / world.y
	var s := minf(sx, sy) if fit_whole_world else maxf(sx, sy)
	zoom = Vector2(s, s)


## 边界跟着世界走；缩放算对之后，相机会正好覆盖世界
func _apply_limits() -> void:
	limit_left = int(world_rect.position.x)
	limit_top = int(world_rect.position.y)
	limit_right = int(world_rect.end.x)
	limit_bottom = int(world_rect.end.y)


func _on_viewport_resized() -> void:
	_apply_zoom()


func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D


func _process(delta: float) -> void:
	if not follow_player:
		return
	if _target == null or not is_instance_valid(_target):
		_target = _find_player()
		if _target == null:
			return
	var weight := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(_target.global_position, weight)
