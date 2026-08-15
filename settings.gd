extends Node

#Einstellungen liegen in user://settings.cfg und werden beim Start angewandt
const PATH='user://settings.cfg'

var player_name='Player 1'
var fullscreen=false
var vsync=false
var crosshair=true
var show_fps=false

func _ready():
	load_file()
	apply()

func load_file():
	var c=ConfigFile.new()
	if c.load(PATH)!=OK:
		return
	player_name=c.get_value('game','player_name',player_name)
	fullscreen=c.get_value('video','fullscreen',fullscreen)
	vsync=c.get_value('video','vsync',vsync)
	crosshair=c.get_value('hud','crosshair',crosshair)
	show_fps=c.get_value('hud','show_fps',show_fps)

func save():
	var c=ConfigFile.new()
	c.set_value('game','player_name',player_name)
	c.set_value('video','fullscreen',fullscreen)
	c.set_value('video','vsync',vsync)
	c.set_value('hud','crosshair',crosshair)
	c.set_value('hud','show_fps',show_fps)
	c.save(PATH)

func apply():
	OS.window_fullscreen=fullscreen
	OS.vsync_enabled=vsync

func set_option(key,value):
	set(key,value)
	apply()
	save()

#Beschriftung der belegten Tasten, direkt aus der InputMap gelesen
const KEY_ROWS=[
	['forward','Move forward'],
	['backward','Move back'],
	['left','Strafe left'],
	['right','Strafe right'],
	['walk','Walk'],
	['fire','Fire'],
	['reload','Reload'],
	['weapon_1','Handgun'],
	['weapon_2','Rifle'],
	['weapon_3','Shotgun'],
	['weapon_4','Knife'],
	['teammenu','Team menu'],
	['buymenu','Buy menu'],
	['scoreboard','Scoreboard'],
	['nade_he','HE grenade'],
	['nade_flash','Flashbang'],
	['nade_smoke','Smoke'],
	['nade_molotov','Molotov'],
	['use','Plant / defuse (hold)']
]

func binding_text(action):
	if !InputMap.has_action(action):
		return '-'
	var parts=[]
	for e in InputMap.get_action_list(action):
		if e is InputEventKey:
			parts.append(OS.get_scancode_string(e.scancode))
		elif e is InputEventMouseButton:
			if e.button_index==BUTTON_LEFT:
				parts.append('LMB')
			elif e.button_index==BUTTON_RIGHT:
				parts.append('RMB')
			else:
				parts.append('MB'+str(e.button_index))
	if parts.empty():
		return '-'
	return PoolStringArray(parts).join(' / ')
