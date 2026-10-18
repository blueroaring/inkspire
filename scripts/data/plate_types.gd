class_name PlateTypes
extends RefCounted
## 「盘子分类」小游戏的素材与词表（**纯数据 + 纯绘制**，不认识任何 UI 或流程）。
##
## 用户 2026-09-19 的要求（两稿）：
##   ① "根据盘子的颜色形状等收纳到正确的桶中" → **形状是判定维度**（桶按形状分）；
##   ② "加上倒/取的选择，根据来的同学是拿着吃完的盘子还是要拿盘子决定，表现要有同学排队来"
##      → 每张单子有**两个维度**：先判断这位同学是"来倒盘子"还是"来取盘子"（`needs`），
##        再按盘子的**形状**分对桶（`shape`）。
##
## 所以判定用的词表其实只有一张：`SHAPES`（5 种）。颜色仍然保留，但**只做视觉区分**
## （盘子的颜色让画面不至于是一片灰），不参与判定 —— 判定维度越少，玩家越容易一眼读懂规则。
##
## 为什么不让颜色也参与判定：那样正确率会掉到 1/(形状数×颜色数)，玩家会退化成猜。
## 现在两步各 1/2 与 1/5，且第二步的桶位还会随机换位置（见 PlateGame 的说明）。

## 桶 / 判定维度：盘子的形状（用户要求"还要判断形状"）
const SHAPES: Array[String] = ["round", "square", "triangle", "diamond", "star"]

const SHAPE_NAMES := {
	"round": "圆盘",
	"square": "方盘",
	"triangle": "三角盘",
	"diamond": "菱形盘",
	"star": "花边盘",
}

## 颜色（**只影响外观**，不参与判定）
const COLORS: Array[String] = ["red", "blue", "green", "yellow"]

const COLOR_NAMES := {
	"red": "红",
	"blue": "蓝",
	"green": "绿",
	"yellow": "黄",
}

const COLOR_VALUES := {
	"red": Color("#c8402f"),
	"blue": Color("#2f6ec8"),
	"green": Color("#3f9a4e"),
	"yellow": Color("#d8b33a"),
}

## 盘子边长（像素）：128 是 32 的整数倍，1:1 显示时不会被相机/UI 缩放弄糊
const SIZE := 128
const HALF := SIZE / 2

## 生成好的纹理缓存：key = "<color>_<shape>"（小游戏的学生立绘也借用这张缓存表）
static var _cache: Dictionary = {}


## 取缓存里的贴图（没有返回 null）——小游戏的立绘缓存与盘子共用一张表，
## 于是"缓存怎么存"只有一处实现。
static func cached_texture(key: String) -> Texture2D:
	return _cache.get(key)


static func cache_texture(key: String, tex: Texture2D) -> void:
	_cache[key] = tex


# ---------------------------------------------------------------- 画图基元（小游戏共用）


## 在图上填一块矩形（供 PlateGame 画学生立绘复用；越界自动裁掉）
static func fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	_fill_rect(img, x, y, w, h, color)


## 在图上填一个实心圆（同上）
static func fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	_fill_circle(img, cx, cy, radius, color)


## 在图上填一个实心三角形（同上）
static func fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_fill_triangle(img, a, b, c, color)


static func shape_name(shape: String) -> String:
	return String(SHAPE_NAMES.get(shape, shape))


static func is_shape(shape: String) -> bool:
	return SHAPES.has(shape)


static func color_name(color_id: String) -> String:
	return String(COLOR_NAMES.get(color_id, color_id))


static func color_value(color_id: String) -> Color:
	return COLOR_VALUES.get(color_id, Color.WHITE)


static func is_color(color_id: String) -> bool:
	return COLORS.has(color_id)


## 随机出一个盘子（形状参与判定 + 颜色只做外观）。
## [param rng] 传进来是为了"同一颗种子出同一局"，走查里要能重放，不能每次都不同。
static func random_plate(rng: RandomNumberGenerator) -> Dictionary:
	var shape: String = SHAPES[rng.randi_range(0, SHAPES.size() - 1)]
	var color_id: String = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	return {"shape": shape, "color": color_id}


## 盘子的文字说法（框里、队列卡上都用它，保证玩家看到的和判定的是同一件事）
static func plate_label(plate: Dictionary) -> String:
	return "%s·%s" % [color_name(String(plate.get("color", "red"))),
			shape_name(String(plate.get("shape", "round")))]


## 盘子纹理（按 color+shape 缓存，第一次用到才画）
static func texture_for(color_id: String, shape: String) -> Texture2D:
	var key := "%s_%s" % [color_id, shape]
	if _cache.has(key):
		return _cache[key]
	var img := _draw_plate(color_id, shape)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 程序化画一个盘子：外圈深色描边 + 盘身主色 + 内圈浅色盘心。
