## CharacterPractice — rhythm tracing for a single Chinese character.
##
## Beat flow:
##   COUNT_IN  → 3 → 2 → 1  (4 beats, once per character attempt)
##   STROKE    → back-to-back DRAW windows, one per stroke, no re-countdown
##   REST      → show overall grade + meaning reaction, then loop
##
## Systems wired in:
##   InkBar            — resource/health; depletes on bad grades, gold in FLOW
##   FLOW state        — 4+ consecutive A/S grades trigger visual + ink bonus
##   CharacterReaction — particle burst with English meaning on completion
##   InkPainting       — accumulating calligraphy background

extends Node2D

const CHAR_DATA_DIR  := "res://assets/characters/"
const FALLBACK_BPM   := 90.0
const COUNT_IN_BEATS := 4
const STROKE_BEATS   := 4
const FREE_BEATS     := 4
const REST_BEATS     := 4
const FLOW_THRESHOLD := 4   # consecutive good grades to enter FLOW

const PHASE_COUNT_IN := 0
const PHASE_STROKE   := 1
const PHASE_REST     := 2

# ── State ─────────────────────────────────────────────────────────────────────
var _character     : String = ""
var _strokes       : Array[PackedVector2Array] = []
var _stroke_idx    : int       = 0
var _done_strokes  : Array[int] = []
var _stroke_grades : Array[String] = []
var _has_data      : bool = false

var _phase      : int = PHASE_COUNT_IN
var _phase_beat : int = 0

# Flow tracking
var _streak  : int  = 0
var _in_flow : bool = false

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _audio_player  : AudioStreamPlayer
var _beat_clock    : BeatClock
var _canvas        : DrawingCanvas
var _ghost         : GhostStroke
var _analyzer      : StrokeAnalyzer
var _visualizer    : BeatVisualizer
var _overlay       : ScoreOverlay
var _ink_bar       : InkBar
var _painting      : InkPainting
var _flow_vignette : ColorRect
var _guide_label   : Label

var _cue_label     : Label
var _stroke_label  : Label
var _history_label : Label
var _grade_history : Array[String] = []

var _draw_start_t : float = 0.0
var _draw_end_t   : float = 0.0

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_character = GameState.character
	_load_stroke_data()
	_build_background()
	_setup_painting()      # behind canvas
	_build_char_guide()
	_setup_audio()
	_setup_beat_clock()
	_setup_canvas()
	_setup_ghost()
	_setup_analyzer()
	_setup_visualizer()
	_setup_overlay()
	_setup_hud()           # CanvasLayer: labels + back button + ink bar + vignette
	_beat_clock.start()
	if _audio_player.stream:
		_audio_player.play()

func _load_stroke_data() -> void:
	if _character.is_empty():
		return
	var hex  := "%x" % _character.unicode_at(0)
	var path := CHAR_DATA_DIR + hex + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return
	var dict := data as Dictionary
	if not dict.has("strokes"):
		return
	var raw: Array = dict["strokes"]
	for raw_stroke in raw:
		var pts := PackedVector2Array()
		for pt in raw_stroke:
			pts.append(Vector2(float(pt[0]), float(pt[1])))
		if pts.size() >= 2:
			_strokes.append(pts)
	_has_data = _strokes.size() > 0

# ── Scene construction ────────────────────────────────────────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.97, 0.97, 0.95)
	bg.size     = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

func _setup_painting() -> void:
	_painting = InkPainting.new()
	_painting.z_index = 0
	add_child(_painting)

func _build_char_guide() -> void:
	_guide_label = Label.new()
	_guide_label.text                 = _character
	_guide_label.custom_minimum_size  = Vector2(500, 500)
	_guide_label.position             = Vector2(390, 110)
	_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guide_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_guide_label.add_theme_font_size_override("font_size", 380)
	_guide_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.78, 0.13))
	add_child(_guide_label)

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	var song := GameState.song_path
	if song != "":
		var stream: Resource = load(song)
		if stream:
			_audio_player.stream = stream

