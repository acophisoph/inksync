## MainMenu — entry point for InkSync.
## Three mode cards: Drawing, Map Editor, Character Mode.
## All UI built in code — no .tscn dependencies.

extends Node2D

# ── Mode definitions ──────────────────────────────────────────────────────────
const MODES := [
	{
		"icon":   "◎",
		"title":  "Drawing Mode",
		"desc":   "Trace shapes and free-draw\nprompts in sync with the beat.\nScore every stroke.",
		"accent": Color(1.0, 0.78, 0.2),
		"scene":  "res://scenes/SongSelect.tscn",
	},
	{
		"icon":   "卷",
		"title":  "Story Mode",
		"desc":   "Listen to a story in Mandarin.\nPaint the world to life by\nwriting each character.",
		"accent": Color(0.55, 0.88, 0.50),
		"scene":  "res://scenes/StorySelect.tscn",
	},
	{
		"icon":   "漢",
		"title":  "Character Mode",
		"desc":   "Practice Chinese characters\nstroke by stroke, guided\nby rhythm.",
		"accent": Color(1.0, 0.48, 0.48),
		"scene":  "res://scenes/CharacterMode.tscn",
	},
	{
		"icon":   "✦",
		"title":  "Map Editor",
		"desc":   "Build beatmaps and stroke\nchallenges. Share them with\nthe community.",
		"accent": Color(0.35, 0.72, 1.0),
		"scene":  "res://scenes/EditMode.tscn",
	},
]

# Background ink blobs — decorative, slowly pulsing
var _blobs : Array = []

func _ready() -> void:
	_init_blobs()
	_build_background()
	_build_ui()

# ── Decorative background ─────────────────────────────────────────────────────

func _init_blobs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 12:
		_blobs.append({
			"pos":    Vector2(rng.randf_range(60, 1220), rng.randf_range(60, 660)),
			"radius": rng.randf_range(30, 90),
			"phase":  rng.randf_range(0, TAU),
			"speed":  rng.randf_range(0.3, 0.8),
			"color":  Color(rng.randf_range(0.1, 0.3), rng.randf_range(0.1, 0.3),
						   rng.randf_range(0.25, 0.45), rng.randf_range(0.04, 0.1)),
		})

func _process(delta: float) -> void:
	for b in _blobs:
		b["phase"] += delta * b["speed"]
	queue_redraw()

func _draw() -> void:
	for b in _blobs:
		var r : float = b["radius"] * (0.85 + 0.15 * sin(b["phase"]))
		draw_circle(b["pos"], r, b["color"])

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.size  = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

# ── UI layout ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	layer.add_child(root)

	root.add_child(_build_header())

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	root.add_child(spacer1)

	root.add_child(_build_cards_row())

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer2)

	root.add_child(_build_footer())

func _build_header() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 200)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "InkSync"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Draw in sync. Level up both skills."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68, 0.85))
	box.add_child(sub)

	return box

func _build_cards_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.custom_minimum_size = Vector2(0, 320)

	for mode in MODES:
		row.add_child(_build_card(mode))

	return row

func _build_card(mode: Dictionary) -> Control:
	var accent : Color = mode["accent"]

	# Outer container for margin
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   2)
	outer.add_theme_constant_override("margin_right",  2)
	outer.add_theme_constant_override("margin_top",    2)
	outer.add_theme_constant_override("margin_bottom", 2)

	# The button itself
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(290, 300)
	btn.focus_mode = Control.FOCUS_NONE

	# Normal style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color          = Color(0.12, 0.12, 0.18, 0.92)
	style_normal.border_width_left  = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top   = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color       = Color(accent.r, accent.g, accent.b, 0.35)
	style_normal.corner_radius_top_left     = 14
	style_normal.corner_radius_top_right    = 14
	style_normal.corner_radius_bottom_left  = 14
	style_normal.corner_radius_bottom_right = 14
	btn.add_theme_stylebox_override("normal", style_normal)

	# Hover style
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color          = Color(0.16, 0.16, 0.24, 0.97)
	style_hover.border_width_left  = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top   = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color       = accent
	style_hover.corner_radius_top_left     = 14
	style_hover.corner_radius_top_right    = 14
	style_hover.corner_radius_bottom_left  = 14
	style_hover.corner_radius_bottom_right = 14
	btn.add_theme_stylebox_override("hover", style_hover)

	# Pressed style
	var style_press := StyleBoxFlat.new()
	style_press.bg_color          = Color(0.1, 0.1, 0.15, 0.97)
	style_press.border_width_left  = 2
	style_press.border_width_right = 2
	style_press.border_width_top   = 2
	style_press.border_width_bottom = 2
	style_press.border_color       = accent.lightened(0.2)
	style_press.corner_radius_top_left     = 14
	style_press.corner_radius_top_right    = 14
	style_press.corner_radius_bottom_left  = 14
	style_press.corner_radius_bottom_right = 14
	btn.add_theme_stylebox_override("pressed", style_press)

	# Card content (vertical layout inside button)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	btn.add_child(vbox)

	# Icon
	var icon_label := Label.new()
	icon_label.text = mode["icon"]
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 52)
	icon_label.add_theme_color_override("font_color", accent)
	vbox.add_child(icon_label)

	# Title
	var title_label := Label.new()
	title_label.text = mode["title"]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(title_label)

	# Divider line (drawn as a tiny ColorRect)
	var divider := ColorRect.new()
	divider.color = Color(accent.r, accent.g, accent.b, 0.4)
	divider.custom_minimum_size = Vector2(160, 1)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(divider)

	# Description
	var desc_label := Label.new()
	desc_label.text = mode["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.85))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Wire up the button
	var scene_path : String = mode["scene"]
	btn.pressed.connect(func(): _go_to(scene_path))

	outer.add_child(btn)
	return outer

func _build_footer() -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 40)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var ver := Label.new()
	ver.text = "v0.1.0 — open source, community-driven"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45, 0.7))
	box.add_child(ver)

	return box

func _go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
