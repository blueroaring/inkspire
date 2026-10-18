extends Control
signal practice_requested(task: String)
signal closed
const BOOK := preload("res://scripts/data/tower_onboarding.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
var index := 0
var replay := false
var demo: TextureRect
var frames: SpriteFrames
var playing := true
var elapsed := 0.0
var frame_index := 0

func _ready() -> void:
	name = "TowerOnboarding"
	size = Vector2(1920, 1080)
	index = 0 if replay else clampi(int(TowerRun.data.get("onboarding", {}).get("page", 0)), 0, BOOK.PAGES.size() - 1)
	show_page(index)

func show_page(value: int) -> void:
	index = clampi(value, 0, BOOK.PAGES.size() - 1)
	if not replay:
		TowerRun.data.onboarding.page = index
		TowerRun.save_game()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var page: Dictionary = BOOK.PAGES[index]
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.018, 0.033, 0.055, 0.90)
	add_child(shade)
	var sheet := M.panel(Rect2(150, 70, 1620, 940), T.SURFACE, T.GOLD)
	add_child(sheet)
	preload("res://scripts/ui/tower_finish.gd").decorate(sheet)
	M.heading(sheet, "新手教程  /  %02d · %02d" % [index + 1, BOOK.PAGES.size()], Rect2(42, 24, 1100, 36), 24)
	M.heading(sheet, page.title, Rect2(42, 78, 1500, 60), 38)
	var explanation_text := String(page.text)
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		explanation_text = explanation_text.replace("右键查看详情", "点「详情」查看说明").replace("左键选牌", "点按选牌")
		if page.id == "battle": explanation_text = "先点左侧的牌，再点敌人或队友。想看卡牌或终结技说明，就打开左下「详情」，看完关掉再出牌。选错目标时可以点「取消选取」。\n\n先看看敌人要做什么，再决定进攻还是保护队友。能量不够时可以结束回合。顶部能查看牌堆、记录、角色和道具；充能足够后可以用终结技。有些牌需要额外选牌或操作画布。"
	var explanation := M.paragraph(sheet, explanation_text, Rect2(44, 158, 540, 420), 24)
	explanation.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	explanation.clip_text = true
	explanation.size = Vector2(540, 420)
	var try_box := M.panel(Rect2(32, 606, 568, 190), T.RECESSED, T.GOLD)
	sheet.add_child(try_box)
	M.heading(try_box, "现在试试", Rect2(20, 12, 510, 40), 25)
	M.paragraph(try_box, page.action, Rect2(20, 58, 522, 120), 22)
	var frame := M.panel(Rect2(632, 155, 946, 599), T.INK, T.GOLD)
	sheet.add_child(frame)
	demo = TextureRect.new()
	demo.position = Vector2(12, 12)
	demo.size = Vector2(922, 575)
	demo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	demo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(demo)
	var path := "res://assets/graphics/tower/tutorial/%s.tres" % page.id
	frames = load(path) if ResourceLoader.exists(path) else null
	restart()
	var pause := M.button("暂停演示", Rect2(644, 772, 180, 48), func(): playing = not playing)
	pause.pressed.connect(func(): pause.text = "暂停演示" if playing else "继续演示")
	sheet.add_child(pause)
	sheet.add_child(M.button("重播", Rect2(840, 772, 140, 48), restart))
	M.paragraph(sheet, "游戏实录 · 循环 GIF 演示", Rect2(1010, 772, 550, 46), 21, T.MUTED)
	var previous := M.button("上一页", Rect2(44, 854, 162, 54), func(): show_page(index - 1))
	previous.disabled = index == 0
	sheet.add_child(previous)
	var task := String(page.get("task", ""))
	var done := replay or task.is_empty() or bool(TowerRun.data.get("onboarding", {}).get("tasks", {}).get(task, false))
	if not task.is_empty():
		var words: String = {"formation":"去编队", "loadout":"去改技能", "battle":"进入教学战斗"}[task]
		sheet.add_child(M.button("已完成练习" if done and not replay else words, Rect2(650, 854, 300, 54), func(): practice_requested.emit(task), T.GOLD, true))
	var next := M.button("返回大厅" if replay and index == BOOK.PAGES.size() - 1 else "完成教程" if index == BOOK.PAGES.size() - 1 else "下一页", Rect2(1220, 854, 350, 54), _next, T.GOLD, true)
	next.disabled = not done
	if index == BOOK.PAGES.size() - 1 and not replay:
		for key in ["formation", "loadout", "battle"]:
			if not TowerRun.data.onboarding.tasks.get(key, false): next.disabled = true
	sheet.add_child(next)
	sheet.add_child(M.button("关闭手册" if replay else "跳过教程", Rect2(224, 854, 205, 54), _skip))

func restart() -> void:
	elapsed = 0
	frame_index = 0
	playing = true
	if frames: demo.texture = frames.get_frame_texture("default", 0)

func _next() -> void:
	if index < BOOK.PAGES.size() - 1:
		show_page(index + 1)
	else:
		if not replay: TowerRun.finish_onboarding()
		closed.emit()
		queue_free()

func _skip() -> void:
	if replay:
		closed.emit()
		queue_free()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "跳过新手教程"
	dialog.dialog_text = "跳过后可以直接攀登，随时从大厅重看教程。"
	dialog.confirmed.connect(func(): TowerRun.finish_onboarding(true); closed.emit(); queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(580, 180))

func _process(delta: float) -> void:
	if not playing or frames == null: return
	elapsed += delta
	var duration := frames.get_frame_duration("default", frame_index) / frames.get_animation_speed("default")
	while elapsed >= duration:
		elapsed -= duration
		frame_index = (frame_index + 1) % frames.get_frame_count("default")
		duration = frames.get_frame_duration("default", frame_index) / frames.get_animation_speed("default")
	demo.texture = frames.get_frame_texture("default", frame_index)