func _setup_beat_clock() -> void:
	_beat_clock     = BeatClock.new()
	_beat_clock.bpm = GameState.bpm if GameState.song_path != "" else FALLBACK_BPM
	add_child(_beat_clock)
	_beat_clock.setup(_audio_player)
	_beat_clock.beat_hit.connect(_on_beat)

func _setup_canvas() -> void:
	_canvas = DrawingCanvas.new()
	_canvas.z_index = 2
	add_child(_canvas)
	_canvas.setup(_audio_player)
	_canvas.set_drawing_enabled(false)

func _setup_ghost() -> void:
	_ghost = GhostStroke.new()
	_ghost.z_index = 3
	add_child(_ghost)
	_ghost.visible = _has_data
	if _has_data:
		_ghost.load_all_strokes(_strokes, 0, [])

func _setup_analyzer() -> void:
	_analyzer = StrokeAnalyzer.new()
	add_child(_analyzer)

func _setup_visualizer() -> void:
	_visualizer = BeatVisualizer.new()
	_visualizer.z_index = 4
	add_child(_visualizer)
	_visualizer.position = Vector2(56, 56)
	_visualizer.setup(_beat_clock)

func _setup_overlay() -> void:
	_overlay = ScoreOverlay.new()
	_overlay.layer = 5
	add_child(_overlay)

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# ── Flow vignette — subtle gold tint over entire screen ──
	_flow_vignette = ColorRect.new()
	_flow_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flow_vignette.color   = Color(1.0, 0.85, 0.1, 0.0)
	_flow_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flow_vignette)

	# ── Cue (centre-top) ──
	_cue_label = Label.new()
	_cue_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_cue_label.offset_top   = 24
	_cue_label.offset_left  = -220
	_cue_label.offset_right =  220
	_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue_label.add_theme_font_size_override("font_size", 42)
	layer.add_child(_cue_label)
	_set_cue("GET READY", Color(0.5, 0.5, 0.5))

	# ── Sub-label (stroke counter / char name) ──
	_stroke_label = Label.new()
	_stroke_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stroke_label.offset_top   = 76
	_stroke_label.offset_left  = -220
	_stroke_label.offset_right =  220
	_stroke_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stroke_label.add_theme_font_size_override("font_size", 20)
	_stroke_label.add_theme_color_override("font_color", Color(0.35, 0.45, 0.65))
	layer.add_child(_stroke_label)
	_refresh_stroke_label()

	# ── Grade history (top-right) ──
	_history_label = Label.new()
	_history_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_history_label.offset_top   = 14
	_history_label.offset_right = -16
	_history_label.offset_left  = -220
	_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_history_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_history_label)

	# ── Ink bar ──
	_ink_bar = InkBar.new()
	_ink_bar.ink_empty.connect(_on_ink_empty)
	layer.add_child(_ink_bar)

	# ── Back button ──
	var back := Button.new()
	back.text       = "← Characters"
	back.focus_mode = Control.FOCUS_NONE
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left   = 12
	back.offset_top    = 12
	back.offset_right  = 164
	back.offset_bottom = 44
	back.add_theme_font_size_override("font_size", 15)
	var bs := StyleBoxFlat.new()
	bs.bg_color     = Color(0.1, 0.1, 0.15, 0.75)
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
		get_tree().change_scene_to_file("res://scenes/CharacterMode.tscn")
	)
	layer.add_child(back)

# ── Beat cycle — state machine ────────────────────────────────────────────────

func _on_beat(_beat_number: int) -> void:
	_visualizer.pulse()
	match _phase:
		PHASE_COUNT_IN: _tick_count_in()
		PHASE_STROKE:   _tick_stroke()
		PHASE_REST:     _tick_rest()

