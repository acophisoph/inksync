## SongSelect — choose a song and set BPM before entering Drawing Mode.
##
## Scans assets/music/ for .ogg / .mp3 / .wav files automatically.
## BPM can be typed manually or tapped out live.

extends Node2D

const MUSIC_DIR    := "res://assets/music/"
const AUDIO_EXTS   := ["ogg", "mp3", "wav"]
const TAP_TIMEOUT  := 2.0
const MAX_TAP_HIST := 8
const BPM_CACHE    := "user://bpm_cache.json"

var _songs          : Array[String] = []
var _selected_index : int   = -1
var _bpm            : float = 90.0

var _tap_times      : Array[float] = []
var _last_tap_time  : float = -99.0

# UI refs
var _song_buttons   : Array[Button] = []
var _bpm_display    : Label
var _tap_btn        : Button
var _start_btn      : Button
var _preview_player : AudioStreamPlayer
var _status_label   : Label

func _ready() -> void:
	_scan_songs()
	_build_background()
	_bpm = _load_bpm_for("")   # will be overridden on song select
	_build_ui()
	# If a song was previously chosen, restore it so the user can hit Start immediately
	if GameState.song_path != "":
		var idx := _songs.find(GameState.song_path)
		if idx >= 0:
			_selected_index = idx
			_bpm = GameState.bpm
			_update_bpm_display()
			# Highlight the button (UI is already built at this point)
			if idx < _song_buttons.size():
				var s := StyleBoxFlat.new()
				s.bg_color = Color(0.18, 0.22, 0.35)
				s.border_color = Color(1.0, 0.78, 0.2, 0.8)
				s.border_width_left   = 2
				s.border_width_right  = 2
				s.border_width_top    = 2
				s.border_width_bottom = 2
				s.corner_radius_top_left     = 6
				s.corner_radius_top_right    = 6
				s.corner_radius_bottom_left  = 6
				s.corner_radius_bottom_right = 6
				_song_buttons[idx].add_theme_stylebox_override("normal", s)
			_status_label.text = GameState.song_path.get_file().get_basename()
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2, 0.9))
	_refresh_start_btn()

# ── Song scanning ─────────────────────────────────────────────────────────────

func _scan_songs() -> void:
	var dir := DirAccess.open(MUSIC_DIR)
	if not dir:
		push_warning("SongSelect: could not open " + MUSIC_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var ext := fname.get_extension().to_lower()
		if ext in AUDIO_EXTS:
			_songs.append(MUSIC_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_songs.sort()

# ── Background ────────────────────────────────────────────────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.07, 0.07, 0.11)
	bg.size     = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_preview_player = AudioStreamPlayer.new()
	add_child(_preview_player)

	var layer := CanvasLayer.new()
	add_child(layer)

	# ── Top bar ──
	var top_bar := _make_top_bar()
	layer.add_child(top_bar)

	# ── Main two-column layout ──
	var columns := HBoxContainer.new()
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.offset_top    = 64
	columns.offset_bottom = -80
	columns.offset_left   = 40
	columns.offset_right  = -40
	columns.add_theme_constant_override("separation", 32)
	layer.add_child(columns)

	# Left: song list
	columns.add_child(_build_song_list())

	# Right: BPM panel
	columns.add_child(_build_bpm_panel())

	# ── Bottom bar ──
	var bottom := _make_bottom_bar()
	layer.add_child(bottom)

func _make_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 56
	bar.add_theme_constant_override("separation", 16)

	var back := _make_small_button("← Menu", Color(0.4, 0.4, 0.55))
	back.offset_left = 16
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	bar.add_child(back)

	var title := Label.new()
	title.text = "Select a Song"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	bar.add_child(title)

	# Spacer to balance the back button
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(100, 0)
	bar.add_child(gap)

	return bar

func _build_song_list() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "♪  Songs  (%d found)" % _songs.size()
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65, 0.8))
	header.add_theme_constant_override("margin_left", 12)
	vbox.add_child(header)

	if _songs.is_empty():
		var empty := Label.new()
		empty.text = "No songs found.\nDrop .ogg / .mp3 / .wav files\ninto assets/music/"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(empty)
	else:
		for i in _songs.size():
			var btn := _make_song_button(i)
			vbox.add_child(btn)
			_song_buttons.append(btn)

	return panel

