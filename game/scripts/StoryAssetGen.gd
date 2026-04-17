## StoryAssetGen — @tool script that generates placeholder silhouette PNGs
## for the Cang Jie story (and any story that needs them).
##
## Run once from the Godot editor: attach to any Node, tick the
## "generate" export bool in the Inspector, then remove the script.
## Output: assets/stories/cangjie/layer_*.png

@tool
extends Node

@export var generate : bool = false :
	set(v):
		if v and Engine.is_editor_hint():
			_generate_all()

const OUT_DIR := "res://assets/stories/cangjie/"
const W := 1280
const H := 720

func _generate_all() -> void:
	_gen_sun()
	_gen_mountain()
	_gen_water()
	_gen_tree()
	_gen_person()
	_gen_moon()
	print("StoryAssetGen: all layer images written to ", OUT_DIR)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _new_img() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))   # fully transparent
	return img

func _ink(alpha: float = 1.0) -> Color:
	return Color(0.08, 0.06, 0.04, alpha)

func _save(img: Image, name: String) -> void:
	var path := OUT_DIR + name
	img.save_png(path)
	print("  wrote ", path)

func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(max(0, cy - ry), min(H, cy + ry + 1)):
		for x in range(max(0, cx - rx), min(W, cx + rx + 1)):
			var dx := float(x - cx) / float(rx)
			var dy := float(y - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(max(0, y), min(H, y + h)):
		for px in range(max(0, x), min(W, x + w)):
			img.set_pixel(px, py, col)

func _fill_triangle(img: Image, ax: int, ay: int, bx: int, by: int,
		cx: int, cy: int, col: Color) -> void:
	var min_x := max(0, min(ax, min(bx, cx)))
	var max_x := min(W - 1, max(ax, max(bx, cx)))
	var min_y := max(0, min(ay, min(by, cy)))
	var max_y := min(H - 1, max(ay, max(by, cy)))
	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			if _point_in_tri(px, py, ax, ay, bx, by, cx, cy):
				img.set_pixel(px, py, col)

func _point_in_tri(px: int, py: int, ax: int, ay: int,
		bx: int, by: int, cx: int, cy: int) -> bool:
	var d1 := _sign(px, py, ax, ay, bx, by)
	var d2 := _sign(px, py, bx, by, cx, cy)
	var d3 := _sign(px, py, cx, cy, ax, ay)
	var has_neg := d1 < 0 or d2 < 0 or d3 < 0
	var has_pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)

func _sign(px: int, py: int, ax: int, ay: int, bx: int, by: int) -> float:
	return float((px - bx) * (ay - by) - (ax - bx) * (py - by))

# ── Layer generators ──────────────────────────────────────────────────────────

func _gen_sun() -> void:
	var img := _new_img()
	var col := _ink(0.92)
	# Sun disc
	_fill_ellipse(img, 970, 150, 100, 100, col)
	# Halo (lighter)
	var halo := _ink(0.18)
	_fill_ellipse(img, 970, 150, 140, 140, halo)
	# Sky wash across top
	for y in range(0, 280):
		var a := (1.0 - float(y) / 280.0) * 0.22
		for x in range(W):
			if img.get_pixel(x, y).a < 0.1:
				img.set_pixel(x, y, Color(0.08, 0.06, 0.04, a))
	_save(img, "layer_sun.png")

func _gen_mountain() -> void:
	var img := _new_img()
	var col := _ink(0.88)
	var soft := _ink(0.40)
	# Three peaks (left, centre tall, right)
	_fill_triangle(img, 40,  620, 340, 200, 640, 620, col)
	_fill_triangle(img, 240, 620, 480, 120, 720, 620, col)
	_fill_triangle(img, 500, 620, 680, 240, 860, 620, col)
	# Soft mist at base
	for y in range(560, 680):
		var a := float(y - 560) / 120.0 * 0.25
		for x in range(W):
			if img.get_pixel(x, y).a < 0.1:
				img.set_pixel(x, y, Color(0.08, 0.06, 0.04, a))
	_save(img, "layer_mountain.png")

func _gen_water() -> void:
	var img := _new_img()
	# Wavy water bands
	for y in range(480, H):
		for x in range(W):
			var wave := sin(float(x) * 0.025 + float(y) * 0.08) * 12.0
			var dist_from_centre := absf(float(y) - 580.0 + wave)
			var a := clampf(1.0 - dist_from_centre / 120.0, 0.0, 1.0)
			if y > 480:
				a *= clampf(float(y - 480) / 60.0, 0.0, 1.0)
			if a > 0.02:
				img.set_pixel(x, y, _ink(a * 0.85))
	_save(img, "layer_water.png")

func _gen_tree() -> void:
	var img := _new_img()
	var col := _ink(0.90)
	# Trunk
	_fill_rect(img, 688, 380, 28, 220, col)
	# Canopy — stacked ellipses
	_fill_ellipse(img, 702, 320, 80, 70, col)
	_fill_ellipse(img, 702, 270, 60, 55, col)
	_fill_ellipse(img, 702, 230, 40, 40, col)
	# Roots
	_fill_triangle(img, 680, 580, 640, 650, 702, 590, _ink(0.55))
	_fill_triangle(img, 720, 580, 760, 650, 702, 590, _ink(0.55))
	_save(img, "layer_tree.png")

func _gen_person() -> void:
	var img := _new_img()
	var col := _ink(0.92)
	# Head
	_fill_ellipse(img, 600, 390, 22, 24, col)
	# Body
	_fill_rect(img, 592, 412, 16, 70, col)
	# Left leg
	_fill_triangle(img, 592, 478, 565, 560, 598, 480, col)
	# Right leg
	_fill_triangle(img, 608, 478, 635, 560, 602, 480, col)
	# Left arm
	_fill_triangle(img, 592, 430, 558, 480, 596, 445, col)
	# Right arm
	_fill_triangle(img, 608, 430, 642, 480, 604, 445, col)
	_save(img, "layer_person.png")

func _gen_moon() -> void:
	var img := _new_img()
	var col := _ink(0.88)
	# Full circle
	_fill_ellipse(img, 1110, 150, 88, 88, col)
	# Bite out (crescent)
	_fill_ellipse(img, 1145, 140, 72, 72, Color(0, 0, 0, 0))
	# Soft glow around moon
	_fill_ellipse(img, 1110, 150, 120, 120, _ink(0.12))
	# Night sky wash top-right corner
	for y in range(0, 240):
		for x in range(900, W):
			if img.get_pixel(x, y).a < 0.05:
				var a := (1.0 - float(y) / 240.0) * (float(x - 900) / 380.0) * 0.15
				img.set_pixel(x, y, _ink(a))
	_save(img, "layer_moon.png")
