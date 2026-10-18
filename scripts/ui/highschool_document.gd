extends CanvasLayer
## 校园时刻表与线索纸条共用查看器；双面纸条可随时翻面。
signal closed
var root: Control
var picture: TextureRect
var close_button: Button
var flip_button: Button
var pages: Array[Texture2D] = []
var page := 0
var _closing := false

static func show_document(parent: Node, texture_path: String, title: String, back_path: String = "") -> void:
	var viewer := load("res://scripts/ui/highschool_document.gd").new() as CanvasLayer
	parent.add_child(viewer)
	viewer.pages.append(load(texture_path))
	if back_path != "": viewer.pages.append(load(back_path))
	viewer._show_page()
	viewer.close_button.text = title + "　·　关闭 / Esc"
	await viewer.closed
	viewer.queue_free()

func _ready() -> void:
	layer = 57
	add_to_group("school_document")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(picture)
	close_button = Button.new()
	close_button.add_theme_font_size_override("font_size", 21)
	close_button.pressed.connect(_close)
	root.add_child(close_button)
	flip_button = Button.new()
	flip_button.add_theme_font_size_override("font_size", 21)
	flip_button.pressed.connect(_flip)
	flip_button.hide()
	root.add_child(flip_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	close_button.grab_focus()

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	picture.position = Vector2(24, 20)
	picture.size = screen - Vector2(48, 100)
	close_button.position = Vector2(screen.x * 0.5 - (330 if pages.size() > 1 else 225), screen.y - 66)
	close_button.size = Vector2(450, 46)
	flip_button.position = close_button.position + Vector2(466, 0)
	flip_button.size = Vector2(194, 46)

func _show_page() -> void:
	picture.texture = pages[page]
	flip_button.visible = pages.size() > 1
	flip_button.text = "翻到背面 / F" if page == 0 else "翻到正面 / F"
	_layout()

func _flip() -> void:
	if pages.size() < 2: return
	page = (page + 1) % pages.size()
	_show_page()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		get_viewport().set_input_as_handled()
		_flip()
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closing: return
	_closing = true
	closed.emit()
