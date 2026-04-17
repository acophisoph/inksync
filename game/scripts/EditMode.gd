## EditMode — InkSync Map Editor.
##
## Create beatmaps (.inkmap files) by:
##   1. Loading a song from assets/music/
##   2. Setting BPM
##   3. Clicking the timeline to place draw windows
##   4. Drawing the reference stroke for each window
##   5. Saving as a .inkmap JSON file to user://maps/
##
## .inkmap format:
##   { "title", "song", "bpm", "challenges": [{ "beat", "duration", "prompt", "stroke" }] }

extends Node2D

const MUSIC_DIR  := "res://assets/music/"
const AUDIO_EXTS := ["ogg", "mp3", "wav"]
const MAPS_DIR   := "user://maps/"
const PX_PER_BEAT := 60.0   # timeline pixels per beat
const VISIBLE_BEATS := 20

var _inkmap : Dictionary = {
	"title":      "Untitled Map",
	"song":       "",
	"bpm":        90.0,
	"challenges": [],
}

var _songs           : Array[String] = []
var _audio           : AudioStreamPlayer
var _selected_chall  : int = -1   # index into _inkmap.challenges, -1 = none
var _is_playing      : bool = false
@warning_ignore("unused_private_class_variable")
var _timeline_offset : float = 0.0   # scroll offset in beats (read/written by _TimelineNode)
var _drawing_enabled : bool = false
var _current_stroke  : Array = []
var _is_drawing      : bool = false
var _saved_strokes   : Array[PackedVector2Array] = []

# UI refs
var _song_option     : OptionButton
var _bpm_label       : Label
var _title_edit      : LineEdit
var _props_panel     : Control
var _props_prompt    : LineEdit
var _props_beat      : Label
var _canvas_node     : Node2D
var _timeline_node   : Control
var _play_btn        : Button
var _save_btn        : Button

func _ready() -> void:
	_scan_songs()
	_ensure_maps_dir()
	_build_background()
	_build_ui()

func _scan_songs() -> void:
	var dir := DirAccess.open(MUSIC_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.get_extension().to_lower() in AUDIO_EXTS:
			_songs.append(MUSIC_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_songs.sort()

func _ensure_maps_dir() -> void:
	if not DirAccess.dir_exists_absolute(MAPS_DIR.replace("user://",
		OS.get_user_data_dir() + "/")):
		DirAccess.make_dir_absolute(MAPS_DIR.replace("user://",
			OS.get_user_data_dir() + "/"))

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.06, 0.06, 0.09)
	bg.size     = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

func _build_ui() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	var layer := CanvasLayer.new()
	add_child(layer)

	layer.add_child(_build_top_bar())
	layer.add_child(_build_main_area())
	layer.add_child(_build_timeline_panel())

func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 52

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.16)
	bar.add_theme_stylebox_override("panel", s)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	# Back
	var back := _small_btn("← Menu")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	hbox.add_child(back)

	_add_separator(hbox)

	# Title field
	var title_lbl := Label.new()
	title_lbl.text = "Title:"
	title_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hbox.add_child(title_lbl)

	_title_edit = LineEdit.new()
	_title_edit.text = "Untitled Map"
	_title_edit.custom_minimum_size = Vector2(160, 0)
	_title_edit.text_changed.connect(func(t: String): _inkmap["title"] = t)
	hbox.add_child(_title_edit)

	_add_separator(hbox)

	# Song dropdown
	var song_lbl := Label.new()
	song_lbl.text = "Song:"
	song_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hbox.add_child(song_lbl)

	_song_option = OptionButton.new()
	_song_option.custom_minimum_size = Vector2(220, 0)
	_song_option.add_item("— select —")
	for sp in _songs:
		_song_option.add_item(sp.get_file().get_basename())
	_song_option.item_selected.connect(_on_song_selected)
	hbox.add_child(_song_option)

	_add_separator(hbox)

	# BPM
	var bpm_lbl := Label.new()
	bpm_lbl.text = "BPM:"
	bpm_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hbox.add_child(bpm_lbl)

	_bpm_label = Label.new()
	_bpm_label.text = "90"
	_bpm_label.custom_minimum_size = Vector2(40, 0)
	_bpm_label.add_theme_font_size_override("font_size", 18)
	_bpm_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	hbox.add_child(_bpm_label)

	var bpm_minus := _small_btn("−")
	bpm_minus.pressed.connect(func(): _nudge_bpm(-5))
	hbox.add_child(bpm_minus)

	var bpm_plus := _small_btn("+")
	bpm_plus.pressed.connect(func(): _nudge_bpm(5))
	hbox.add_child(bpm_plus)

	_add_separator(hbox)

	# Spacer
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	# Play/Stop
	_play_btn = _small_btn("▶ Preview")
	_play_btn.pressed.connect(_toggle_play)
	hbox.add_child(_play_btn)

	_add_separator(hbox)

	# Save
	_save_btn = _small_btn("💾 Save")
	_save_btn.pressed.connect(_save_map)
	hbox.add_child(_save_btn)

	return bar

