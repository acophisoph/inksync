## BeatVisualizer — a pulsing dot in the corner that shows the beat.
##
## The ring fills up like a progress bar during each beat, then
## flashes bright when the beat fires. Position is set in Main.gd.

class_name BeatVisualizer
extends Node2D

const RING_RADIUS  := 22.0
const DOT_RADIUS   := 10.0
const RING_WIDTH   := 3.0
const BEAT_COLOR   := Color(1.0, 0.75, 0.15, 1.0)    # warm yellow
const RING_BG_CLR  := Color(0.3,  0.3,  0.3,  0.4)
const FLASH_COLOR  := Color(1.0, 0.92, 0.4,  1.0)

var _beat_clock   : BeatClock
var _flash_scale  : float = 1.0   # > 1.0 right after a beat hit, decays to 1.0

func setup(beat_clock: BeatClock) -> void:
	_beat_clock = beat_clock

## Called by Main._on_beat() every beat.
func pulse() -> void:
	_flash_scale = 2.0

func _process(delta: float) -> void:
	if _flash_scale > 1.0:
		_flash_scale = move_toward(_flash_scale, 1.0, delta * 10.0)
	queue_redraw()

func _draw() -> void:
	# Background ring
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48, RING_BG_CLR, RING_WIDTH)

	# Progress arc — fills up across the beat
	if _beat_clock:
		var phase := _beat_clock.get_beat_phase()
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS,
			-PI * 0.5,                    # start at 12 o'clock
			-PI * 0.5 + phase * TAU,
			48,
			BEAT_COLOR,
			RING_WIDTH
		)

	# Central dot — flashes and scales on each beat
	var r := DOT_RADIUS * _flash_scale
	draw_circle(Vector2.ZERO, r, FLASH_COLOR if _flash_scale > 1.2 else BEAT_COLOR)
