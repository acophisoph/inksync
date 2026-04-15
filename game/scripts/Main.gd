extends Node2D

# ── Configuration ─────────────────────────────────────────────────────────────
## Path to your music file inside assets/music/.
## Rename your track to match, or update this constant.
## Supported formats: .ogg (preferred), .mp3
const SONG_PATH  := "res://assets/music/song.ogg"

## Path to the reference stroke the player traces.
## See assets/strokes/ for examples and the format spec.
const STROKE_PATH := "res://assets/strokes/circle.json"

## Beats per minute of your song. The beat clock and hit windows use this.
const BPM := 120.0

## The player should START their stroke on beat START_BEAT
## and LIFT the pen on beat END_BEAT.
## At 120 BPM, 2 beats = 1 second. Adjust to feel right with your song.
const START_BEAT := 1
const END_BEAT   := 3
# ──────────────────────────────────────────────────────────────────────────────

var _audio_player : AudioStreamPlayer
var _beat_clock   : BeatClock
var _canvas       : DrawingCanvas
var _ghost        : GhostStroke
var _analyzer     : StrokeAnalyzer
var _visualizer   : BeatVisualizer
var _overlay      : ScoreOverlay

var _start_beat_time : float
var _end_beat_time   : float

func _ready() -> void:
	_build_background()
	_setup_audio()
	_setup_beat_clock()
	_setup_canvas()
	_setup_ghost()
	_setup_analyzer()
	_setup_visualizer()
	_setup_overlay()
	_start_session()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.97, 0.97, 0.95)   # soft off-white canvas feel
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	var stream = load(SONG_PATH)
	if stream:
		_audio_player.stream = stream
	else:
		push_warning(
			"InkSync: no song found at '%s'.\n" % SONG_PATH +
			"Running with visual metronome only — see SETUP.md to add music."
		)

func _setup_beat_clock() -> void:
	_beat_clock = BeatClock.new()
	_beat_clock.bpm = BPM
	add_child(_beat_clock)
	_beat_clock.setup(_audio_player)
	_beat_clock.beat_hit.connect(_on_beat)

	var beat_dur       := 60.0 / BPM
	_start_beat_time    = START_BEAT * beat_dur
	_end_beat_time      = END_BEAT   * beat_dur

func _setup_canvas() -> void:
	_canvas = DrawingCanvas.new()
	add_child(_canvas)
	_canvas.setup(_audio_player)
	_canvas.stroke_completed.connect(_on_stroke_completed)

func _setup_ghost() -> void:
	_ghost = GhostStroke.new()
	add_child(_ghost)
	_ghost.load_from_json(STROKE_PATH)

func _setup_analyzer() -> void:
	_analyzer = StrokeAnalyzer.new()
	add_child(_analyzer)

func _setup_visualizer() -> void:
	_visualizer = BeatVisualizer.new()
	add_child(_visualizer)
	_visualizer.position = Vector2(64, 64)   # top-left corner of screen
	_visualizer.setup(_beat_clock)

func _setup_overlay() -> void:
	_overlay = ScoreOverlay.new()
	add_child(_overlay)

func _start_session() -> void:
	_beat_clock.start()
	if _audio_player.stream:
		_audio_player.play()

func _on_beat(beat_number: int) -> void:
	_visualizer.pulse()

func _on_stroke_completed(stroke_data: Array) -> void:
	var result := _analyzer.analyze(
		stroke_data,
		_ghost.get_path(),
		_beat_clock,
		_start_beat_time,
		_end_beat_time
	)
	_overlay.show_result(result)
	_canvas.clear()
