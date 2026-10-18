extends Control
## Interactive 2D mesh portrait. Independent from combat RNG, speed and rules.
const OPEN := preload("res://assets/graphics/battle/anya/portrait_phoenix.webp")
const CLOSED := preload("res://assets/graphics/battle/anya/portrait_phoenix_blink.webp")
const DEFORM := preload("res://scripts/ui/anya_living_portrait.gdshader")
const SOURCE_SIZE := Vector2(462, 600)
static var shared_mesh: ArrayMesh
var drawing: MeshInstance2D
var rig: ShaderMaterial
var gaze := Vector2.ZERO
var blink_override := -1.0
var recoil := 0.0
var resolve_glow := 0.0
var fit_cover := false
var pointer := Vector2.ZERO
var source_size := SOURCE_SIZE
var phase_offset := 1.73
var resting := false

func _ready() -> void:
	name = "AnyaLivingPortrait"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if shared_mesh == null: shared_mesh = _mesh()
	drawing = MeshInstance2D.new()
	drawing.texture = OPEN
	drawing.mesh = shared_mesh
	rig = ShaderMaterial.new()
	rig.shader = DEFORM
	rig.set_shader_parameter("closed_eyes", CLOSED)
	drawing.material = rig
	add_child(drawing)
	resized.connect(_fit)
	visibility_changed.connect(func() -> void:
		set_process(is_visible_in_tree())
		set_process_input(is_visible_in_tree()))
	_fit()
	pointer = get_global_mouse_position()
	gaze = _pointer_gaze()
	_process(0)

static func _mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const COLUMNS := 32
	const ROWS := 40
	for y in range(ROWS + 1):
		for x in range(COLUMNS + 1):
			var uv := Vector2(float(x) / COLUMNS, float(y) / ROWS)
			vertices.append(Vector3(uv.x * SOURCE_SIZE.x, uv.y * SOURCE_SIZE.y, 0))
			uvs.append(uv)
	for y in ROWS:
		for x in COLUMNS:
			var i := y * (COLUMNS + 1) + x
			indices.append_array(PackedInt32Array([i, i + 1, i + COLUMNS + 1, i + 1, i + COLUMNS + 2, i + COLUMNS + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _fit() -> void:
	if not is_instance_valid(drawing): return
	var factor := maxf(size.x / source_size.x, size.y / source_size.y) if fit_cover else minf(size.x / source_size.x, size.y / source_size.y)
	drawing.scale = source_size / SOURCE_SIZE * factor
	drawing.position = (size - source_size * factor) * 0.5

func _pointer_gaze() -> Vector2:
	var delta := pointer - get_global_rect().get_center()
	return Vector2(clampf(delta.x / 480.0, -1, 1), clampf(delta.y / 360.0, -1, 1))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = get_canvas_transform().affine_inverse() * event.position

func react(guarded: bool = false) -> void:
	recoil = 0.35 if guarded else 1.0
	resolve_glow = 1.0

func affirm() -> void:
	resolve_glow = 1.0

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	# Wall clock keeps the pose continuous when the battle rebuilds status labels.
	var seconds := Time.get_ticks_msec() / 1000.0
	gaze = gaze.lerp(_pointer_gaze(), 1.0 - exp(-delta * 7.0))
	var phase := fmod(seconds + phase_offset, 5.6)
	var blink := 0.0
	if phase < 0.20: blink = sin(PI * phase / 0.20)
	if phase > 0.32 and phase < 0.48 and int(seconds / 5.6) % 3 == 0: blink = sin(PI * (phase - 0.32) / 0.16)
	if blink_override >= 0: blink = blink_override
	if resting:
		seconds = 0
		gaze = Vector2.ZERO
		blink = 1
	recoil = move_toward(recoil, 0, delta * 3.8)
	resolve_glow = move_toward(resolve_glow, 0, delta * 1.4)
	rig.set_shader_parameter("clock_seconds", seconds)
	rig.set_shader_parameter("gaze", gaze)
	rig.set_shader_parameter("blink", blink)
	rig.set_shader_parameter("recoil", recoil)
	rig.set_shader_parameter("resolve_glow", resolve_glow)
