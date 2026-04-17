## StoryBackground — layered ink-to-colour scene background.
##
## Each layer starts as a faint ink silhouette and blooms into full colour
## when the player completes its character.
##
## Layers are driven entirely by story.json:
##   image  (optional) — path to a PNG; uses desaturate shader for reveal
##   rect   (fallback)  — [x, y, w, h] coloured placeholder rectangle
##   color              — [r, g, b] target colour when fully revealed
##   z                  — draw order

class_name StoryBackground
extends Node2D

const SILHOUETTE_ALPHA := 0.15
const SILHOUETTE_COLOR := Color(0.20, 0.16, 0.12, SILHOUETTE_ALPHA)
const REVEAL_DURATION  := 2.2

var _layers : Dictionary = {}   # id -> { node, cr, mat, full_color, revealed }

# ── Public API ────────────────────────────────────────────────────────────────

func add_layer(data: Dictionary) -> void:
	var id      : String = data.get("id", "layer_%d" % _layers.size())
	var image   : String = data.get("image", "")
	var col_arr : Array  = data.get("color", [0.5, 0.5, 0.5])
	var col     := Color(col_arr[0], col_arr[1], col_arr[2], 1.0)
	var z_val   : int    = data.get("z", 0)

	var entry : Dictionary = { "revealed": false, "full_color": col,
								"cr": null, "mat": null }

	if image != "" and ResourceLoader.exists(image):
		entry["node"] = _make_image_layer(image, z_val, entry)
	else:
		entry["node"] = _make_placeholder_layer(data, col, z_val, entry)

	add_child(entry["node"])
	_layers[id] = entry

## Reveal a layer instantly (used when restoring session on re-entry).
func reveal_instant(id: String) -> void:
	if not _layers.has(id):
		return
	var entry : Dictionary = _layers[id]
	if entry["revealed"]:
		return
	entry["revealed"] = true
	var col : Color = entry["full_color"]
	if entry["mat"] != null:
		var mat : ShaderMaterial = entry["mat"]
		mat.set_shader_parameter("saturation",  1.0)
		mat.set_shader_parameter("alpha_scale", 1.0)
	elif entry["cr"] != null:
		var cr : ColorRect = entry["cr"]
		cr.color = Color(col.r, col.g, col.b, 0.88)

## Animate reveal over REVEAL_DURATION seconds.
func reveal(id: String) -> void:
	if not _layers.has(id):
		return
	var entry : Dictionary = _layers[id]
	if entry["revealed"]:
		return
	entry["revealed"] = true
	var col : Color = entry["full_color"]

	if entry["mat"] != null:
		var mat : ShaderMaterial = entry["mat"]
		var tw := create_tween().set_parallel(true)
		tw.tween_method(
			func(v: float): mat.set_shader_parameter("saturation", v),
			0.0, 1.0, REVEAL_DURATION)
		tw.tween_method(
			func(v: float): mat.set_shader_parameter("alpha_scale", v),
			SILHOUETTE_ALPHA, 1.0, REVEAL_DURATION)
	elif entry["cr"] != null:
		var cr        : ColorRect = entry["cr"]
		var start_col := SILHOUETTE_COLOR
		var end_col   := Color(col.r, col.g, col.b, 0.88)
		var tw := create_tween()
		tw.tween_method(
			func(t: float): cr.color = start_col.lerp(end_col, t),
			0.0, 1.0, REVEAL_DURATION)

# ── Private builders ──────────────────────────────────────────────────────────

func _make_image_layer(image: String, z_val: int, entry: Dictionary) -> Node2D:
	var container := Node2D.new()
	container.z_index = z_val

	var tex := TextureRect.new()
	tex.texture = load(image) as Texture2D
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)

	var shader_res : Resource = load("res://shaders/desaturate.gdshader")
	if shader_res:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res as Shader
		mat.set_shader_parameter("saturation",  0.0)
		mat.set_shader_parameter("alpha_scale", SILHOUETTE_ALPHA)
		tex.material = mat
		entry["mat"] = mat

	container.add_child(tex)
	return container

func _make_placeholder_layer(data: Dictionary, col: Color, z_val: int,
		entry: Dictionary) -> Node2D:
	var rect_arr : Array = data.get("rect", [0, 0, 200, 200])
	var container := Node2D.new()
	container.z_index = z_val

	var cr := ColorRect.new()
	cr.position = Vector2(float(rect_arr[0]), float(rect_arr[1]))
	cr.size     = Vector2(float(rect_arr[2]), float(rect_arr[3]))
	cr.color    = SILHOUETTE_COLOR
	container.add_child(cr)
	entry["cr"] = cr
	return container
