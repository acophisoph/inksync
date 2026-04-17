## StoryMode — narrative character-practice session.
##
## Loads a story.json, shows the layered silhouette background,
## optionally plays Mandarin narration, then sequences the player through
## each character in the story. Completing a character reveals its scene layer
## in full colour. When all characters are done the scene is fully painted.
##
## Flow (across scene changes):
##   StoryMode (idx=0) → CharacterPractice → StoryMode (idx=1, reveals layer 0)
##   → CharacterPractice → … → StoryMode (idx=N, all layers revealed) → done!
##
## GameState fields used:
##   story_path        — absolute res:// path to the story.json
##   story_char_index  — next character to practice (incremented by CharacterPractice)

extends Node2D

var _story     : Dictionary = {}
var _layers    : Array      = []   # ordered layer entries from JSON
var _bg        : StoryBackground
var _narration : AudioStreamPlayer

var _hud_layer   : CanvasLayer
var _title_label : Label
var _sub_label   : Label
var _cue_label   : Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_story()
	_build_scene()
	_restore_and_advance()

# ── Story loading ─────────────────────────────────────────────────────────────

func _load_story() -> void:
	var path := GameState.story_path
	if path == "":
		push_error("StoryMode: GameState.story_path is empty.")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("StoryMode: cannot open '%s'" % path)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("StoryMode: JSON parse error in '%s'" % path)
		return
	var data : Variant = json.get_data()
	if data is Dictionary:
		_story  = data
		_layers = _story.get("layers", [])

# ── Scene building ────────────────────────────────────────────────────────────

func _build_scene() -> void:
	# Paper background
	var bg_arr : Array = _story.get("background_color", [0.94, 0.91, 0.84])
	var bg := ColorRect.new()
	bg.color    = Color(float(bg_arr[0]), float(bg_arr[1]), float(bg_arr[2]))
	bg.size     = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Story layers
	_bg = StoryBackground.new()
	add_child(_bg)
	for layer_data in _layers:
		_bg.add_layer(layer_data)

	# Narration audio (optional)
	_narration = AudioStreamPlayer.new()
	add_child(_narration)
	var nar_path : String = _story.get("narration", "")
	if nar_path != "" and ResourceLoader.exists(nar_path):
		_narration.stream = load(nar_path) as AudioStream

	# HUD
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	# Title (Chinese + English)
	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top    = 18
	_title_label.offset_bottom = 64
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.14, 0.10, 0.08, 0.88))
	var title_cn : String = _story.get("title", "")
	var title_en : String = _story.get("title_en", "")
	_title_label.text = (title_cn + "  —  " + title_en) if title_en != "" else title_cn
	_hud_layer.add_child(_title_label)

	# Sub-label (character description / story excerpt)
	_sub_label = Label.new()
	_sub_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sub_label.offset_top    = 64
	_sub_label.offset_bottom = 96
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 16)
	_sub_label.add_theme_color_override("font_color", Color(0.30, 0.22, 0.16, 0.65))
	_hud_layer.add_child(_sub_label)

	# Bottom cue
	_cue_label = Label.new()
	_cue_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cue_label.offset_top    = -60
	_cue_label.offset_bottom = -16
	_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue_label.add_theme_font_size_override("font_size", 20)
	_cue_label.add_theme_color_override("font_color", Color(0.14, 0.10, 0.08, 0.75))
	_hud_layer.add_child(_cue_label)

	# Back button
	var back := Button.new()
	back.text = "← Stories"
	back.focus_mode = Control.FOCUS_NONE
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left   = 12
	back.offset_top    = 12
	back.offset_right  = 128
	back.offset_bottom = 44
	back.add_theme_font_size_override("font_size", 15)
	var bs := StyleBoxFlat.new()
	bs.bg_color    = Color(0.1, 0.08, 0.06, 0.75)
	bs.border_color = Color(0.4, 0.3, 0.2, 0.5)
	bs.border_width_left   = 1; bs.border_width_right  = 1
	bs.border_width_top    = 1; bs.border_width_bottom = 1
	bs.corner_radius_top_left     = 6; bs.corner_radius_top_right    = 6
	bs.corner_radius_bottom_left  = 6; bs.corner_radius_bottom_right = 6
	back.add_theme_stylebox_override("normal", bs)
	back.pressed.connect(func():
		GameState.story_path       = ""
		GameState.story_char_index = 0
		get_tree().change_scene_to_file("res://scenes/StorySelect.tscn")
	)
	_hud_layer.add_child(back)

# ── Session restore + advance ─────────────────────────────────────────────────

func _restore_and_advance() -> void:
	var idx : int = GameState.story_char_index

	# Instantly restore all layers that were already completed
	for i in min(idx, _layers.size()):
		var lid : String = (_layers[i] as Dictionary).get("id", "")
		_bg.reveal_instant(lid)

	if idx == 0:
		# First entry — start narration and go to first character
		if _narration.stream:
			_narration.play()
		await _show_next_character_prompt(idx)
	elif idx <= _layers.size():
		# Returning from a completed character — animate that reveal then continue
		var just_done : Dictionary = _layers[idx - 1]
		_bg.reveal(just_done.get("id", ""))

		var ch   : String = just_done.get("character", "")
		var desc : String = just_done.get("description", "")
		_cue_label.text = '✦  "%s" painted into the world' % ch
		_sub_label.text = desc
		await get_tree().create_timer(StoryBackground.REVEAL_DURATION + 0.4).timeout

		if idx >= _layers.size():
			await _story_complete()
			return

		await _show_next_character_prompt(idx)
	else:
		await _story_complete()

func _show_next_character_prompt(idx: int) -> void:
	if idx >= _layers.size():
		return
	var layer : Dictionary = _layers[idx]
	var ch    : String     = layer.get("character", "")
	var desc  : String     = layer.get("description", "")

	_cue_label.text = "Next: paint  %s  (%d / %d)" % [ch, idx + 1, _layers.size()]
	_sub_label.text = desc
	await get_tree().create_timer(1.5).timeout

	GameState.character = ch
	get_tree().change_scene_to_file("res://scenes/CharacterPractice.tscn")

func _story_complete() -> void:
	_cue_label.text  = "✦  The story is complete  ✦"
	_sub_label.text  = _story.get("ending", "")
	_title_label.add_theme_color_override("font_color", Color(0.55, 0.38, 0.08, 1.0))

	# Gentle pulse on the title
	var tw := create_tween().set_loops()
	tw.tween_property(_title_label, "modulate:a", 0.6, 1.4)
	tw.tween_property(_title_label, "modulate:a", 1.0, 1.4)
