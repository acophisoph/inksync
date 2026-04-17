extends Node2D

# ── Shape library ─────────────────────────────────────────────────────────────
const SHAPES := [
	{"name": "Horizontal Line", "path": "res://assets/strokes/line_h.json"},
	{"name": "Vertical Line",   "path": "res://assets/strokes/line_v.json"},
	{"name": "Diagonal ↘",      "path": "res://assets/strokes/line_diag_r.json"},
	{"name": "Diagonal ↗",      "path": "res://assets/strokes/line_diag_l.json"},
	{"name": "Circle",          "path": "res://assets/strokes/circle.json"},
	{"name": "Wide Ellipse",    "path": "res://assets/strokes/ellipse_wide.json"},
	{"name": "Tall Ellipse",    "path": "res://assets/strokes/ellipse_tall.json"},
	{"name": "C Curve",         "path": "res://assets/strokes/curve_c.json"},
	{"name": "S Curve",         "path": "res://assets/strokes/curve_s.json"},
	{"name": "Square",          "path": "res://assets/strokes/square.json"},
	{"name": "Triangle",        "path": "res://assets/strokes/triangle.json"},
]

const FALLBACK_SONG   := "res://assets/music/song.ogg"
const FALLBACK_BPM    := 90.0
const CYCLE_BEATS     := 8
const DRAW_START      := 4
const DRAW_DURATION   := 4
const FLOW_THRESHOLD  := 4
# ──────────────────────────────────────────────────────────────────────────────

var _audio_player : AudioStreamPlayer
var _beat_clock   : BeatClock
var _canvas       : DrawingCanvas
var _ghost        : GhostStroke
var _analyzer     : StrokeAnalyzer
var _visualizer   : BeatVisualizer
var _overlay      : ScoreOverlay
var _ink_bar      : InkBar
var _flow_vignette : ColorRect

var _cue_label        : Label
var _shape_name_label : Label
var _history_label    : Label
var _flow_label       : Label

var _draw_start_t    : float = 0.0
var _draw_end_t      : float = 0.0
var _shape_idx       : int   = 0
var _session_grades  : Array[String] = []
var _session_started : bool  = false
var _streak          : int   = 0
var _in_flow         : bool  = false

func _ready() -> void:
	_shape_idx = GameState.shape_index
	_build_background()
	_setup_audio()
	_setup_beat_clock()
	_setup_canvas()
	_setup_ghost()
	_setup_analyzer()
	_setup_visualizer()
	_setup_hud()
	_setup_overlay()
	_setup_ink_bar()
	_start_session()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.97, 0.97, 0.95)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	var song := GameState.song_path if GameState.song_path != "" else FALLBACK_SONG
	var stream: Resource = load(song)
	if stream:
		_audio_player.stream = stream
	else:
		push_warning("InkSync: no song at '%s'." % song)

func _setup_beat_clock() -> void:
	_beat_clock = BeatClock.new()
	_beat_clock.bpm = GameState.bpm if GameState.song_path != "" else FALLBACK_BPM
	add_child(_beat_clock)
	_beat_clock.setup(_audio_player)
	_beat_clock.beat_hit.connect(_on_beat)

func _setup_canvas() -> void:
	_canvas = DrawingCanvas.new()
	add_child(_canvas)
	_canvas.setup(_audio_player)
	_canvas.set_drawing_enabled(false)

func _setup_ghost() -> void:
	_ghost = GhostStroke.new()
	add_child(_ghost)
	_ghost.load_from_json(SHAPES[_shape_idx]["path"])

func _setup_analyzer() -> void:
	_analyzer = StrokeAnalyzer.new()
	add_child(_analyzer)

