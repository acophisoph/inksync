## InkBar — the player's ink resource bar.
##
## Ink is POWER. Good strokes refill it; bad ones drain it.
## A slow passive drain creates steady background pressure.
## The bar flashes green on S, pulses gold in FLOW.
## Emits ink_empty when depleted.

class_name InkBar
extends Node2D

signal ink_empty

# ── Grade model ────────────────────────────────────────────────────────────────
# Negative = refills ink. Positive = drains ink.
const GRADE_DRAIN := {
	"S": -0.20,   # big satisfying refill
	"A": -0.10,   # nice refill
	"B": -0.02,   # near-neutral (tiny refill to reward finishing the stroke)
	"C":  0.08,   # oops
	"D":  0.18,   # bad
	"—":  0.25,   # miss — feels punishing
}
const PASSIVE_DRAIN_PER_SEC := 0.002   # 0.2%/s — ticking pressure in the background
const FLOW_DRAIN_MULT        := 0.35   # flow massively reduces drain / boosts refill

# ── Layout ─────────────────────────────────────────────────────────────────────
const BAR_X  := 20.0
const BAR_Y  := 694.0
const BAR_W  := 1240.0
const BAR_H  := 16.0

# ── State ──────────────────────────────────────────────────────────────────────
var _ink         : float = 1.0
var _display_ink : float = 1.0
var _in_flow     : bool  = false
var _pulse       : float = 0.0   # white flash on state change
var _grade_flash : float = 0.0   # coloured flash on grade
var _flash_col   : Color = Color.WHITE
var _warning_t   : float = 0.0

func apply_grade(grade: String) -> void:
	var drain : float = GRADE_DRAIN.get(grade, 0.1)
	if _in_flow:
		drain *= FLOW_DRAIN_MULT
	_ink = clampf(_ink - drain, 0.0, 1.0)

	# Trigger a grade flash
	if grade == "S":
		_flash_col = Color(0.3, 1.0, 0.5)   # bright green burst
		_grade_flash = 1.0
	elif grade == "A":
		_flash_col = Color(0.5, 0.9, 1.0)   # cyan lift
		_grade_flash = 0.7
	elif grade == "—" or grade == "D":
		_flash_col = Color(1.0, 0.2, 0.2)   # red sting
		_grade_flash = 0.85

	if _ink <= 0.0:
		ink_empty.emit()

func set_flow(on: bool) -> void:
	if _in_flow == on:
		return
	_in_flow = on
	_pulse   = 1.0
	queue_redraw()

func get_ink() -> float:
	return _ink

func _process(delta: float) -> void:
	# Passive drain
	var passive := PASSIVE_DRAIN_PER_SEC * delta
	if _in_flow:
		passive *= FLOW_DRAIN_MULT
	_ink = clampf(_ink - passive, 0.0, 1.0)

	# Display lerp — fast drop (damage feels immediate), slow climb (refill feels earned)
	var lerp_speed := 3.5 if _display_ink > _ink else 1.0
	_display_ink = move_toward(_display_ink, _ink, delta * lerp_speed)

	if _pulse > 0.0:
		_pulse = move_toward(_pulse, 0.0, delta * 3.5)
	if _grade_flash > 0.0:
		_grade_flash = move_toward(_grade_flash, 0.0, delta * 3.0)
	if _ink < 0.30:
		_warning_t += delta * 5.0
	else:
		_warning_t = 0.0
	queue_redraw()

func _draw() -> void:
	var fill_w := BAR_W * _display_ink

	# ── Track ──────────────────────────────────────────────────────────────
	draw_rect(Rect2(BAR_X, BAR_Y, BAR_W, BAR_H), Color(0.08, 0.08, 0.12, 0.85))

	if fill_w <= 0.0:
		return

	# ── Determine fill colour ──────────────────────────────────────────────
	var col : Color
	if _in_flow:
		var shimmer := 0.5 + 0.5 * sin(_warning_t * 2.0)
		col = Color(1.0, 0.82 + shimmer * 0.1, 0.15, 1.0)
	elif _display_ink < 0.20:
		var blink := 0.5 + 0.5 * sin(_warning_t)
		col = Color(0.9, 0.15 + blink * 0.2, 0.15, 1.0)
	elif _display_ink < 0.45:
		col = Color(0.95, 0.55, 0.1, 1.0)
	else:
		col = Color(0.25, 0.45, 0.95, 1.0)

	# ── Fill ───────────────────────────────────────────────────────────────
	draw_rect(Rect2(BAR_X, BAR_Y, fill_w, BAR_H), col)

	# Grade flash overlay (colour of grade)
	if _grade_flash > 0.0:
		var fc := _flash_col
		draw_rect(Rect2(BAR_X, BAR_Y, fill_w, BAR_H),
			Color(fc.r, fc.g, fc.b, _grade_flash * 0.55))

	# State-change pulse
	if _pulse > 0.0:
		draw_rect(Rect2(BAR_X, BAR_Y, fill_w, BAR_H),
			Color(1.0, 1.0, 1.0, _pulse * 0.40))

	# Highlight stripe at top
	draw_rect(Rect2(BAR_X, BAR_Y, fill_w, BAR_H * 0.3),
		Color(1.0, 1.0, 1.0, 0.12))

	# ── Label ──────────────────────────────────────────────────────────────
	var label_text := "✦ FLOW" if _in_flow else "INK"
	var label_col  := Color(col.r, col.g, col.b, 0.85)
	draw_string(ThemeDB.fallback_font,
		Vector2(BAR_X + 4.0, BAR_Y - 5.0),
		label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_col)

	draw_string(ThemeDB.fallback_font,
		Vector2(BAR_X + BAR_W - 36.0, BAR_Y - 5.0),
		"%d%%" % int(_display_ink * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_col)
