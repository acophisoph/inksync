## StrokeAnalyzer — scores a completed stroke against the reference.
##
## Produces three independent scores (0.0–1.0):
##   accuracy   — how closely the shape matches the reference path
##   smoothness — how confident and wobble-free the strokes were
##   timing     — how well pen-down / pen-up aligned to the target beats
##
## Returns a Dictionary with those three floats plus a letter grade.

class_name StrokeAnalyzer
extends Node

const RESAMPLE_N  := 64    # points used for shape comparison
const MAX_DIST_PX := 180.0 # pixel distance beyond which accuracy = 0

func analyze(
	stroke_data   : Array,
	reference     : PackedVector2Array,
	beat_clock    : BeatClock,
	start_beat_t  : float,
	end_beat_t    : float
) -> Dictionary:
	var player_path := _extract_path(stroke_data)
	var accuracy    := _shape_accuracy(player_path, reference)
	var smoothness  := _stroke_smoothness(player_path)
	var timing      := _timing_score(stroke_data, start_beat_t, end_beat_t, beat_clock.bpm)

	return {
		"accuracy":   accuracy,
		"smoothness": smoothness,
		"timing":     timing,
		"grade":      _letter_grade(accuracy, smoothness, timing),
	}

# ── Shape Accuracy ─────────────────────────────────────────────────────────────

func _shape_accuracy(player: PackedVector2Array, reference: PackedVector2Array) -> float:
	if player.size() < 2 or reference.size() < 2:
		return 0.0

	var p := _resample(player,    RESAMPLE_N)
	var r := _resample(reference, RESAMPLE_N)

	# Translate player centroid to match reference centroid so position doesn't penalise
	var offset := _centroid(r) - _centroid(p)

	var total := 0.0
	for i in RESAMPLE_N:
		total += (p[i] + offset).distance_to(r[i])

	var avg := total / RESAMPLE_N
	return clamp(1.0 - avg / MAX_DIST_PX, 0.0, 1.0)

# ── Stroke Smoothness ──────────────────────────────────────────────────────────

func _stroke_smoothness(path: PackedVector2Array) -> float:
	if path.size() < 3:
		return 1.0

	var angle_changes : Array[float] = []
	for i in range(1, path.size() - 1):
		var a := path[i]     - path[i - 1]
		var b := path[i + 1] - path[i]
		if a.length() < 0.5 or b.length() < 0.5:
			continue
		angle_changes.append(absf(a.angle_to(b)))

	if angle_changes.is_empty():
		return 1.0

	var avg := 0.0
	for v in angle_changes:
		avg += v
	avg /= angle_changes.size()

	# avg ≈ 0 → smooth straight line   avg ≈ PI → extremely jagged
	return clamp(1.0 - avg / PI, 0.0, 1.0)

# ── Timing Score ───────────────────────────────────────────────────────────────

func _timing_score(
	stroke_data : Array,
	start_time  : float,
	end_time    : float,
	bpm         : float
) -> float:
	if stroke_data.is_empty():
		return 0.0

	var hit_window     := (60.0 / bpm) * 0.3   # 30% of a beat = generous window
	var actual_start   : float = stroke_data.front()["time"]
	var actual_end     : float = stroke_data.back()["time"]

	var start_score := clamp(1.0 - absf(actual_start - start_time) / hit_window, 0.0, 1.0)
	var end_score   := clamp(1.0 - absf(actual_end   - end_time)   / hit_window, 0.0, 1.0)

	return (start_score + end_score) * 0.5

# ── Letter Grade ───────────────────────────────────────────────────────────────

func _letter_grade(accuracy: float, smoothness: float, timing: float) -> String:
	# Weighted: shape matters most, then smoothness, then timing
	var score := (accuracy * 0.5 + smoothness * 0.3 + timing * 0.2) * 100.0
	if score >= 95: return "S"
	if score >= 85: return "A"
	if score >= 70: return "B"
	if score >= 55: return "C"
	return "D"

# ── Path Utilities ─────────────────────────────────────────────────────────────

func _extract_path(stroke_data: Array) -> PackedVector2Array:
	var path := PackedVector2Array()
	for pt in stroke_data:
		path.append(pt["pos"])
	return path

func _centroid(path: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for pt in path:
		c += pt
	return c / float(path.size())

## Resample a polyline to exactly n evenly-spaced points by arc length.
func _resample(path: PackedVector2Array, n: int) -> PackedVector2Array:
	if path.size() < 2:
		return path

	# Build cumulative arc-length table
	var arc_lengths := [0.0]
	for i in range(1, path.size()):
		arc_lengths.append(arc_lengths[-1] + path[i - 1].distance_to(path[i]))

	var total    := arc_lengths[-1]
	var interval := total / float(n - 1)
	var result   := PackedVector2Array()
	result.append(path[0])

	var j := 1
	for k in range(1, n - 1):
		var target := interval * k
		while j < arc_lengths.size() - 1 and arc_lengths[j] < target:
			j += 1
		var seg_len := arc_lengths[j] - arc_lengths[j - 1]
		var t       := (target - arc_lengths[j - 1]) / seg_len if seg_len > 0.0 else 0.0
		result.append(path[j - 1].lerp(path[j], t))

	result.append(path[-1])
	return result
