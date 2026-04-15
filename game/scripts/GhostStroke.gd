## GhostStroke — renders the semi-transparent reference path the player traces.
##
## Loaded from a JSON file: an array of [x, y] coordinate pairs.
## See assets/strokes/circle.json for the format.

class_name GhostStroke
extends Node2D

const GHOST_COLOR  := Color(0.35, 0.45, 1.0, 0.25)   # soft blue, see-through
const GUIDE_COLOR  := Color(0.35, 0.45, 1.0, 0.55)   # slightly more visible
const LINE_WIDTH   := 5.0
const MARKER_RADIUS := 9.0

var _path : PackedVector2Array = PackedVector2Array()

## Load a reference path from a JSON file.
## JSON format: [[x1,y1], [x2,y2], ...]
## Coordinates are in screen pixels (origin = top-left, 1280x720 viewport).
func load_from_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("GhostStroke: could not open '%s'. Does the file exist?" % path)
		return

	var json  := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("GhostStroke: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return

	var data : Array = json.get_data()
	_path = PackedVector2Array()
	for pt in data:
		_path.append(Vector2(pt[0], pt[1]))

	queue_redraw()

## Returns the reference path for use in StrokeAnalyzer.
func get_stroke_path() -> PackedVector2Array:
	return _path

func _draw() -> void:
	if _path.size() < 2:
		return

	draw_polyline(_path, GHOST_COLOR, LINE_WIDTH, true)

	# Start marker (blue-ish circle) — where to put the pen down
	draw_circle(_path[0], MARKER_RADIUS, GUIDE_COLOR)

	# End marker (slightly different shade) — where to lift the pen
	draw_circle(_path[-1], MARKER_RADIUS * 0.7, Color(1.0, 0.5, 0.3, 0.6))
