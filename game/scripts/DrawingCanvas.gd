## DrawingCanvas — captures pen/mouse input and renders strokes.
##
## Each stroke is recorded as an array of point dicts:
##   { "pos": Vector2, "time": float, "pressure": float }
##
## Works with mouse (pressure always 1.0) and drawing tablets (real pressure).

class_name DrawingCanvas
extends Node2D

## Emitted when the user lifts the pen/mouse. Passes the full stroke data.
signal stroke_completed(stroke_data: Array)

const INK_COLOR  := Color(0.08, 0.08, 0.12, 1.0)   # near-black ink
const INK_WIDTH  := 3.0

var _finished_strokes : Array[PackedVector2Array] = []
var _current_stroke   : Array = []   # Array of {pos, time, pressure}
var _is_drawing       : bool = false
var _audio_player     : AudioStreamPlayer

func setup(audio_player: AudioStreamPlayer) -> void:
	_audio_player = audio_player

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_stroke(mb.position)
			else:
				_end_stroke()

	elif event is InputEventMouseMotion and _is_drawing:
		var mm := event as InputEventMouseMotion
		# pressure is 0.0 on mouse (no tablet) — we default it to 1.0
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

	# Store the path for rendering
	var path := PackedVector2Array()
	for pt in _current_stroke:
		path.append(pt["pos"])
	_finished_strokes.append(path)

	stroke_completed.emit(_current_stroke.duplicate())
	_current_stroke = []
	queue_redraw()

func _draw() -> void:
	# Render all completed strokes
	for stroke in _finished_strokes:
		if stroke.size() >= 2:
			draw_polyline(stroke, INK_COLOR, INK_WIDTH, true)

	# Render the stroke currently in progress
	if _current_stroke.size() >= 2:
		var pts := PackedVector2Array()
		for pt in _current_stroke:
			pts.append(pt["pos"])
		draw_polyline(pts, INK_COLOR, INK_WIDTH, true)

## Wipe the canvas between rounds.
func clear() -> void:
	_finished_strokes.clear()
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
