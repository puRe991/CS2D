extends Control

const AMBER=Color(0.87,0.62,0.15)
const MUTED=Color(0.62,0.68,0.75)

var panes={}

func _ready():
	print(IP.get_local_addresses())
	panes={
		'play':[$pane_play,$nav_play],
		'settings':[$pane_settings,$nav_settings],
		'controls':[$pane_controls,$nav_controls]
	}
	$pane_play/Name.text=settings.player_name
	fill_controls()
	sync_options()
	show_pane('play')

#Belegung direkt aus der InputMap, damit die Liste nie veraltet
func fill_controls():
	var grid=$pane_controls/grid
	for c in grid.get_children():
		c.queue_free()
	for row in settings.KEY_ROWS:
		var name_label=Label.new()
		name_label.text=row[1]
		name_label.add_color_override('font_color',Color(0.78,0.82,0.87))
		name_label.rect_min_size=Vector2(180,0)
		grid.add_child(name_label)
		var key_label=Label.new()
		key_label.text=settings.binding_text(row[0])
		key_label.add_color_override('font_color',AMBER)
		key_label.rect_min_size=Vector2(110,0)
		grid.add_child(key_label)

func sync_options():
	set_option_button($pane_settings/opt_fullscreen,settings.fullscreen)
	set_option_button($pane_settings/opt_vsync,settings.vsync)
	set_option_button($pane_settings/opt_crosshair,settings.crosshair)
	set_option_button($pane_settings/opt_fps,settings.show_fps)

func set_option_button(b,on):
	b.pressed=on
	var col=MUTED
	b.text='OFF'
	if on:
		col=AMBER
		b.text='ON'
	#Im Toggle-Zustand zieht der Button font_color_pressed, nicht font_color
	b.add_color_override('font_color',col)
	b.add_color_override('font_color_pressed',col)
	b.add_color_override('font_color_hover',col)

func show_pane(which):
	for key in panes:
		var pane=panes[key][0]
		var nav=panes[key][1]
		var active=(key==which)
		pane.visible=active
		if active:
			nav.add_color_override('font_color',AMBER)
			$indicator.margin_top=nav.margin_top
			$indicator.margin_bottom=nav.margin_bottom
		else:
			nav.add_color_override('font_color',MUTED)

func _on_nav_play_pressed():
	show_pane('play')

func _on_nav_settings_pressed():
	show_pane('settings')

func _on_nav_controls_pressed():
	show_pane('controls')

func _on_nav_quit_pressed():
	get_tree().quit()

func _on_fullscreen_toggled(on):
	settings.set_option('fullscreen',on)
	set_option_button($pane_settings/opt_fullscreen,on)

func _on_vsync_toggled(on):
	settings.set_option('vsync',on)
	set_option_button($pane_settings/opt_vsync,on)

func _on_crosshair_toggled(on):
	settings.set_option('crosshair',on)
	set_option_button($pane_settings/opt_crosshair,on)

func _on_fps_toggled(on):
	settings.set_option('show_fps',on)
	set_option_button($pane_settings/opt_fps,on)

func remember_name():
	settings.player_name=$pane_play/Name.text
	settings.save()

func _on_server_pressed():
	remember_name()
	multiplayer.make_server($pane_play/port.text,$pane_play/Name.text)
	load_playerlist()

func _on_client_pressed():
	remember_name()
	multiplayer.make_client($pane_play/ip.text,$pane_play/port.text,$pane_play/Name.text)
	load_playerlist()

func load_playerlist():
	get_tree().change_scene("res://lobby_players.tscn")
