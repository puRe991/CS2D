extends Sprite

var radius
var par
var parent_radius
var holding=0

const hold_inter=0.3
var tmp_ind

#Ab hier gilt der Stick als ausgelenkt
const dead_zone=0.15

export var Player_Path=NodePath()
var player
func _ready():
	#Am Desktop wird mit WASD und Maus gesteuert, der Stick bleibt aus
	if !OS.has_touchscreen_ui_hint():
		set_process(false)
		set_process_input(false)
		return
	set_process_input(true)
	radius=texture.get_width()/2
	par=get_parent()

	parent_radius=par.texture.get_width()/2
	player=get_node(Player_Path)
func _process(delta):
	#Restore Joystick
	if position!=Vector2(0,0) and !holding:
		move_local_x(-(position.x/2))
		move_local_y(-(position.y/2))

	#Auslenkung 0..1 an den Spieler weiterreichen, der Rest passiert dort
	var strength=position.length()/parent_radius
	if strength>dead_zone:
		player.touch_dir=position.normalized()*min(strength,1)
		player.touch_active=true
	else:
		player.touch_dir=Vector2(0,0)
		player.touch_active=false


func _unhandled_input(event):
	if event is InputEventScreenDrag:
		if global_position.distance_to(event.position)<radius+50 and par.global_position.distance_to(event.position)<parent_radius+150:
			position=(event.position-get_parent().global_position).clamped(parent_radius)
			holding=true
			event.index=10
	elif event is InputEventScreenTouch and true:
		if global_position.distance_to(event.position)<radius:
			event.index=10
			holding=true
		if !event.is_pressed() and event.index==10:
			print(event.index)
			holding=false
