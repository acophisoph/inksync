## DrawingCanvas — captures pen/mouse input and renders ink strokes.
##
## Default mode: simple fixed-width polyline (Drawing Mode, Character Mode).
## Brush mode (set brush_mode = true): variable-width calligraphy quads.
##   - Slow movement → thick   Fast movement → thin
##   - Natural taper at start and end   Subtle bristle texture
##
## get_last_stroke() returns raw point data for StrokeAnalyzer.

class_name DrawingCanvas
extends Node2D

signal stroke_completed(stroke_data: Array)

# ── Ink style ──────────────────────────────────────────────────────────────────
const INK_COLOR    := Color(0.04, 0.04, 0.10, 1.0)   # deep sumi ink
const SIMPLE_WIDTH := 3.0    # fixed width for non-brush mode
const BASE_WIDTH   := 10.0   # resting brush width (px)
const MIN_WIDTH    :=  2.0   # minimum (fast flick)
const MAX_WIDTH    := 26.0   # maximum (slow press)
const SPEED_SCALE  := 0.020  # how strongly speed narrows the stroke
const TAPER_FRAC   := 0.22   # fraction of stroke that tapers at each end
const BRISTLE_AMP  := 0.07   # ±7% width wobble for bristle texture

var brush_mode : bool = false   # set true in Story Mode

# ── Canvas state ───────────────────────────────────────────────────────────────
var _finished_strokes : Array  = []   # Array of Array[Dictionary] (full point data)
var _current_stroke   : Array  = []
var _last_stroke_data : Array  = []
var _is_drawing       : bool   = false
var _enabled          : bool   = false
var _audio_player     : AudioStreamPlayer
var _stroke_counter   : int    = 0    # seed for per-stroke bristle pattern

# ── Setup ──────────────────────────────────────────────────────────────────────

func setup(audio_player: AudioStreamPlayer) -> void:
	_audio_player = audio_player

func set_drawing_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and _is_drawing:
		_end_stroke()
	queue_redraw()

func get_last_stroke() -> Array:
	return _last_stroke_data.duplicate()

func clear() -> void:
	_finished_strokes.clear()
	_last_stroke_data = []
	_stroke_counter   = 0
	queue_redraw()

# ── Input ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_stroke(mb.position)
			else:
				_end_stroke()
	elif event is InputEventMouseMotion and _is_drawing:
		var mm := event as InputEventMouseMotion
		_add_point(mm.position, mm.pressure if mm.pressure > 0.0 else 1.0)

func _begin_stroke(pos: Vector2) -> void:
	_is_drawing     = true
	_current_stroke = [_make_point(pos, 1.0)]

func _add_point(pos: Vector2, pressure: float) -> void:
	# Skip if barely moved — avoids zero-length segments
	if _current_stroke.size() > 0:
		var last_pos : Vector2 = _current_stroke.back()["pos"]
		if last_pos.distance_squared_to(pos) < 2.0:
			return
	_current_stroke.append(_make_point(pos, pressure))
	queue_redraw()

func _end_stroke() -> void:
	_is_drawing = false
	if _current_stroke.size() < 2:
		_current_stroke = []
		return
	_last_stroke_data = _current_stroke.duplicate()
	_finished_strokes.append(_current_stroke.duplicate())
	stroke_completed.emit(_current_stroke.duplicate())
	_stroke_counter  += 1
	_current_stroke   = []
	queue_redraw()

# ── Rendering ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Subtle active-window tint (warm parchment glow, not distracting)
	if _enabled:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)),
			Color(1.0, 0.92, 0.72, 0.06))

	for i in _finished_strokes.size():
		if brush_mode:
			_draw_brush_stroke(_finished_strokes[i], i, 1.0)
		else:
			var pts := PackedVector2Array()
			for pt in _finished_strokes[i]:
				pts.append(pt["pos"])
			draw_polyline(pts, INK_COLOR, SIMPLE_WIDTH, true)

	if _current_stroke.size() >= 2:
		if brush_mode:
			_draw_brush_stroke(_current_stroke, _stroke_counter, 1.0)
		else:
			var pts := PackedVector2Array()
			for pt in _current_stroke:
				pts.append(pt["pos"])
			draw_polyline(pts, INK_COLOR, SIMPLE_WIDTH, true)