func _build_main_area() -> Control:
	var area := HBoxContainer.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.offset_top    = 52
	area.offset_bottom = -140
	area.add_theme_constant_override("separation", 0)

	# Canvas area (left 75%)
	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.93, 0.93, 0.91)
	canvas_panel.add_theme_stylebox_override("panel", cs)

	_canvas_node = _DrawCanvasNode.new(self)
	canvas_panel.add_child(_canvas_node)
	area.add_child(canvas_panel)

	# Properties panel (right 25%)
	var props := PanelContainer.new()
	props.custom_minimum_size = Vector2(280, 0)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.1, 0.16)
	props.add_theme_stylebox_override("panel", ps)
	_props_panel = props

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	props.add_child(vbox)

	var ph := Label.new()
	ph.text = "PROPERTIES"
	ph.add_theme_font_size_override("font_size", 13)
	ph.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	vbox.add_child(ph)

	_props_beat = Label.new()
	_props_beat.text = "No challenge selected"
	_props_beat.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(_props_beat)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "Prompt text:"
	prompt_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(prompt_lbl)

	_props_prompt = LineEdit.new()
	_props_prompt.placeholder_text = "e.g. Draw a circle"
	_props_prompt.text_changed.connect(_on_prompt_changed)
	vbox.add_child(_props_prompt)

	var clear_btn := _small_btn("🗑 Clear stroke")
	clear_btn.pressed.connect(_clear_selected_stroke)
	vbox.add_child(clear_btn)

	var help := Label.new()
	help.text = (
		"\nHow to use:\n\n" +
		"1. Select a song above\n" +
		"2. Click the timeline to\n   add a draw window\n" +
		"3. Select a challenge,\n   then draw on the canvas\n" +
		"4. Save when done"
	)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(help)

	area.add_child(props)
	return area

func _build_timeline_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -140

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.13)
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "TIMELINE  —  click to add a draw window  |  ← → scroll"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	vbox.add_child(header)

	_timeline_node = _TimelineNode.new(self)
	_timeline_node.custom_minimum_size = Vector2(0, 90)
	_timeline_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_node.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_timeline_node)

	return panel

# ── Inner classes for custom drawing ─────────────────────────────────────────

class _DrawCanvasNode extends Node2D:
	var _editor: Node

	func _init(editor: Node) -> void:
		_editor = editor

	func _input(event: InputEvent) -> void:
		if not _editor._drawing_enabled:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_editor._is_drawing = true
					_editor._current_stroke = [mb.position]
				else:
					_editor._finish_drawing_stroke()
		elif event is InputEventMouseMotion and _editor._is_drawing:
			_editor._current_stroke.append(event.position)
			queue_redraw()

	func _draw() -> void:
		# Completed strokes
		for stroke in _editor._saved_strokes:
			if stroke.size() >= 2:
				draw_polyline(stroke, Color(0.08, 0.08, 0.12, 0.9), 3.0, true)
		# In-progress stroke
		if _editor._current_stroke.size() >= 2:
			var pts := PackedVector2Array()
			for p in _editor._current_stroke:
				pts.append(p)
			draw_polyline(pts, Color(0.2, 0.5, 1.0, 0.9), 3.0, true)
		# Instruction overlay
		if _editor._selected_chall < 0:
			var r := get_viewport_rect()
			draw_string(
				ThemeDB.fallback_font,
				r.size * 0.5 + Vector2(-200, -10),
				"Select a challenge on the timeline to draw its reference stroke",
				HORIZONTAL_ALIGNMENT_LEFT, 400, 16,
				Color(0.5, 0.5, 0.6, 0.6)
			)


