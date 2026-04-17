## GhostStroke — renders the semi-transparent reference path the player traces.
##
## load_from_json() loads the path from a JSON file: [[x,y],[x,y],...]
## set_highlight(true) makes it pulse brighter right before the draw window.

class_name GhostStroke
extends Node2D

const GHOST_COLOR     := Color(0.35, 0.45, 1.0, 0.22)
const HIGHLIGHT_COLOR := Color(0.35, 0.45, 1.0, 0.65)
const GUIDE_COLOR     := Color(0.35, 0.45, 1.0, 0.55)
const DIM_COLOR       := Color(0.35, 0.45, 1.0, 0.32)   # upcoming strokes in char mode
const DONE_COLOR      := Color(0.25, 0.78, 0.45, 0.55)  # completed strokes
const LINE_WIDTH      := 5.0
const MARKER_RADIUS   := 9.0

var _path        : PackedVector2Array = PackedVector2Array()
var _highlighted : bool = false
var _pulse       : float = 0.0

# Multi-stroke character mode
var _all_strokes   : Array[PackedVector2Array] = []
var _current_idx   : int = 0
var _done_indices  : Array[int] = []

func load_from_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("GhostStroke: could not open '%s'" % path)
		return
	var json  := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("GhostStroke: JSON parse error in '%s'" % path)
		return
	var data: Array = json.get_data()
	_path = PackedVector2Array()
	for pt in data:
		_path.append(Vector2(pt[0], pt[1]))
	_all_strokes = []
	queue_redraw()

func get_stroke_path() -> PackedVector2Array:
	return _path

func load_from_points(points: PackedVector2Array) -> void:
	_path = points
	_all_strokes = []
	queue_redraw()

## Show all strokes of a character simultaneously.
## current: index of the stroke the player is about to draw.
## done:    indices of strokes already completed this round.
func load_all_strokes(strokes: Array[PackedVector2Array], current: int, done: Array[int]) -> void:
	_all_strokes  = strokes
	_current_idx  = current
	_done_indices = done
	_path = strokes[current] if current < strokes.size() else PackedVector2Array()
	queue_redraw()

## Highlight the current stroke right before the draw window opens.
func set_highlight(on: bool) -> void:
	_highlighted = on
	_pulse = 1.0 if on else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _highlighted and _pulse < 1.0:
		_pulse = move_toward(_pulse, 1.0, delta * 4.0)
		queue_redraw()
	elif not _highlighted and _pulse > 0.0:
		_pulse = move_toward(_pulse, 0.0, delta * 3.0)
		queue_redraw()

func _draw() -> void:
	# ── Multi-stroke character mode ──────────────────────────────────────────
	if _all_strokes.size() > 0:
		for i in _all_strokes.size():
			var s := _all_strokes[i]
			if s.size() < 2:
				continue
			if i == _current_idx:
				# Current stroke — bright with pulse animation
				var col := GHOST_COLOR.lerp(HIGHLIGHT_COLOR, _pulse)
				draw_polyline(s, col, LINE_WIDTH, true)
				draw_circle(s[0], MARKER_RADIUS,
					GUIDE_COLOR.lerp(Color(0.2, 0.6, 1.0, 0.9), _pulse))
				draw_circle(s[-1], MARKER_RADIUS * 0.7,
					Color(1.0, 0.5, 0.3, 0.6 + _pulse * 0.3))
			elif i in _done_indices:
				# Completed strokes — green tint
				draw_polyline(s, DONE_COLOR, LINE_WIDTH - 1.0, true)
			else:
				# Upcoming strokes — very faint guide
				draw_polyline(s, DIM_COLOR, LINE_WIDTH - 1.0, true)
		return

	# ── Single-stroke mode (Drawing Mode) ────────────────────────────────────
	if _path.size() < 2:
		return
	var color := GHOST_COLOR.lerp(HIGHLIGHT_COLOR, _pulse)
	draw_polyline(_path, color, LINE_WIDTH, true)
	draw_circle(_path[0], MARKER_RADIUS,
		GUIDE_COLOR.lerp(Color(0.2, 0.6, 1.0, 0.9), _pulse))
	draw_circle(_path[-1], MARKER_RADIUS * 0.7,
		Color(1.0, 0.5, 0.3, 0.6 + _pulse * 0.3))
