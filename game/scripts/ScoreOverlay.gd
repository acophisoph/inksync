## ScoreOverlay — shows score feedback for 3 seconds after each stroke.
##
## Builds its own UI in code so there's no .tscn dependency.
## All nodes are created in _ready() and the panel is hidden until show_result().

class_name ScoreOverlay
extends CanvasLayer

var _panel        : PanelContainer
var _grade_label  : Label
var _detail_label : Label

func _ready() -> void:
	_build_ui()
	_panel.hide()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)

	# Center the panel on screen (640, 360 at 1280x720)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -160
	_panel.offset_right  =  160
	_panel.offset_top    = -120
	_panel.offset_bottom =  120

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# Big grade letter
	_grade_label = Label.new()
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size", 80)
	vbox.add_child(_grade_label)

	# Accuracy / smoothness / timing breakdown
	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_detail_label)

## Display the result dict from StrokeAnalyzer.analyze() for 3 seconds.
func show_result(result: Dictionary) -> void:
	_grade_label.text  = result["grade"]
	_detail_label.text = (
		"Accuracy    %d%%\nSmoothness  %d%%\nTiming      %d%%" % [
			int(result["accuracy"]   * 100),
			int(result["smoothness"] * 100),
			int(result["timing"]     * 100),
		]
	)
	_panel.show()
	await get_tree().create_timer(3.0).timeout
	_panel.hide()
