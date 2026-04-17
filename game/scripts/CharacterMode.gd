## CharacterMode — Chinese character stroke-order practice.
##
## Shows HSK character grids. Clicking a character enters a rhythm
## tracing session. Characters with stroke data in assets/characters/
## get ghost-path guided practice; others get free-trace mode.

extends Node2D

const HSK1 := [
	"一","二","三","四","五","六","七","八","九","十",
	"百","千","万","零","个","人","大","小","中","国",
	"的","了","是","不","在","有","我","你","他","她",
	"们","这","那","上","下","来","去","说","看","想",
	"好","多","少","很","都","也","和","与","但","就",
	"年","月","日","时","分","今","明","昨","前","后",
	"左","右","里","外","东","西","南","北","地","天",
	"水","火","山","木","金","土","手","口","目","耳",
	"心","身","头","面","名","字","书","学","校","老",
	"师","生","男","女","子","家","房","门","车","路",
	"吃","喝","睡","走","跑","坐","站","买","卖","用",
	"钱","元","块","毛","分","颜","色","红","白","黑",
	"新","旧","高","低","长","短","快","慢","冷","热",
	"问","答","请","谢","对","错","可","以","能","会",
	"喜","欢","爱","朋","友","儿","父","母","哥","弟",
]

const HSK2 := [
	"吧","班","半","帮","报","比","别","病","才","层",
	"差","唱","出","楚","从","错","带","道","得","第",
	"点","店","电","读","法","饭","非","够","关","贵",
	"过","还","孩","汉","合","花","话","画","换","回",
	"级","几","件","健","将","近","进","经","觉","开",
	"课","客","空","累","两","另","楼","旅","绿","满",
	"妹","民","明","拿","难","哪","旁","票","平","起",
	"然","认","如","身","什","试","事","太","题","听",
	"完","晚","玩","往","为","位","午","向","写","行",
	"姓","休","眼","已","因","影","游","鱼","运","再",
	"找","真","知","直","重","住","准","把","被","除",
	"春","词","当","动","独","风","该","更","工","共",
	"果","号","活","极","觉","刻","没","呢","批","期",
	"然","色","深","识","通","文","系","新","业","意",
	"用","语","整","正","志","终","种","自","总","最",
]

const HSK3 := [
	"爱","安","按","把","白","帮","报","杯","本","比",
	"必","毕","表","并","波","部","步","查","常","成",
	"乘","冲","聪","村","但","导","到","掉","懂","断",
	"堆","而","发","防","放","飞","感","跟","贡","海",
	"黑","坏","欢","活","机","将","科","可","快","里",
	"律","木","呢","能","批","确","然","润","色","深",
	"石","识","数","说","谈","通","往","文","系","想",
	"笑","信","行","学","业","意","引","由","语","整",
	"正","志","种","总","最","作","阿","啊","笔","表",
	"波","玻","步","差","常","成","村","但","当","掉",
	"而","防","放","飞","感","该","跟","共","果","号",
	"黑","坏","活","机","极","觉","刻","律","没","期",
	"认","润","识","通","系","业","意","整","志","终",
	"自","总","最","安","按","必","毕","并","冲","聪",
	"断","堆","贡","石","数","引","由","作","阿","啊",
]

const HSK4 := [
	"爱护","包括","保护","必须","标准","部分","参加","层次","常识",
	"成功","传统","促进","达到","代替","当地","道德","的确","地方",
	"发展","方面","方式","分析","服从","改变","改革","各种","公共",
	"关系","广泛","规律","过程","合理","积极","基本","基础","计划",
	"技术","加强","坚持","建立","结合","解决","经济","经验","具体",
	"开展","科学","理论","利用","联系","了解","目的","内容","能力",
	"培养","批评","平衡","普遍","其中","全面","确保","人民","认识",
	"任务","社会","生产","实践","实现","事业","适当","说明","思想",
]

const HSK5 := [
	"阐述","彻底","促使","存在","单纯","当然","道路","典型","调整",
	"动力","对于","发挥","方针","分配","概括","各自","贯彻","广大",
	"规划","过渡","和谐","积累","基于","健全","建设","具有","决定",
	"可能","克服","历史","联合","落实","面临","明确","内在","凝聚",
	"平衡","普及","其次","强调","确立","人才","认可","融合","社区",
	"深化","生活","实施","探索","统一","推进","完善","维护","务必",
	"系统","相互","协调","形成","研究","依据","引导","优化","有效",
]

const HSK6 := [
	"阐明","彻头彻尾","持续","创新","促进","代价","当务之急","道义",
	"奠定","动态","多元","发扬","方案","奋斗","扶持","概念","干预",
	"高度","贯穿","规范","和平","弘扬","化解","积极性","激励","坚守",
	"建构","践行","精准","抉择","科技","力量","联动","路径","论证",
	"蒙古","民主","模式","内涵","凝练","培育","剖析","倡导","契机",
	"强化","权衡","诠释","认同","融通","深刻","生态","实效","视野",
	"探讨","体系","提升","统筹","拓展","稳步","务实","协同","省略",
]