## 为什么用画的而不是找素材：① 小游戏是**临时叠层**，不该被美术资源卡住；
## ② 形状/颜色是词表驱动的，程序化生成能保证"词表里加一个形状就多一种盘子"。
static func _draw_plate(color_id: String, shape: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := color_value(color_id)
	var ridge := base.darkened(0.45)
	var core := base.lightened(0.35)
	match shape:
		"square":
			_fill_rect(img, 6, 6, SIZE - 12, SIZE - 12, ridge)
			_fill_rect(img, 12, 12, SIZE - 24, SIZE - 24, base)
			_fill_rect(img, 26, 26, SIZE - 52, SIZE - 52, core)
		"triangle":
			_fill_triangle(img, Vector2(HALF, 8.0), Vector2(SIZE - 8.0, SIZE - 10.0),
					Vector2(8.0, SIZE - 10.0), ridge)
			_fill_triangle(img, Vector2(HALF, 20.0), Vector2(SIZE - 20.0, SIZE - 18.0),
					Vector2(20.0, SIZE - 18.0), base)
			_fill_triangle(img, Vector2(HALF, 40.0), Vector2(SIZE - 40.0, SIZE - 32.0),
					Vector2(40.0, SIZE - 32.0), core)
		"diamond":
			_fill_diamond(img, 4.0, ridge)
			_fill_diamond(img, 12.0, base)
			_fill_diamond(img, 30.0, core)
		"star":
			_fill_star(img, 5, 6.0, base, ridge)
			_fill_star(img, 5, 18.0, core, core)
		_:
			_fill_circle(img, HALF, HALF, HALF - 5, ridge)
			_fill_circle(img, HALF, HALF, HALF - 11, base)
			_fill_circle(img, HALF, HALF, HALF - 26, core)
	return img


## 菱形：两段三角形拼起来（不用任何绘图 API，纯像素写）
static func _fill_diamond(img: Image, inset: float, color: Color) -> void:
	_fill_triangle(img, Vector2(HALF, inset), Vector2(SIZE - inset, HALF),
			Vector2(HALF, SIZE - inset), color)
	_fill_triangle(img, Vector2(HALF, inset), Vector2(inset, HALF),
			Vector2(HALF, SIZE - inset), color)


## 花边盘（五角星）：外圈填深色、再填一圈小一点的主色、中间填盘心
static func _fill_star(img: Image, points: int, inset: float, fill: Color, rim: Color) -> void:
	var outer := HALF - inset
	var inner := outer * 0.46
	var center := Vector2(HALF, HALF)
	var vertices := PackedVector2Array()
	for i in points * 2:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI * 0.5 + PI * float(i) / float(points)
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	# 星形多边形填充：用"点是否在多边形内"的射线法逐像素判（顶点只有 10 个，够快）
	var min_x := int(floorf(center.x - outer))
	var max_x := int(ceilf(center.x + outer))
	var min_y := int(floorf(center.y - outer))
	var max_y := int(ceilf(center.y + outer))
	for py in range(maxi(0, min_y), mini(SIZE, max_y + 1)):
		for px in range(maxi(0, min_x), mini(SIZE, max_x + 1)):
			var p := Vector2(float(px) + 0.5, float(py) + 0.5)
			if _in_polygon(p, vertices):
				img.set_pixel(px, py, fill)
	# 描边：把多边形边界附近的像素涂成深色（星形缩一圈再盖主色，视觉上就是描边）
	if rim != fill:
		var inner_vertices := PackedVector2Array()
		for i in points * 2:
			var radius := (outer - 6.0) if i % 2 == 0 else (inner - 3.0)
			var angle := -PI * 0.5 + PI * float(i) / float(points)
			inner_vertices.append(center + Vector2(cos(angle), sin(angle)) * maxf(2.0, radius))
		for py in range(maxi(0, min_y), mini(SIZE, max_y + 1)):
			for px in range(maxi(0, min_x), mini(SIZE, max_x + 1)):
				var p := Vector2(float(px) + 0.5, float(py) + 0.5)
				if _in_polygon(p, vertices) and not _in_polygon(p, inner_vertices):
					img.set_pixel(px, py, rim)


static func _in_polygon(p: Vector2, vertices: PackedVector2Array) -> bool:
	var inside := false
	var count := vertices.size()
	var j := count - 1
	for i in count:
		var a := vertices[i]
		var b := vertices[j]
		if ((a.y > p.y) != (b.y > p.y)) \
				and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(maxi(0, y), mini(SIZE, y + h)):
		for px in range(maxi(0, x), mini(SIZE, x + w)):
			img.set_pixel(px, py, color)


static func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for py in range(maxi(0, cy - radius), mini(SIZE, cy + radius + 1)):
		for px in range(maxi(0, cx - radius), mini(SIZE, cx + radius + 1)):
			var dx := px - cx
			var dy := py - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(px, py, color)


## 实心三角形（用重心符号判定，够用且不依赖任何绘图 API）
static func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(floorf(minf(a.x, minf(b.x, c.x))))
	var max_x := int(ceilf(maxf(a.x, maxf(b.x, c.x))))
	var min_y := int(floorf(minf(a.y, minf(b.y, c.y))))
	var max_y := int(ceilf(maxf(a.y, maxf(b.y, c.y))))
	for py in range(maxi(0, min_y), mini(SIZE, max_y + 1)):
		for px in range(maxi(0, min_x), mini(SIZE, max_x + 1)):
			var p := Vector2(float(px) + 0.5, float(py) + 0.5)
			if _in_triangle(p, a, b, c):
				img.set_pixel(px, py, color)


static func _in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _edge(p, a, b)
	var d2 := _edge(p, b, c)
	var d3 := _edge(p, c, a)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


static func _edge(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