func _make_song_button(index: int) -> Button:
	var path        := _songs[index]
	var display     := path.get_file().get_basename()

	var btn := Button.new()
	btn.text = "♪   " + display
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 17)

	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = Color(0.12, 0.12, 0.18, 0.0)
	s_normal.corner_radius_top_left     = 6
	s_normal.corner_radius_top_right    = 6
	s_normal.corner_radius_bottom_left  = 6
	s_normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", s_normal)

	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = Color(0.18, 0.18, 0.28)
	s_hover.corner_radius_top_left     = 6
	s_hover.corner_radius_top_right    = 6
	s_hover.corner_radius_bottom_left  = 6
	s_hover.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", s_hover)

	btn.pressed.connect(func(): _select_song(index))
	return btn

func _build_bpm_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Section label
	var section := Label.new()
	section.text = "BPM"
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_theme_font_size_override("font_size", 15)
	section.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65, 0.8))
	vbox.add_child(section)

	# Big BPM number
	_bpm_display = Label.new()
	_bpm_display.text = str(int(_bpm))
	_bpm_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bpm_display.add_theme_font_size_override("font_size", 80)
	_bpm_display.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	vbox.add_child(_bpm_display)

	# +/- nudge buttons
	var nudge_row := HBoxContainer.new()
	nudge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nudge_row.add_theme_constant_override("separation", 8)
	vbox.add_child(nudge_row)

	for delta in [-5, -1, 1, 5]:
		var lbl := "−5" if delta == -5 else ("−1" if delta == -1 else ("+1" if delta == 1 else "+5"))
		var nb := _make_nudge_button(lbl, delta)
		nudge_row.add_child(nb)

	# TAP button
	_tap_btn = Button.new()
	_tap_btn.text = "TAP  ♩"
	_tap_btn.focus_mode = Control.FOCUS_NONE
	_tap_btn.add_theme_font_size_override("font_size", 22)
	_tap_btn.custom_minimum_size = Vector2(160, 56)

	var tap_style := StyleBoxFlat.new()
	tap_style.bg_color = Color(0.18, 0.22, 0.35)
	tap_style.border_color = Color(0.35, 0.55, 1.0, 0.6)
	tap_style.border_width_left   = 2
	tap_style.border_width_right  = 2
	tap_style.border_width_top    = 2
	tap_style.border_width_bottom = 2
	tap_style.corner_radius_top_left     = 10
	tap_style.corner_radius_top_right    = 10
	tap_style.corner_radius_bottom_left  = 10
	tap_style.corner_radius_bottom_right = 10
	_tap_btn.add_theme_stylebox_override("normal", tap_style)
	_tap_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_tap_btn.pressed.connect(_on_tap)
	vbox.add_child(_tap_btn)

	# Tap hint
	var hint := Label.new()
	hint.text = "Tap to the beat to detect BPM"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	vbox.add_child(hint)

	# Status line (shows selected song name)
	_status_label = Label.new()
	_status_label.text = "No song selected"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.6))
	vbox.add_child(_status_label)

	return panel

func _make_nudge_button(label: String, delta: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(52, 36)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.15, 0.22)
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(func(): _nudge_bpm(delta))
	return btn

func _make_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top    = -72
	bar.offset_left   = 40
	bar.offset_right  = -40
	bar.alignment = BoxContainer.ALIGNMENT_END

	_start_btn = Button.new()
	_start_btn.text = "▶  Start Drawing Mode"
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.add_theme_font_size_override("font_size", 20)
	_start_btn.custom_minimum_size = Vector2(280, 52)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.45, 0.2)
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_left  = 10
	s.corner_radius_bottom_right = 10
	_start_btn.add_theme_stylebox_override("normal", s)

	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = Color(0.2, 0.58, 0.26)
	s_hover.corner_radius_top_left     = 10
	s_hover.corner_radius_top_right    = 10
	s_hover.corner_radius_bottom_left  = 10
	s_hover.corner_radius_bottom_right = 10
	_start_btn.add_theme_stylebox_override("hover", s_hover)
	_start_btn.add_theme_color_override("font_color", Color(0.9, 1.0, 0.92))
	_start_btn.pressed.connect(_on_start)
	bar.add_child(_start_btn)

	return bar