const ALL_LEVELS := [HSK1, HSK2, HSK3, HSK4, HSK5, HSK6]

const LEVEL_COLORS := [
	Color(0.35, 0.72, 1.0),   # HSK 1 — blue
	Color(0.4,  0.82, 0.45),  # HSK 2 — green
	Color(1.0,  0.78, 0.2),   # HSK 3 — gold
	Color(1.0,  0.55, 0.2),   # HSK 4 — orange
	Color(0.9,  0.35, 0.35),  # HSK 5 — red
	Color(0.7,  0.35, 0.9),   # HSK 6 — purple
]

var _current_level : int = 0
var _grid_container : GridContainer
var _status_bar : Label

func _ready() -> void:
	_build_background()
	_build_ui()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.07, 0.07, 0.11)
	bg.size     = Vector2(1280, 720)
	bg.position = Vector2.ZERO
	add_child(bg)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_build_top_bar())
	layer.add_child(_build_character_grid())
	layer.add_child(_build_status_bar())

func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 60
	bar.offset_left   = 20
	bar.offset_right  = -20
	bar.add_theme_constant_override("separation", 16)

	var back := _make_btn("← Menu")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	bar.add_child(back)

	var title := Label.new()
	title.text = "漢  Character Mode"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)

	for lvl in 6:
		var btn := Button.new()
		btn.text = "HSK %d" % (lvl + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 14)
		var col : Color = LEVEL_COLORS[lvl]
		var s := StyleBoxFlat.new()
		s.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.8)
		s.border_color = col if lvl == _current_level else Color(col.r, col.g, col.b, 0.3)
		s.border_width_left   = 2
		s.border_width_right  = 2
		s.border_width_top    = 2
		s.border_width_bottom = 2
		s.corner_radius_top_left     = 6
		s.corner_radius_top_right    = 6
		s.corner_radius_bottom_left  = 6
		s.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_color_override("font_color", col)
		var captured_lvl := lvl
		btn.pressed.connect(func(): _switch_level(captured_lvl))
		bar.add_child(btn)

	return bar

func _build_character_grid() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top    = 68
	scroll.offset_bottom = -40
	scroll.offset_left   = 20
	scroll.offset_right  = -20

	_grid_container = GridContainer.new()
	_grid_container.columns = 15
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_container)

	_populate_grid()
	return scroll

func _build_status_bar() -> Control:
	_status_bar = Label.new()
	_status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_bar.offset_top  = -36
	_status_bar.offset_left = 20
	_status_bar.add_theme_font_size_override("font_size", 13)
	_status_bar.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	_status_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_refresh_status()
	return _status_bar

func _populate_grid() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	var chars : Array = ALL_LEVELS[_current_level]
	for i in chars.size():
		var ch : String = chars[i]
		_grid_container.add_child(_make_char_button(ch, i))

func _switch_level(lvl: int) -> void:
	_current_level = lvl
	_populate_grid()
	_refresh_status()

func _make_char_button(character: String, _index: int) -> Button:
	var btn := Button.new()
	btn.text = character
	btn.custom_minimum_size = Vector2(68, 68)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 28)
	btn.tooltip_text = "Practice: %s" % character

	var accent : Color = LEVEL_COLORS[_current_level]
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color     = Color(0.12, 0.12, 0.18)
	s_normal.border_color = Color(accent.r, accent.g, accent.b, 0.2)
	s_normal.border_width_left   = 1
	s_normal.border_width_right  = 1
	s_normal.border_width_top    = 1
	s_normal.border_width_bottom = 1
	s_normal.corner_radius_top_left     = 8
	s_normal.corner_radius_top_right    = 8
	s_normal.corner_radius_bottom_left  = 8
	s_normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", s_normal)

	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color     = Color(0.18, 0.18, 0.28)
	s_hover.border_color = accent
	s_hover.border_width_left   = 2
	s_hover.border_width_right  = 2
	s_hover.border_width_top    = 2
	s_hover.border_width_bottom = 2
	s_hover.corner_radius_top_left     = 8
	s_hover.corner_radius_top_right    = 8
	s_hover.corner_radius_bottom_left  = 8
	s_hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", s_hover)

	btn.pressed.connect(func(): _on_character_selected(character))
	return btn

func _refresh_status() -> void:
	var chars : Array = ALL_LEVELS[_current_level]
	var has_data_note := "  •  Characters with stroke data show guided practice"
	_status_bar.text = "HSK %d  •  %d characters  •  Click any character to practice%s" % [
		_current_level + 1, chars.size(), has_data_note
	]

func _on_character_selected(character: String) -> void:
	GameState.character = character
	get_tree().change_scene_to_file("res://scenes/CharacterPractice.tscn")

func _make_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text       = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	return btn
