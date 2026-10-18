extends RefCounted
## Shared cache and aspect-correct presentation of supplied transparent artwork.
static var _textures: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if _textures.has(key): return _textures[key]
	var path := "res://assets/graphics/battle/new_effects/%s.webp" % key
	var result: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[key] = result
	return result

static func stamp(canvas: CanvasItem, key: String, at: Vector2, box: Vector2, alpha: float = 1.0, angle: float = 0.0) -> bool:
	var art := texture(key)
	if art == null: return false
	var dimensions := art.get_size()
	var fitted := dimensions * minf(box.x / dimensions.x, box.y / dimensions.y)
	canvas.draw_set_transform(at, angle)
	canvas.draw_texture_rect(art, Rect2(-fitted * 0.5, fitted), false, Color(1, 1, 1, clampf(alpha, 0, 1)))
	canvas.draw_set_transform(Vector2.ZERO)
	return true
