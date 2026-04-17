## DrawingCanvas — captures pen/mouse input and renders strokes.
##
## Call set_drawing_enabled(true/false) to open/close the draw window.
## get_last_stroke() returns the most recently completed stroke data.

class_name DrawingCanvas
extends Node2D

signal stroke_completed(stroke_data: Array)

const INK_COLOR     := Color(0.08, 0.08, 0.12, 1.0)
const INK_WIDTH     := 3.0
const ACTIVE_TINT   := Color(0.72, 1.0, 0.78, 0.14)   # subtle green when draw window is open

var _finished_strokes : Array[PackedVector2Array] = []
var _current_stroke   : Array = []
var _last_stroke_data : Array = []
var _is_drawing       : bool  = false
var _enabled          : bool  = false
var _audio_player     : AudioStreamPlayer

func setup(audio_player: AudioStreamPlayer) -> void:
	_audio_player = audio_player

## Open or close the drawing window.
## Closing mid-stroke force-ends and saves the stroke.
func set_drawing_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and _is_drawing:
		_end_stroke()
	queue_redraw()

## Returns the last completed stroke data. Empty array if nothing drawn.
func get_last_stroke() -> Array:
	return _last_stroke_data.duplicate()

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
	_current_stroke.append(_make_point(pos, pressure))
	queue_redraw()

func _end_stroke() -> void:
	_is_drawing = false
	if _current_stroke.size() < 2:
		_current_stroke = []
		return
	_last_stroke_data = _current_stroke.duplicate()

	var path := PackedVector2Array()
	for pt in _current_stroke:
		path.append(pt["pos"])
	_finished_strokes.append(path)

	stroke_completed.emit(_current_stroke.duplicate())
	_current_stroke = []
	queue_redraw()

func _draw() -> void:
	# Tint the canvas green while the draw window is open
	if _enabled:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), ACTIVE_TINT)

	for stroke in _finished_strokes:
		if stroke.size() >= 2:
			draw_polyline(stroke, INK_COLOR, INK_WIDTH, true)

	if _current_stroke.size() >= 2:
		var pts := PackedVector2Array()
		for pt in _current_stroke:
			pts.append(pt["pos"])
		draw_polyline(pts, INK_COLOR, INK_WIDTH, true)

func clear() -> void:
	_finished_strokes.clear()
	_last_stroke_data = []
	queue_redraw()

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