class _TimelineNode extends Control:
	var _editor: Node

	func _init(editor: Node) -> void:
		_editor = editor

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var beat := int(mb.position.x / PX_PER_BEAT) + int(_editor._timeline_offset)
				_editor._add_or_select_challenge(beat)
		if event is InputEventKey and event.pressed:
			var ke := event as InputEventKey
			if ke.keycode == KEY_LEFT:
				_editor._timeline_offset = maxf(0.0, _editor._timeline_offset - 1.0)
				queue_redraw()
			elif ke.keycode == KEY_RIGHT:
				_editor._timeline_offset += 1.0
				queue_redraw()

	func _draw() -> void:
		var h := 90.0
		var bpm : float = _editor._inkmap["bpm"]

		# Beat grid
		for b in VISIBLE_BEATS + 1:
			var beat := b + int(_editor._timeline_offset)
			var x    := b * PX_PER_BEAT
			var is_bar := beat % 4 == 0
			draw_line(Vector2(x, 0), Vector2(x, h),
				Color(0.3, 0.3, 0.45, 0.6 if is_bar else 0.25), 1.0)
			if is_bar:
				draw_string(ThemeDB.fallback_font, Vector2(x + 3, 14),
					str(beat), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.4, 0.4, 0.55))

		# Challenge blocks
		var challenges: Array = _editor._inkmap["challenges"]
		for i in challenges.size():
			var ch    : Dictionary = challenges[i]
			var start : int = ch["beat"]
			var dur   : int = ch["duration"]
			var x0: float = (start - _editor._timeline_offset) * PX_PER_BEAT
			var x1: float = x0 + dur * PX_PER_BEAT
			var col   := Color(0.35, 0.72, 1.0, 0.75) if i != _editor._selected_chall \
				else Color(1.0, 0.78, 0.2, 0.9)
			draw_rect(Rect2(x0, 20, x1 - x0, 55), col)
			draw_string(ThemeDB.fallback_font, Vector2(x0 + 4, 38),
				str(ch.get("prompt", "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.05, 0.05, 0.08))

		# Playhead
		if _editor._is_playing and _editor._audio.playing:
			var beat_pos: float = _editor._audio.get_playback_position() / (60.0 / bpm)
			var px: float = (beat_pos - _editor._timeline_offset) * PX_PER_BEAT
			draw_line(Vector2(px, 0), Vector2(px, h), Color(1.0, 0.4, 0.4, 0.9), 2.0)

# ── Logic ─────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _is_playing and _timeline_node:
		_timeline_node.queue_redraw()

func _add_or_select_challenge(beat: int) -> void:
	# Check if clicking an existing challenge
	var challenges: Array = _inkmap["challenges"]
	for i in challenges.size():
		var ch: Dictionary = challenges[i]
		if beat >= int(ch["beat"]) and beat < int(ch["beat"]) + int(ch["duration"]):
			_select_challenge(i)
			return
	# Create new one
	var new_ch := {
		"beat":     beat,
		"duration": 4,
		"prompt":   "Draw here",
		"stroke":   [],
	}
	challenges.append(new_ch)
	_select_challenge(challenges.size() - 1)
	if _timeline_node:
		_timeline_node.queue_redraw()

func _select_challenge(index: int) -> void:
	_selected_index_set(index)
	var ch: Dictionary = _inkmap["challenges"][index]
	_props_beat.text    = "Beat %d  |  %d beats long" % [ch["beat"], ch["duration"]]
	_props_prompt.text  = ch.get("prompt", "")
	_drawing_enabled    = true

	# Load existing stroke onto canvas
	_saved_strokes.clear()
	var raw: Array = ch.get("stroke", [])
	if raw.size() >= 2:
		var pts := PackedVector2Array()
		for p in raw:
			pts.append(Vector2(p[0], p[1]))
		_saved_strokes.append(pts)
	if _canvas_node:
		_canvas_node.queue_redraw()

func _selected_index_set(idx: int) -> void:
	_selected_chall = idx

func _finish_drawing_stroke() -> void:
	_is_drawing = false
	if _current_stroke.size() < 2 or _selected_chall < 0:
		_current_stroke = []
		return
	var pts := PackedVector2Array()
	for p in _current_stroke:
		pts.append(p)
	_saved_strokes.clear()
	_saved_strokes.append(pts)

	# Save stroke back into the challenge as [[x,y],...]
	var arr := []
	for p in _current_stroke:
		arr.append([p.x, p.y])
	var challenges: Array = _inkmap["challenges"]
	challenges[_selected_chall]["stroke"] = arr
	_current_stroke = []
	if _canvas_node:
		_canvas_node.queue_redraw()

func _clear_selected_stroke() -> void:
	if _selected_chall < 0:
		return
	var challenges: Array = _inkmap["challenges"]
	challenges[_selected_chall]["stroke"] = []
	_saved_strokes.clear()
	if _canvas_node:
		_canvas_node.queue_redraw()

func _on_prompt_changed(text: String) -> void:
	if _selected_chall < 0:
		return
	var challenges: Array = _inkmap["challenges"]
	challenges[_selected_chall]["prompt"] = text
	if _timeline_node:
		_timeline_node.queue_redraw()

func _on_song_selected(idx: int) -> void:
	if idx == 0:
		_inkmap["song"] = ""
		_audio.stop()
		return
	var path := _songs[idx - 1]
	_inkmap["song"] = path.get_file()
	var stream: Resource = load(path)
	if stream:
		_audio.stream = stream

func _toggle_play() -> void:
	if _audio.stream == null:
		return
	_is_playing = not _is_playing
	if _is_playing:
		_audio.play()
		_play_btn.text = "■ Stop"
	else:
		_audio.stop()
		_play_btn.text = "▶ Preview"

func _nudge_bpm(delta: int) -> void:
	_inkmap["bpm"] = clampf(float(_inkmap["bpm"]) + delta, 40.0, 300.0)
	_bpm_label.text = str(int(_inkmap["bpm"]))

func _save_map() -> void:
	var title: String = _inkmap["title"]
	var safe  := title.replace(" ", "_").to_lower()
	var path  := MAPS_DIR + safe + ".inkmap"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("EditMode: could not save to " + path)
		return
	f.store_string(JSON.stringify(_inkmap, "\t"))
	_save_btn.text = "✓ Saved!"
	await get_tree().create_timer(2.0).timeout
	_save_btn.text = "💾 Save"

# ── Helper ────────────────────────────────────────────────────────────────────

func _small_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func _add_separator(container: Control) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(1, 0)
	container.add_child(sep)