func _setup_visualizer() -> void:
	_visualizer = BeatVisualizer.new()
	add_child(_visualizer)
	_visualizer.position = Vector2(56, 56)
	_visualizer.setup(_beat_clock)

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# ── DRAW cue (center-top) ──
	_cue_label = Label.new()
	_cue_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cue_label.offset_top   = 24
	_cue_label.offset_left  = -220
	_cue_label.offset_right = 220
	_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue_label.add_theme_font_size_override("font_size", 42)
	layer.add_child(_cue_label)
	_set_cue("GET READY", Color(0.5, 0.5, 0.5))

	# ── Shape name (below cue) ──
	_shape_name_label = Label.new()
	_shape_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_shape_name_label.offset_top   = 76
	_shape_name_label.offset_left  = -220
	_shape_name_label.offset_right = 220
	_shape_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shape_name_label.add_theme_font_size_override("font_size", 18)
	_shape_name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	layer.add_child(_shape_name_label)

	# ── Grade history (top-right) ──
	_history_label = Label.new()
	_history_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_history_label.offset_top    = 14
	_history_label.offset_right  = -16
	_history_label.offset_left   = -220
	_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_history_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_history_label)

	# ── Prev / Next shape buttons ──
	var prev_btn := _make_nav_button("◀")
	prev_btn.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	prev_btn.offset_top    = -20
	prev_btn.offset_bottom = 20
	prev_btn.offset_left   = 12
	prev_btn.offset_right  = 52
	prev_btn.pressed.connect(func(): _change_shape(_shape_idx - 1))
	layer.add_child(prev_btn)

	var next_btn := _make_nav_button("▶")
	next_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	next_btn.offset_top    = -20
	next_btn.offset_bottom = 20
	next_btn.offset_left   = -52
	next_btn.offset_right  = -12
	next_btn.pressed.connect(func(): _change_shape(_shape_idx + 1))
	layer.add_child(next_btn)

	# ── Back button (top-left) ──
	var back := Button.new()
	back.text = "← Menu"
	back.focus_mode = Control.FOCUS_NONE
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left   = 12
	back.offset_top    = 12
	back.offset_right  = 110
	back.offset_bottom = 44
	back.add_theme_font_size_override("font_size", 15)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.1, 0.15, 0.75)
	bs.border_color = Color(0.4, 0.4, 0.5, 0.5)
	bs.border_width_left   = 1
	bs.border_width_right  = 1
	bs.border_width_top    = 1
	bs.border_width_bottom = 1
	bs.corner_radius_top_left     = 6
	bs.corner_radius_top_right    = 6
	bs.corner_radius_bottom_left  = 6
	bs.corner_radius_bottom_right = 6
	back.add_theme_stylebox_override("normal", bs)
	back.pressed.connect(func():
		GameState.shape_index = _shape_idx
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	layer.add_child(back)

	_refresh_hud()

func _make_nav_button(icon: String) -> Button:
	var btn := Button.new()
	btn.text = icon
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.15, 0.55)
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", s)
	return btn

func _setup_overlay() -> void:
	_overlay = ScoreOverlay.new()
	add_child(_overlay)

func _setup_ink_bar() -> void:
	# Flow vignette — subtle golden border when in FLOW
	_flow_vignette = ColorRect.new()
	_flow_vignette.color = Color(1.0, 0.85, 0.1, 0.0)
	_flow_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flow_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow_vignette.visible = false
	var layer_v := CanvasLayer.new()
	layer_v.layer = 5
	add_child(layer_v)
	layer_v.add_child(_flow_vignette)

	_ink_bar = InkBar.new()
	_ink_bar.ink_empty.connect(_on_ink_empty)
	add_child(_ink_bar)

	# FLOW label (center, hidden until triggered)
	var layer_f := CanvasLayer.new()
	layer_f.layer = 6
	add_child(layer_f)
	_flow_label = Label.new()
	_flow_label.text = "✦ FLOW!"
	_flow_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flow_label.offset_top   = 110
	_flow_label.offset_left  = -160
	_flow_label.offset_right = 160
	_flow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flow_label.add_theme_font_size_override("font_size", 32)
	_flow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 0.0))
	_flow_label.visible = false
	layer_f.add_child(_flow_label)

func _start_session() -> void:
	_beat_clock.start()
	if _audio_player.stream:
		_audio_player.play()

# ── Input — arrow keys cycle shapes ──────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var ke := event as InputEventKey
	if ke.keycode == KEY_RIGHT or ke.keycode == KEY_D:
		_change_shape(_shape_idx + 1)
	elif ke.keycode == KEY_LEFT or ke.keycode == KEY_A:
		_change_shape(_shape_idx - 1)

