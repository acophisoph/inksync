## InkPainting — accumulates completed characters as a fading calligraphy
## background, building up an ink painting over a session.
##
## Each completed character fades in at a random artistic position,
## persists for a while, then slowly fades out to make room for new ones.

class_name InkPainting
extends Node2D

const MAX_CHARS    := 18
const FADE_IN_T    := 1.2
const HOLD_T       := 22.0
const FADE_OUT_T   := 5.0
const TOTAL_LIFE   := FADE_IN_T + HOLD_T + FADE_OUT_T

# Avoid centre (practice area)
const SAFE_ZONES := [
	Rect2(380, 160, 500, 420),   # centre — keep clear
]

var _entries : Array = []   # {char, pos, size, rot, age, label}

func add_character(character: String) -> void:
	var pos  := _pick_position()
	var size := int(randf_range(52.0, 130.0))
	var rot  := randf_range(-0.30, 0.30)

	var lbl := Label.new()
	lbl.text     = character
	lbl.position = pos
	lbl.rotation = rot
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", Color(0.04, 0.04, 0.10, 0.0))
	add_child(lbl)

	_entries.append({
		"label": lbl,
		"age":   0.0,
		"char":  character,
	})

	# Remove oldest if over cap
	if _entries.size() > MAX_CHARS:
		var oldest : Dictionary = _entries[0]
		oldest["age"] = FADE_IN_T + HOLD_T + 0.1   # force into fade-out

func _pick_position() -> Vector2:
	var attempts := 0
	while attempts < 30:
		var px := randf_range(60.0, 1160.0)
		var py := randf_range(70.0, 600.0)
		var candidate := Vector2(px, py)
		var ok := true
		for z in SAFE_ZONES:
			if z.has_point(candidate):
				ok = false
				break
		if ok:
			return candidate
		attempts += 1
	return Vector2(randf_range(60.0, 200.0), randf_range(70.0, 600.0))

func _process(delta: float) -> void:
	var dead : Array = []
	for entry in _entries:
		entry["age"] += delta
		var age : float = entry["age"]
		var lbl : Label = entry["label"]
		var a   : float

		if age < FADE_IN_T:
			a = (age / FADE_IN_T) * 0.18
		elif age < FADE_IN_T + HOLD_T:
			a = 0.18
		else:
			var fade_prog := (age - FADE_IN_T - HOLD_T) / FADE_OUT_T
			a = (1.0 - fade_prog) * 0.18
			if fade_prog >= 1.0:
				dead.append(entry)
				lbl.queue_free()
				continue

		lbl.add_theme_color_override("font_color", Color(0.04, 0.04, 0.10, a))

	for d in dead:
		_entries.erase(d)
