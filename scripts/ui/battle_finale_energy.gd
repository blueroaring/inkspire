extends RefCounted
## Painted plasma mapped onto flowing ribbons. Shared by gathering, flight and contact.
static var ribbon_texture: Texture2D
static var vortex_texture: Texture2D

static func prepare() -> void:
	if ribbon_texture == null and ResourceLoader.exists("res://assets/graphics/battle/finale/ui/energy_ribbon.webp"):
		ribbon_texture = load("res://assets/graphics/battle/finale/ui/energy_ribbon.webp")
	if vortex_texture == null and ResourceLoader.exists("res://assets/graphics/battle/finale/ui/energy_vortex.webp"):
		vortex_texture = load("res://assets/graphics/battle/finale/ui/energy_vortex.webp")

static func ribbon(canvas: CanvasItem, start: Vector2, end: Vector2, thickness: float, tint: Color, clock: float, opacity: float = 1.0) -> void:
	if ribbon_texture == null or start.distance_squared_to(end)<16 or opacity<=0: return
	var direction := (end-start).normalized()
	var normal := direction.orthogonal()
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	for side in [1,-1]:
		for n in 25:
			var u := float(n if side==1 else 24-n)/24.0
			var wave := sin(u*TAU-clock*2.2)*sin(u*PI)*thickness*.23
			var half := thickness*.5*(.8+.2*sin(u*9-clock))
			vertices.append(start.lerp(end,u)+normal*(wave+side*half))
			uv.append(Vector2(u,0 if side==1 else 1))
			colors.append(Color(tint,opacity))
	canvas.draw_polygon(vertices,colors,uv,ribbon_texture)

static func vortex(canvas: CanvasItem, at: Vector2, radius: float, tint: Color, clock: float, opacity: float = 1.0, squash: float = 1.0) -> void:
	if vortex_texture == null or opacity<=0: return
	canvas.draw_set_transform(at,clock*.24,Vector2(1,squash))
	canvas.draw_texture_rect(vortex_texture,Rect2(-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(tint,opacity))
	canvas.draw_set_transform(at,-clock*.16,Vector2(1,squash))
	canvas.draw_texture_rect(vortex_texture,Rect2(-Vector2.ONE*radius*.72,Vector2.ONE*radius*1.44),false,Color(tint.lightened(.16),opacity*.34))
	canvas.draw_set_transform(Vector2.ZERO)