# ── Beat cycle ─────────────────────────────────────────────────────────────────

func _on_beat(beat_number: int) -> void:
	_visualizer.pulse()
	var pos := beat_number % CYCLE_BEATS

	if pos == 0:
		# Draw window just ended — score it, then reset for the next round
		_canvas.set_drawing_enabled(false)
		_ghost.set_highlight(false)
		if _session_started:
			_score_round()
		_canvas.clear()
		_set_cue("GET READY", Color(0.55, 0.55, 0.55))

	elif pos < DRAW_START - 1:
		_set_cue(str(DRAW_START - pos) + "...", Color(0.55, 0.55, 0.55))

	elif pos == DRAW_START - 1:
		_ghost.set_highlight(true)
		_set_cue("1...", Color(0.9, 0.6, 0.1))

	elif pos == DRAW_START:
		_session_started = true
		var beat_dur  := 60.0 / _beat_clock.bpm
		_draw_start_t  = _beat_clock.current_time()
		_draw_end_t    = _draw_start_t + beat_dur * DRAW_DURATION
		_canvas.set_drawing_enabled(true)
		_set_cue("DRAW!", Color(0.15, 0.82, 0.35))

func _score_round() -> void:
	var stroke := _canvas.get_last_stroke()
	if stroke.size() < 2:
		_set_cue("MISSED!", Color(0.9, 0.25, 0.25))
		_record_grade("—")
		return
	_set_cue("", Color.WHITE)
	var result := _analyzer.analyze(stroke, _ghost.get_stroke_path(),
		_beat_clock, _draw_start_t, _draw_end_t)
	_overlay.show_result(result)
	_record_grade(result["grade"])

func _record_grade(grade: String) -> void:
	_session_grades.append(grade)
	_ink_bar.apply_grade(grade)

	if grade == "S" or grade == "A":
		_streak += 1
		if _streak >= FLOW_THRESHOLD and not _in_flow:
			_enter_flow()
	else:
		_streak = 0
		if _in_flow:
			_exit_flow()

	_refresh_hud()

func _enter_flow() -> void:
	_in_flow = true
	_ink_bar.set_flow(true)
	_flow_vignette.color = Color(1.0, 0.85, 0.1, 0.04)
	_flow_vignette.visible = true
	_flow_label.modulate.a = 1.0
	_flow_label.visible = true
	_flow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	var tw := create_tween()
	tw.tween_property(_flow_label, "modulate:a", 0.0, 1.8).set_delay(1.0)
	tw.tween_callback(func(): _flow_label.visible = false)

func _exit_flow() -> void:
	_in_flow = false
	_ink_bar.set_flow(false)
	_flow_vignette.visible = false

func _on_ink_empty() -> void:
	_beat_clock.stop()
	_canvas.set_drawing_enabled(false)
	_set_cue("INK DRIED", Color(0.7, 0.2, 0.2))
	var popup_layer := CanvasLayer.new()
	popup_layer.layer = 10
	add_child(popup_layer)
	var back_btn := Button.new()
	back_btn.text = "Back to Menu"
	back_btn.set_anchors_preset(Control.PRESET_CENTER)
	back_btn.offset_left   = -80
	back_btn.offset_right  = 80
	back_btn.offset_top    = 40
	back_btn.offset_bottom = 72
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	popup_layer.add_child(back_btn)

func _change_shape(new_idx: int) -> void:
	_shape_idx = ((new_idx % SHAPES.size()) + SHAPES.size()) % SHAPES.size()
	_ghost.load_from_json(SHAPES[_shape_idx]["path"])
	_canvas.clear()
	_session_grades.clear()
	_refresh_hud()

func _refresh_hud() -> void:
	_shape_name_label.text = "%d / %d  —  %s" % [
		_shape_idx + 1, SHAPES.size(), SHAPES[_shape_idx]["name"]
	]
	# Last 5 grades with grade-appropriate colors packed into one label
	var recent := _session_grades.slice(-5)
	var history_text := "  ".join(recent)
	_history_label.text = history_text

func _set_cue(text: String, color: Color) -> void:
	_cue_label.text = text
	_cue_label.add_theme_color_override("font_color", color)
