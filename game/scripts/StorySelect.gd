## StorySelect — browse and launch story-mode sessions.
##
## Scans assets/stories/ for any subdirectory that contains a story.json.
## Displays a card for each story showing its title and progress.
## Drop a new folder with a story.json to make it appear here automatically.

extends Node2D

const STORIES_DIR := "res://assets/stories/"

var _stories : Array = []   # [{path, title, title_en, total, completed}]

func _ready() -> void:
	_scan_stories()
	_build_background()
	_build_ui()

# ── Story scanning ────────────────────────────────────────────────────────────

func _scan_stories() -> void:
	var dir := DirAccess.open(STORIES_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var json_path := STORIES_DIR + entry + "/story.json"
			if FileAccess.file_exists(json_path):
				var info := _read_story_meta(json_path)
				if not info.is_empty():
					_stories.append(info)
		entry = dir.get_next()
	dir.list_dir_end()
	_stories.sort_custom(func(a, b): return a["title_en"] < b["title_en"])

func _read_story_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	var data : Variant = json.get_data()
	if not data is Dictionary:
		return {}
	var d : Dictionary = data
	var layers : Array = d.get("layers", [])
	return {
		"path":     path,
		"title":    d.get("title",    ""),
		"title_en": d.get("title_en", path.get_base_dir().get_file()),
		"desc":     d.get("description", ""),
		"total":    layers.size(),
	}

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.07, 0.07, 0.11)
	bg.size     = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 60
	top.add_theme_constant_override("separation", 16)
	layer.add_child(top)

	var back := _make_button("← Menu", Color(0.4, 0.4, 0.55))
	back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	top.add_child(back)

	var title := Label.new()
	title.text = "Story Mode"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	top.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(108, 0)
	top.add_child(gap)

	if _stories.is_empty():
		_build_empty_state(layer)
	else:
		_build_story_grid(layer)

func _build_empty_state(layer: CanvasLayer) -> void:
	var lbl := Label.new()
	lbl.text = (
		"No stories found.\n\n" +
		"Add a folder to  assets/stories/  containing a  story.json.\n" +
		"See  assets/stories/demo/story.json  for the format."
	)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left  = -360
	lbl.offset_right =  360
	lbl.offset_top   = -80
	lbl.offset_bottom = 80
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.58))
	layer.add_child(lbl)

func _build_story_grid(layer: CanvasLayer) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top  = 64
	scroll.offset_left = 40
	scroll.offset_right  = -40
	scroll.offset_bottom = -20
	layer.add_child(scroll)

	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid)

	for story in _stories:
		grid.add_child(_build_card(story))

func _build_card(story: Dictionary) -> Control:
	var accent := Color(0.55, 0.85, 0.50)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(340, 200)
	btn.focus_mode = Control.FOCUS_NONE

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.13, 0.10, 0.92)
	sn.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	sn.border_width_left   = 2; sn.border_width_right  = 2
	sn.border_width_top    = 2; sn.border_width_bottom = 2
	sn.corner_radius_top_left     = 12; sn.corner_radius_top_right    = 12
	sn.corner_radius_bottom_left  = 12; sn.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", sn)

	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.16, 0.18, 0.13, 0.97)
	sh.border_color = accent
	sh.border_width_left   = 2; sh.border_width_right  = 2
	sh.border_width_top    = 2; sh.border_width_bottom = 2
	sh.corner_radius_top_left     = 12; sh.corner_radius_top_right    = 12
	sh.corner_radius_bottom_left  = 12; sh.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("hover", sh)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	btn.add_child(vbox)

	# Chinese title
	var cn := Label.new()
	cn.text = story["title"]
	cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cn.add_theme_font_size_override("font_size", 36)
	cn.add_theme_color_override("font_color", accent)
	vbox.add_child(cn)

	# English title
	var en := Label.new()
	en.text = story["title_en"]
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.add_theme_font_size_override("font_size", 18)
	en.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	vbox.add_child(en)

	# Divider
	var div := ColorRect.new()
	div.color = Color(accent.r, accent.g, accent.b, 0.3)
	div.custom_minimum_size = Vector2(200, 1)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(div)

	# Description
	if story["desc"] != "":
		var desc := Label.new()
		desc.text = story["desc"]
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52, 0.85))
		vbox.add_child(desc)

	# Character count
	var count := Label.new()
	count.text = "%d characters" % story["total"]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 13)
	count.add_theme_color_override("font_color", Color(0.4, 0.45, 0.38, 0.7))
	vbox.add_child(count)

	var story_path : String = story["path"]
	btn.pressed.connect(func():
		GameState.story_path       = story_path
		GameState.story_char_index = 0
		get_tree().change_scene_to_file("res://scenes/StoryMode.tscn")
	)
	return btn

func _make_button(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(108, 36)
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, 0.7)
	s.border_color = Color(col.r, col.g, col.b, 0.4)
	s.border_width_left   = 1; s.border_width_right  = 1
	s.border_width_top    = 1; s.border_width_bottom = 1
	s.corner_radius_top_left     = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6; s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", s)
	return btn