func _tick_count_in() -> void:
	match _phase_beat:
		0: _set_cue("GET READY", Color(0.55, 0.55, 0.55))
		1: _set_cue("3...", Color(0.55, 0.55, 0.55))
		2: _set_cue("2...", Color(0.55, 0.55, 0.55))
		3:
			_ghost.set_highlight(true)
			_set_cue("1...", Color(0.9, 0.6, 0.1))
	_phase_beat += 1
	if _phase_beat >= COUNT_IN_BEATS:
		_phase      = PHASE_STROKE
		_phase_beat = 0

func _tick_stroke() -> void:
	var beats : int = STROKE_BEATS if _has_data else FREE_BEATS

	if _phase_beat == 0:
		_ghost.set_highlight(false)
		var beat_dur := 60.0 / _beat_clock.bpm
		_draw_start_t = _beat_clock.current_time()
		_draw_end_t   = _draw_start_t + beat_dur * beats
		_canvas.set_drawing_enabled(true)
		_refresh_stroke_label()
		if _has_data:
			_set_cue("DRAW  %d / %d" % [_stroke_idx + 1, _strokes.size()],
				Color(0.15, 0.82, 0.35))
		else:
			_set_cue("DRAW!", Color(0.15, 0.82, 0.35))

	_phase_beat += 1

	if _phase_beat >= beats:
		_canvas.set_drawing_enabled(false)
		_grade_stroke()

		if _has_data:
			_done_strokes.append(_stroke_idx)
			_stroke_idx += 1
			if _stroke_idx < _strokes.size():
				_ghost.load_all_strokes(_strokes, _stroke_idx, _done_strokes)
				_ghost.set_highlight(true)
				_phase_beat = 0
				return

		# All strokes done
		_phase      = PHASE_REST
		_phase_beat = 0
		_show_final_result()

func _tick_rest() -> void:
	_phase_beat += 1
	if _phase_beat >= REST_BEATS:
		_stroke_idx    = 0
		_done_strokes  = []
		_stroke_grades = []
		_canvas.clear()
		_set_cue("GET READY", Color(0.55, 0.55, 0.55))
		if _has_data:
			_ghost.load_all_strokes(_strokes, 0, [])
		_phase      = PHASE_COUNT_IN
		_phase_beat = 0

# ── Scoring & flow ────────────────────────────────────────────────────────────

func _grade_stroke() -> void:
	var stroke := _canvas.get_last_stroke()
	var grade  : String

	if stroke.size() < 2:
		grade = "—"
	else:
		var result: Dictionary
		if _has_data:
			result = _analyzer.analyze(
				stroke, _strokes[_stroke_idx],
				_beat_clock, _draw_start_t, _draw_end_t
			)
		else:
			result = _free_trace_score(stroke)
		grade = result["grade"]

	_stroke_grades.append(grade)
	_grade_history.append(grade)
	_history_label.text = "  ".join(_grade_history.slice(-5))

	_ink_bar.apply_grade(grade)
	_update_flow(grade)

func _update_flow(grade: String) -> void:
	if grade in ["S", "A"]:
		_streak += 1
	else:
		_streak = 0
		if _in_flow:
			_exit_flow()

	if _streak >= FLOW_THRESHOLD and not _in_flow:
		_enter_flow()

func _enter_flow() -> void:
	_in_flow = true
	_ink_bar.set_flow(true)
	_flow_vignette.color = Color(1.0, 0.85, 0.1, 0.04)
	_set_cue("✦ FLOW!", Color(1.0, 0.88, 0.2))

func _exit_flow() -> void:
	_in_flow = false
	_ink_bar.set_flow(false)
	_flow_vignette.color = Color(1.0, 0.85, 0.1, 0.0)