func _make_small_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(100, 36)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.7)
	s.border_color = Color(color.r, color.g, color.b, 0.4)
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", s)
	return btn

# ── Logic ──────────────────────────────────────────────────────────────────────

func _select_song(index: int) -> void:
	_selected_index = index

	# Highlight selected button
	for i in _song_buttons.size():
		var selected_style := StyleBoxFlat.new()
		if i == index:
			selected_style.bg_color = Color(0.18, 0.22, 0.35)
			selected_style.border_color = Color(1.0, 0.78, 0.2, 0.8)
			selected_style.border_width_left   = 2
			selected_style.border_width_right  = 2
			selected_style.border_width_top    = 2
			selected_style.border_width_bottom = 2
		else:
			selected_style.bg_color = Color(0.12, 0.12, 0.18, 0.0)
		selected_style.corner_radius_top_left     = 6
		selected_style.corner_radius_top_right    = 6
		selected_style.corner_radius_bottom_left  = 6
		selected_style.corner_radius_bottom_right = 6
		_song_buttons[i].add_theme_stylebox_override("normal", selected_style)

	var display := _songs[index].get_file().get_basename()
	_status_label.text = display
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2, 0.9))

	# Restore saved BPM for this song if available
	var saved := _load_bpm_for(_songs[index].get_file())
	if saved > 0.0:
		_bpm = saved
		_update_bpm_display()

	_refresh_start_btn()

	# Preview first 8 seconds (non-blocking — Start is already enabled above)
	var stream: Resource = load(_songs[index])
	if stream:
		_preview_player.stream = stream
		_preview_player.play()
		await get_tree().create_timer(8.0).timeout
		if _preview_player.playing:
			_preview_player.stop()

func _nudge_bpm(delta: int) -> void:
	_bpm = clampf(_bpm + delta, 40.0, 300.0)
	_update_bpm_display()

func _on_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time > TAP_TIMEOUT:
		_tap_times.clear()
	_last_tap_time = now
	_tap_times.append(now)
	if _tap_times.size() > MAX_TAP_HIST:
		_tap_times = _tap_times.slice(_tap_times.size() - MAX_TAP_HIST)
	if _tap_times.size() >= 2:
		var span    := _tap_times[-1] - _tap_times[0]
		var avg_gap := span / (_tap_times.size() - 1)
		_bpm = clampf(roundf(60.0 / avg_gap), 40.0, 300.0)
		_update_bpm_display()

func _update_bpm_display() -> void:
	_bpm_display.text = str(int(_bpm))

func _refresh_start_btn() -> void:
	if _start_btn:
		_start_btn.disabled = _selected_index < 0

func _on_start() -> void:
	if _selected_index < 0:
		return
	_preview_player.stop()
	_save_bpm_for(_songs[_selected_index].get_file(), _bpm)
	GameState.song_path = _songs[_selected_index]
	GameState.bpm       = _bpm
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ── BPM cache (user://bpm_cache.json) ────────────────────────────────────────

func _load_bpm_cache() -> Dictionary:
	if not FileAccess.file_exists(BPM_CACHE):
		return {}
	var f := FileAccess.open(BPM_CACHE, FileAccess.READ)
	if not f:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		var data: Variant = json.get_data()
		if data is Dictionary:
			return data
	return {}

func _load_bpm_for(song_file: String) -> float:
	if song_file == "":
		return 90.0
	var cache := _load_bpm_cache()
	if cache.has(song_file):
		return float(cache[song_file])
	return 90.0

func _save_bpm_for(song_file: String, bpm_val: float) -> void:
	var cache := _load_bpm_cache()
	cache[song_file] = bpm_val
	var f := FileAccess.open(BPM_CACHE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cache))
