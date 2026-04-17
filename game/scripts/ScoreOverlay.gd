## ScoreOverlay — compact score panel anchored to the bottom-right corner.
## Slides in after each round, stays for 2.5 seconds, then hides.
## Does NOT cover the drawing canvas.

class_name ScoreOverlay
extends CanvasLayer

const GRADE_COLORS := {
	"S": Color(1.0,  0.85, 0.1,  1.0),   # gold
	"A": Color(0.3,  0.85, 0.35, 1.0),   # green
	"B": Color(0.3,  0.6,  1.0,  1.0),   # blue
	"C": Color(0.85, 0.75, 0.2,  1.0),   # yellow
	"D": Color(0.75, 0.3,  0.3,  1.0),   # red
}

var _panel        : PanelContainer
var _grade_label  : Label
var _detail_label : Label

func _ready() -> void:
	_build_ui()
	_panel.hide()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)

	# Bottom-right corner — stays out of the drawing area
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left   = -220
	_panel.offset_right  = -16
	_panel.offset_top    = -160
	_panel.offset_bottom = -16

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_panel.add_child(hbox)

	# Big grade letter on the left
	_grade_label = Label.new()
	_grade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size", 64)
	_grade_label.custom_minimum_size = Vector2(72, 0)
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_grade_label)

	# Separator line
	var sep := VSeparator.new()
	hbox.add_child(sep)

	# Stats on the right
	_detail_label = Label.new()
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 17)
	hbox.add_child(_detail_label)

func show_result(result: Dictionary) -> void:
	var grade: String = result["grade"]
	_grade_label.text = grade
	_grade_label.add_theme_color_override(
		"font_color",
		GRADE_COLORS.get(grade, Color.WHITE)
	)
	_detail_label.text = (
		"Accuracy    %d%%\nSmoothness  %d%%\nTiming      %d%%" % [
			int(result["accuracy"]   * 100),
			int(result["smoothness"] * 100),
			int(result["timing"]     * 100),
		]
	)
	_panel.show()
	await get_tree().create_timer(2.5).timeout
	_panel.hide()