func _show_final_result() -> void:
	if _stroke_grades.is_empty():
		return

	var total : int = 0
	for g in _stroke_grades:
		match g:
			"S": total += 5
			"A": total += 4
			"B": total += 3
			"C": total += 2
			"D": total += 1
	var avg     : float = float(total) / _stroke_grades.size()
	var overall : String
	if avg >= 4.5:   overall = "S"
	elif avg >= 3.5: overall = "A"
	elif avg >= 2.5: overall = "B"
	elif avg >= 1.5: overall = "C"
	else:            overall = "D"

	var norm : float = avg / 5.0
	_overlay.show_result({
		"accuracy":   norm,
		"smoothness": norm,
		"timing":     norm,
		"grade":      overall,
	})
	_set_cue("", Color.WHITE)

	# Trigger meaning burst + add to background painting
	CharacterReaction.spawn(self, _character)
	_painting.add_character(_character)

func _on_ink_empty() -> void:
	_beat_clock.set_process(false)
	_canvas.set_drawing_enabled(false)
	_show_ink_dried_popup()

func _show_ink_dried_popup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	layer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -220
	panel.offset_right  =  220
	panel.offset_top    = -160
	panel.offset_bottom =  160
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.12)
	ps.corner_radius_top_left     = 12
	ps.corner_radius_top_right    = 12
	ps.corner_radius_bottom_left  = 12
	ps.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", ps)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "INK DRIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.2))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Characters completed: %d" % _painting._entries.size()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(sub)

	var retry := Button.new()
	retry.text       = "Try Again"
	retry.focus_mode = Control.FOCUS_NONE
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(func():
		get_tree().reload_current_scene()
	)
	vbox.add_child(retry)

	var back := Button.new()
	back.text       = "← Characters"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/CharacterMode.tscn")
	)
	vbox.add_child(back)

# ── Scoring helpers ───────────────────────────────────────────────────────────

func _free_trace_score(stroke: Array) -> Dictionary:
	var timing     : float = _score_timing(stroke)
	var smoothness : float = _score_smoothness(stroke)
	var combined   : float = timing * 0.4 + smoothness * 0.6
	return {"accuracy": smoothness, "smoothness": smoothness,
		"timing": timing, "grade": _to_grade(combined)}

func _score_timing(stroke: Array) -> float:
	if stroke.is_empty():
		return 0.0
	var window : float = _draw_end_t - _draw_start_t
	if window <= 0.0:
		return 1.0
	var se : float = absf(float(stroke[0]["time"]) - _draw_start_t)
	var ee : float = absf(float(stroke[-1]["time"]) - _draw_end_t)
	return clampf(1.0 - (se + ee) / window, 0.0, 1.0)

func _score_smoothness(stroke: Array) -> float:
	if stroke.size() < 3:
		return 0.5
	var total : float = 0.0
	var count : int   = 0
	for i in range(1, stroke.size() - 1):
		var a : Vector2 = stroke[i - 1]["pos"]
		var b : Vector2 = stroke[i    ]["pos"]
		var c : Vector2 = stroke[i + 1]["pos"]
		var d1 := b - a
		var d2 := c - b
		if d1.length_squared() > 0.001 and d2.length_squared() > 0.001:
			var angle : float = d1.normalized().angle_to(d2.normalized())
			total += angle * angle
			count += 1
	if count == 0:
		return 0.5
	return clampf(1.0 - (total / count) / (PI * PI * 0.25), 0.0, 1.0)

func _to_grade(score: float) -> String:
	if score >= 0.90: return "S"
	if score >= 0.75: return "A"
	if score >= 0.60: return "B"
	if score >= 0.40: return "C"
	return "D"

func _refresh_stroke_label() -> void:
	if _has_data:
		_stroke_label.text = "%s  —  Stroke %d / %d" % [
			_character, _stroke_idx + 1, _strokes.size()
		]
	else:
		_stroke_label.text = "Tracing: %s" % _character

func _set_cue(text: String, color: Color) -> void:
	_cue_label.text = text
	_cue_label.add_theme_color_override("font_color", color)
