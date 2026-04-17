## CharacterReaction — one-shot visual burst when a character is completed.
##
## Shows the character's English meaning + a colour-coded particle effect
## tied to what the character means (water, fire, earth, sky, person, …).
## Self-destructs after the animation finishes.
##
## Usage:  CharacterReaction.spawn(parent_node, "水")

class_name CharacterReaction
extends Node2D

# ── Meaning database ──────────────────────────────────────────────────────────
const CHAR_INFO := {
	"一":{"m":"one",      "fx":"sky"},   "二":{"m":"two",     "fx":"sky"},
	"三":{"m":"three",    "fx":"sky"},   "四":{"m":"four",    "fx":"sky"},
	"五":{"m":"five",     "fx":"sky"},   "六":{"m":"six",     "fx":"sky"},
	"七":{"m":"seven",    "fx":"sky"},   "八":{"m":"eight",   "fx":"sky"},
	"九":{"m":"nine",     "fx":"sky"},   "十":{"m":"ten",     "fx":"sky"},
	"百":{"m":"hundred",  "fx":"sky"},   "千":{"m":"thousand","fx":"sky"},
	"万":{"m":"ten-thousand","fx":"sky"},"零":{"m":"zero",    "fx":"sky"},
	"人":{"m":"person",   "fx":"person"},"大":{"m":"big",     "fx":"person"},
	"小":{"m":"small",    "fx":"person"},"中":{"m":"middle",  "fx":"earth"},
	"国":{"m":"country",  "fx":"earth"}, "男":{"m":"man",     "fx":"person"},
	"女":{"m":"woman",    "fx":"person"},"子":{"m":"child",   "fx":"person"},
	"父":{"m":"father",   "fx":"person"},"母":{"m":"mother",  "fx":"person"},
	"哥":{"m":"elder bro","fx":"person"},"弟":{"m":"younger bro","fx":"person"},
	"儿":{"m":"son",      "fx":"person"},"朋":{"m":"friend",  "fx":"spirit"},
	"友":{"m":"friend",   "fx":"spirit"},"爱":{"m":"love",    "fx":"spirit"},
	"心":{"m":"heart",    "fx":"spirit"},"喜":{"m":"joy",     "fx":"spirit"},
	"欢":{"m":"happy",    "fx":"spirit"},
	"水":{"m":"water",    "fx":"water"}, "冷":{"m":"cold",    "fx":"water"},
	"河":{"m":"river",    "fx":"water"}, "海":{"m":"sea",     "fx":"water"},
	"火":{"m":"fire",     "fx":"fire"},  "热":{"m":"hot",     "fx":"fire"},
	"红":{"m":"red",      "fx":"fire"},
	"山":{"m":"mountain", "fx":"earth"}, "土":{"m":"earth",   "fx":"earth"},
	"地":{"m":"ground",   "fx":"earth"}, "金":{"m":"gold",    "fx":"metal"},
	"石":{"m":"stone",    "fx":"earth"},
	"木":{"m":"tree",     "fx":"nature"},"草":{"m":"grass",   "fx":"nature"},
	"花":{"m":"flower",   "fx":"nature"},"绿":{"m":"green",   "fx":"nature"},
	"天":{"m":"sky",      "fx":"sky"},   "月":{"m":"moon",    "fx":"sky"},
	"日":{"m":"sun",      "fx":"sky"},   "云":{"m":"cloud",   "fx":"sky"},
	"风":{"m":"wind",     "fx":"sky"},   "白":{"m":"white",   "fx":"sky"},
	"北":{"m":"north",    "fx":"sky"},   "南":{"m":"south",   "fx":"sky"},
	"东":{"m":"east",     "fx":"sky"},   "西":{"m":"west",    "fx":"sky"},
	"手":{"m":"hand",     "fx":"person"},"口":{"m":"mouth",   "fx":"person"},
	"目":{"m":"eye",      "fx":"person"},"耳":{"m":"ear",     "fx":"person"},
	"头":{"m":"head",     "fx":"person"},"身":{"m":"body",    "fx":"person"},
	"面":{"m":"face",     "fx":"person"},
	"上":{"m":"up",       "fx":"sky"},   "下":{"m":"down",    "fx":"earth"},
	"左":{"m":"left",     "fx":"earth"}, "右":{"m":"right",   "fx":"earth"},
	"门":{"m":"door",     "fx":"earth"}, "家":{"m":"home",    "fx":"earth"},
	"路":{"m":"road",     "fx":"earth"}, "书":{"m":"book",    "fx":"spirit"},
	"学":{"m":"study",    "fx":"spirit"},"校":{"m":"school",  "fx":"spirit"},
	"年":{"m":"year",     "fx":"sky"},
}

