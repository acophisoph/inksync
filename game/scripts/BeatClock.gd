## BeatClock — the heartbeat of InkSync.
##
## Tracks playback position against BPM to emit beat_hit signals and expose
## beat-phase helpers used by the visualizer and stroke analyzer.
## Works with or without an AudioStreamPlayer (falls back to wall clock).

class_name BeatClock
extends Node

## Fired every time a new beat starts.
signal beat_hit(beat_number: int)

## Beats per minute. Set this before calling setup().
@export var bpm: float = 120.0

var _beat_duration : float        # seconds per beat
var _last_beat     : int = -1
var _audio_player  : AudioStreamPlayer
var _start_time    : float = 0.0  # wall clock reference when no audio

func setup(audio_player: AudioStreamPlayer) -> void:
	_audio_player  = audio_player
	_beat_duration = 60.0 / bpm

func start() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	_last_beat  = -1

func _process(_delta: float) -> void:
	var pos := _playback_position()
	var current_beat := int(pos / _beat_duration)
	if current_beat != _last_beat:
		_last_beat = current_beat
		beat_hit.emit(current_beat)

## Returns seconds elapsed since playback started.
func _playback_position() -> float:
	if _audio_player and _audio_player.playing:
		return _audio_player.get_playback_position()
	return Time.get_ticks_msec() / 1000.0 - _start_time

## 0.0 at the start of a beat, 1.0 just before the next beat.
func get_beat_phase() -> float:
	return fmod(_playback_position(), _beat_duration) / _beat_duration

## Seconds since/until the nearest beat.
## Negative = beat just passed, positive = beat coming up.
func time_to_nearest_beat() -> float:
	var phase := fmod(_playback_position(), _beat_duration)
	if phase > _beat_duration * 0.5:
		return phase - _beat_duration   # past the beat
	return phase                        # approaching the beat

## Absolute song time right now (used to timestamp strokes).
func current_time() -> float:
	return _playback_position()
