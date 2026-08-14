extends RigidBody2D

#Werden vom Schuetzen beim Spawnen gesetzt
var damage=10
var team=-1

func _ready():
	pass

func _process(delta):
	var bodies=get_colliding_bodies()
	if bodies.empty():
		return
	#Trifft Waende genauso wie Spieler, in beiden Faellen ist die Kugel weg
	for b in bodies:
		if b.is_in_group('player') and b.alive and b.team!=team:
			b.health-=damage
	queue_free()

sync func del():
	queue_free()
