extends Node2D

#Die C4 kennt drei Zustaende: getragen, liegend, scharf
const CARRIED=0
const DROPPED=1
const ARMED=2

const FUSE=40.0
const PLANT_TIME=3.2
const DEFUSE_TIME=10.0
const DEFUSE_TIME_KIT=5.0
const SITE_RADIUS=560.0
const REACH=150.0

var state=CARRIED
var carrier=0
var timer=0.0
var blink=0.0

func _process(delta):
	if state==CARRIED:
		var p=get_parent().get_node_or_null(str(carrier))
		if p!=null and p.alive:
			global_position=p.global_position
		else:
			#Traeger ist tot, die Bombe bleibt liegen
			state=DROPPED
	elif state==ARMED:
		timer-=delta
		if timer<0.0:
			timer=0.0
	blink+=delta
	update()

func give_to(id):
	state=CARRIED
	carrier=id

func drop():
	state=DROPPED
	carrier=0

func arm():
	state=ARMED
	carrier=0
	timer=FUSE

func can_reach(p):
	return global_position.distance_to(p.global_position)<=REACH

func _draw():
	if state==CARRIED:
		return
	var col=Color(0.55,0.45,0.2,1)
	if state==ARMED:
		#Blinkt schneller je knapper die Zeit
		var speed=2.0+6.0*(1.0-timer/FUSE)
		if fmod(blink*speed,1.0)<0.5:
			col=Color(0.95,0.25,0.2,1)
		else:
			col=Color(0.4,0.12,0.1,1)
	draw_circle(Vector2(0,0),22.0,Color(0.1,0.09,0.07,0.9))
	draw_circle(Vector2(0,0),15.0,col)
