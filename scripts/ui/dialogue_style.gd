class_name DialogueStyle
extends RefCounted
## 对话框外观的**唯一来源**（LingChat 风格的 galgame 全宽框）。
##
## 为什么要有这个文件：
##   尺寸、配色、字号如果散在 .tscn + 脚本两处，改一次风格要动好几个地方，还容易漏。
##   这里集中所有常量与样式工厂；`dialogue_box.tscn` 只描述**节点结构**，
##   样式一律由 `dialogue_box.gd` 在 _ready() 里按本文件套上去。
##
## 所有尺寸按基准分辨率 1920x1080 写，运行期按视口宽度等比换算（见各 rect 函数）。

const BASE := Vector2(1920.0, 1080.0)

# ---------------------------------------------------------------- 版式（基准分辨率下的像素）
const MARGIN_X := 140.0        ## 对话框左右留白
const BOX_HEIGHT := 300.0      ## 对话框高度
const BOX_BOTTOM := 66.0       ## 对话框底边到屏幕底部的距离
const PORTRAIT_SIZE := 200.0   ## 立绘框边长：64px 头像按 3 倍整数放大，像素不糊
const RADIUS := 10
const SHADE_HEIGHT := 520.0    ## 底部渐变压暗的高度
const BUST_WIDTH := 520.0      ## 半身立绘位宽度（框外左侧，随框一起缩放）
const BUST_HEIGHT := 640.0

# ---------------------------------------------------------------- 配色
const BOX_BG := Color(0.039, 0.055, 0.110, 1.0)          # #0a0e1c 深海军蓝
const BOX_BORDER := Color(0.541, 0.518, 0.373, 0.95)     # 暗金描边
const NAME_BG := Color(0.070, 0.090, 0.160, 0.96)
const NAME_BORDER := Color(0.859, 0.839, 0.659, 1.0)
const NAME_TEXT := Color(0.957, 0.914, 0.722, 1.0)
const EMOTION_TEXT := Color(0.498, 0.831, 1.0, 1.0)      # 青蓝，对应 LingChat 的情绪标签
const HINT_TEXT := Color(0.560, 0.607, 0.702, 1.0)
const MODE_TEXT := Color(1.0, 0.812, 0.361, 1.0)         # AUTO / SKIP 指示
const INDICATOR_TEXT := Color(0.957, 0.914, 0.722, 1.0)
const SHADE_COLOR := Color(0.016, 0.024, 0.051, 0.94)
const BACKDROP := Color(0.0, 0.0, 0.0, 0.16)
const DEFAULT_TEXT_COLOR := Color(0.949, 0.937, 0.878, 1.0)

# ---------------------------------------------------------------- 字号
const FONT_NAME := 34
const FONT_TEXT := 32
const FONT_EMOTION := 24
const FONT_HINT := 20
const FONT_MODE := 22
const FONT_CHOICE := 30

## 缺省不透明度（Settings 里 dialogue/box_opacity 可以覆盖）
const DEFAULT_BOX_OPACITY := 0.9


# ---------------------------------------------------------------- 版式计算

static func box_rect(viewport: Vector2) -> Rect2:
	var s := viewport.x / BASE.x
	return Rect2(
		Vector2(MARGIN_X * s, viewport.y - (BOX_BOTTOM + BOX_HEIGHT) * s),
		Vector2(maxf(viewport.x - MARGIN_X * 2.0 * s, 320.0), BOX_HEIGHT * s))


static func shade_rect(viewport: Vector2) -> Rect2:
	var s := viewport.x / BASE.x
	var h := SHADE_HEIGHT * s
	return Rect2(Vector2(0.0, viewport.y - h), Vector2(viewport.x, h))


## 半身立绘位：贴着框的左边、底边与框底齐平，向上长出去（galgame 常见构图）
static func bust_rect(viewport: Vector2) -> Rect2:
	var s := viewport.x / BASE.x
	var box := box_rect(viewport)
	var w := BUST_WIDTH * s
	var h := BUST_HEIGHT * s
	return Rect2(Vector2(box.position.x + 40.0 * s, box.position.y + box.size.y - h), Vector2(w, h))


## 选项区：居中在对话框上方，避免压住正文
static func choices_rect(viewport: Vector2) -> Rect2:
	var s := viewport.x / BASE.x
	var w := 1040.0 * s
	var h := 380.0 * s
	var box := box_rect(viewport)
	var center := Vector2(viewport.x * 0.5, box.position.y * 0.5 + 40.0 * s)
	return Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))


# ---------------------------------------------------------------- 设置读取

static func box_opacity() -> float:
	if Settings == null:
		return DEFAULT_BOX_OPACITY
	return clampf(float(Settings.get_value("dialogue", "box_opacity", DEFAULT_BOX_OPACITY)), 0.0, 1.0)


static func text_color() -> Color:
	return DEFAULT_TEXT_COLOR


# ---------------------------------------------------------------- 样式工厂

static func box_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BOX_BG.r, BOX_BG.g, BOX_BG.b, box_opacity())
	# 顶边略粗一点，读作"框的上沿"（galgame 框常见画法）
	sb.border_width_top = 3
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = BOX_BORDER
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 18.0
	return sb


static func portrait_frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.9)
	sb.set_border_width_all(4)
	sb.border_color = BOX_BORDER
	sb.set_corner_radius_all(4)
	# 内缩 4px：200 - 8 = 192 = 64px 头像的 3 倍，保证整数放大不糊
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


static func name_plate_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = NAME_BG
	sb.set_border_width_all(2)
	sb.border_color = NAME_BORDER
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


## 选项按钮：四态样式（原来只套了 normal，hover/focus 看不出来）
static func choice_style(kind: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match kind:
		"hover":
			sb.bg_color = Color(0.14, 0.20, 0.32, 0.98)
			sb.border_color = NAME_BORDER
		"pressed":
			sb.bg_color = Color(0.06, 0.08, 0.14, 1.0)
			sb.border_color = NAME_BORDER
		"focus":
			sb.bg_color = Color(0.12, 0.18, 0.30, 0.98)
			sb.border_color = Color.WHITE
		_:
			sb.bg_color = Color(0.08, 0.10, 0.18, 0.95)
			sb.border_color = BOX_BORDER
	sb.set_border_width_all(3 if kind == "focus" else 2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## 底部渐变压暗（直接从透明过渡到深色，避免"一条黑边"的生硬感）
static func make_shade_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(SHADE_COLOR.r, SHADE_COLOR.g, SHADE_COLOR.b, 0.0))
	gradient.set_color(1, SHADE_COLOR)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = int(SHADE_HEIGHT)
	return tex
