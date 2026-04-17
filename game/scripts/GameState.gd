## GameState — autoload singleton for passing data between scenes.
extends Node

var song_path   : String = ""
var bpm         : float  = 90.0
var shape_index : int    = 0
var character   : String = ""

# Story Mode
var story_path        : String = ""   # res:// path to the active story.json
var story_char_index  : int    = 0    # index of the next character to practice
