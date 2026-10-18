class_name UiKit
extends RefCounted
## UI 统一样式工具。
##
## 目的：让所有界面（标题、存档、设置、暂停）长得一致，且风格集中在一处可改。
## 现在用代码生成 StyleBox，避免往仓库里塞 .tres 主题文件；将来要做正式主题时
## 只需要把这里换成一个 .theme 资源，调用方不用动。

const FONT_SIZE_TITLE := 64
const FONT_SIZE_BUTTON := 32
const FONT_SIZE_NORMAL := 26
const FONT_SIZE_SMALL := 20


static func panel_style(bg: Color = Palette.UI_PANEL, border: Color = Palette.UI_BORDER,
		border_width: int = 3, radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_width)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.01, 0.02, 0.06, 0.62)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.01, 0.02, 0.06, 0.48)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## 给按钮套上统一的四态样式（normal / hover / pressed / focus）
static func style_button(button: Button, accent: Color = Palette.UI_BORDER) -> void:
	var normal := button_style(Color(0.10, 0.14, 0.23, 0.98), Color(0.31, 0.43, 0.60))
	var hover := button_style(Color(0.18, 0.27, 0.42, 0.99), accent)
	var pressed := button_style(Color(0.08, 0.12, 0.20, 1.0), accent)
	var focus := button_style(Color(0.15, 0.23, 0.36, 0.99), accent)
	focus.set_border_width_all(3)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	button.add_theme_color_override("font_color", Palette.UI_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent)


## 生成一个带统一描边的面板
static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	return p


## 生成标题文字
static func make_title(text: String, size: int = FONT_SIZE_TITLE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## 让一个 Control 铺满整个视口。
##
## 为什么不用 set_anchors_preset()：本项目的场景根节点是 Node2D（不是 Control），
## 程序化创建 Control 后调用 set_anchors_preset 实测不生效
## （用 get_global_rect() 验证过：anchors 仍为 0，按钮直接堆在左上角）。
## 因此统一改成显式按视口尺寸摆放，行为确定、可预期。
## 实现上用 set_deferred，避免在布局通知期间直接改尺寸被引擎拒绝。
static func fill_viewport(node: Control, tree: SceneTree) -> void:
	_apply_geometry(node, tree, Rect2(Vector2.ZERO, tree.root.get_visible_rect().size))


## 以视口中心为基准摆一个固定尺寸的 Control
static func place_centered(node: Control, tree: SceneTree, size: Vector2,
		center_offset: Vector2 = Vector2.ZERO) -> void:
	var vp := tree.root.get_visible_rect().size
	_apply_geometry(node, tree, Rect2(vp * 0.5 + center_offset - size * 0.5, size))


## 摆一个固定矩形（相对视口左上角）
static func place(node: Control, rect: Rect2) -> void:
	node.set_deferred("position", rect.position)
	node.set_deferred("size", rect.size)


static func _apply_geometry(node: Control, _tree: SceneTree, rect: Rect2) -> void:
	node.set_deferred("position", rect.position)
	node.set_deferred("size", rect.size)


## 统一按钮点击音效（暂无音效资源时静默）
static func click_sfx() -> void:
	AudioManager.play_ui("click")