const FX_COLORS := {
	"water":  Color(0.25, 0.60, 1.00),
	"fire":   Color(1.00, 0.42, 0.08),
	"earth":  Color(0.65, 0.45, 0.20),
	"nature": Color(0.28, 0.80, 0.32),
	"sky":    Color(0.75, 0.88, 1.00),
	"person": Color(0.95, 0.78, 0.50),
	"spirit": Color(1.00, 0.45, 0.80),
	"metal":  Color(1.00, 0.88, 0.30),
	"default":Color(0.35, 0.45, 1.00),
}

# ── Instance state ────────────────────────────────────────────────────────────
var _char     : String = ""
var _meaning  : String = ""
var _category : String = "default"
var _life     : float  = 2.8
var _max_life : float  = 2.8

var _particles : Array = []
var _rings     : Array = []

# ── Static factory ────────────────────────────────────────────────────────────
static func spawn(parent: Node, character: String) -> void:
	var r := CharacterReaction.new()
	r._char = character
	var info : Dictionary = CHAR_INFO.get(character, {})
	r._meaning  = info.get("m", "")
	r._category = info.get("fx", "default")
	r.z_index   = 20
	parent.add_child(r)

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var col  := _get_color()
	var cx   := 640.0
	var cy   := 360.0

	# Particles — direction depends on fx type
	for i in 30:
		var angle := randf() * TAU
		var speed := randf_range(90.0, 320.0)
		var vel   := Vector2(cos(angle), sin(angle)) * speed
		if _category == "fire":
			vel.y = -absf(vel.y) - 40.0   # always upward
		elif _category == "sky":
			vel.y = absf(vel.y) * 0.5      # drift downward gently
		elif _category == "water":
			vel.y = absf(vel.y) * 0.3      # pool downward

		_particles.append({
			"pos":      Vector2(cx, cy),
			"vel":      vel,
			"life":     randf_range(0.6, 2.2),
			"max_life": 2.2,
			"col":      col.lerp(Color.WHITE, randf() * 0.35),
			"size":     randf_range(5.0, 16.0),
		})

	# Expanding ring(s)
	_rings.append({"pos": Vector2(cx, cy), "r": 10.0, "target": 300.0,
		"life": 1.4, "max_life": 1.4, "col": col})
	if _category in ["fire", "spirit"]:
		_rings.append({"pos": Vector2(cx, cy), "r": 10.0, "target": 180.0,
			"life": 1.0, "max_life": 1.0,
			"col": col.lerp(Color.WHITE, 0.5)})

func _get_color() -> Color:
	return FX_COLORS.get(_category, FX_COLORS["default"])

# ── Loop ──────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	for p in _particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.93
		match _category:
			"fire":   p["vel"].y -= 160.0 * delta
			"water":  p["vel"].y +=  50.0 * delta
			"nature": p["vel"].x += sin(p["life"] * 8.0) * 20.0 * delta
		p["life"] -= delta
	_particles = _particles.filter(func(p): return p["life"] > 0.0)

	for ring in _rings:
		ring["r"]    = move_toward(ring["r"], ring["target"], delta * 400.0)
		ring["life"] -= delta
	_rings = _rings.filter(func(r): return r["life"] > 0.0)

	queue_redraw()

func _draw() -> void:
	var global_a := clampf(_life / _max_life * 2.5, 0.0, 1.0)

	# Rings
	for ring in _rings:
		var a: float = (float(ring["life"]) / float(ring["max_life"])) * 0.55 * global_a
		var c : Color = ring["col"]
		draw_arc(ring["pos"], ring["r"], 0.0, TAU, 48,
			Color(c.r, c.g, c.b, a), 3.5, true)

	# Particles
	for p in _particles:
		var a: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0) * global_a
		var c : Color = p["col"]
		draw_circle(p["pos"], p["size"] * (0.4 + a * 0.6),
			Color(c.r, c.g, c.b, a * 0.9))

	# Meaning text — fades in then out
	if not _meaning.is_empty():
		var t       := 1.0 - _life / _max_life          # 0→1 over lifetime
		var text_a  := clampf(sin(t * PI) * 1.8, 0.0, 1.0) * global_a
		var txt     := '"%s"' % _meaning
		draw_string(ThemeDB.fallback_font,
			Vector2(640.0, 295.0),
			txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 26,
			Color(0.95, 0.95, 0.95, text_a))
