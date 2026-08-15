extends RigidBody2D

#Werden vom Schuetzen beim Spawnen gesetzt
var damage=10
var team=-1
var shooter=0
var reward=0
var armor_pen=0.0
var wname=''
var origin=Vector2(0,0)
var falloff_start=0.0
var falloff_end=1.0
var falloff_min=1.0

#Schaden faellt mit der Flugstrecke ab
func damage_at_range():
	if falloff_end<=falloff_start:
		return damage
	var dist=global_position.distance_to(origin)
	if dist<=falloff_start:
		return damage
	var t=(dist-falloff_start)/(falloff_end-falloff_start)
	if t>1.0:
		t=1.0
	return int(damage*(1.0-(1.0-falloff_min)*t))

func _ready():
	pass

func _process(delta):
	var bodies=get_colliding_bodies()
	if bodies.empty():
		return
	#Trifft Waende genauso wie Spieler, in beiden Faellen ist die Kugel weg
	for b in bodies:
		if b.is_in_group('player') and b.alive and b.team!=team:
			b.take_damage(damage_at_range(),shooter,reward,armor_pen,wname)
	queue_free()

sync func del():
	queue_free()