# ── Brush stroke renderer ──────────────────────────────────────────────────────

func _draw_brush_stroke(points: Array, stroke_seed: int, alpha: float) -> void:
	var n := points.size()
	if n < 2:
		return

	# ── 1. Compute width at each point based on draw speed ──────────────────
	var widths : Array[float] = []
	widths.resize(n)
	widths[0] = BASE_WIDTH

	for i in range(1, n):
		var p_prev : Vector2 = points[i - 1]["pos"]
		var p_curr : Vector2 = points[i]["pos"]
		var dt     : float   = maxf(points[i]["time"] - points[i - 1]["time"], 0.001)
		var speed  : float   = p_prev.distance_to(p_curr) / dt
		widths[i] = clampf(BASE_WIDTH - speed * SPEED_SCALE, MIN_WIDTH, MAX_WIDTH)

	# ── 2. Smooth widths (2-pass average) ───────────────────────────────────
	for _pass in 2:
		for i in range(1, n - 1):
			widths[i] = (widths[i - 1] + widths[i] * 2.0 + widths[i + 1]) / 4.0

	# ── 3. Taper at start and end (simulates touch-down and lift-off) ───────
	var taper_len := int(maxf(float(n) * TAPER_FRAC, 2.0))
	for i in taper_len:
		var t := float(i) / float(taper_len)
		var ease_t := t * t          # quadratic ease-in
		widths[i]               = lerpf(0.2, widths[i],               ease_t)
		widths[n - 1 - i]       = lerpf(0.2, widths[n - 1 - i],       ease_t)

	# ── 4. Ink bleed passes then main stroke ────────────────────────────────
	# Three layered passes simulate ink soaking into paper fibres:
	#   outer halo → mid bleed → dense core
	_draw_quads(points, widths, stroke_seed,
		Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, alpha * 0.055), 2.2)
	_draw_quads(points, widths, stroke_seed,
		Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, alpha * 0.14),  1.5)
	_draw_quads(points, widths, stroke_seed,
		Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, alpha),         1.0)

	# ── 5. Touch-down blob ───────────────────────────────────────────────────
	var ink := Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, alpha)
	var start_r := widths[0] * 0.9
	if start_r > 0.5:
		draw_circle(points[0]["pos"], start_r * 1.5,
			Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, alpha * 0.10))
		draw_circle(points[0]["pos"], start_r, ink)

func _draw_quads(points: Array, widths: Array[float],
		stroke_seed: int, col: Color, width_mult: float) -> void:
	var n := points.size()
	for i in range(n - 1):
		var p0 : Vector2 = points[i]["pos"]
		var p1 : Vector2 = points[i + 1]["pos"]
		if p0.distance_squared_to(p1) < 0.25:
			continue
		var bristle := 1.0 + sin(float(stroke_seed * 997 + i) * 2.39996) * BRISTLE_AMP
		var w0 := widths[i]     * bristle * width_mult
		var w1 := widths[i + 1] * bristle * width_mult
		var dir  := (p1 - p0).normalized()
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			p0 + perp * w0, p1 + perp * w1,
			p1 - perp * w1, p0 - perp * w0,
		]), col)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_point(pos: Vector2, pressure: float) -> Dictionary:
	return {
		"pos":      pos,
		"time":     _current_time(),
		"pressure": pressure,
	}

func _current_time() -> float:
	if _audio_player and _audio_player.playing:
		return _audio_player.get_playback_position()
	return Time.get_ticks_msec() / 1000.0
