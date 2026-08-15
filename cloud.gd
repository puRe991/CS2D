extends Node2D

#Rauch und Feuer teilen sich diesen Knoten. Rauch blockiert Sicht, Feuer
#macht Schaden im Takt
var kind='smoke'
var radius=400.0
var life=10.0
var team=-1
var shooter=0
var damage=0
var tick=0.0
var grow=0.0

func setup(k,r,l,t,who,dmg):
	kind=k
	radius=r
	life=l
	team=t
	shooter=who
	damage=dmg
	if k=='smoke':
		add_to_group('smoke')
	set_as_toplevel(true)

func _process(delta):
	if grow<1.0:
		grow+=delta*2.5
		if grow>1.0:
			grow=1.0
	life-=delta
	if life<=0.0:
		queue_free()
		return
	if kind=='fire':
		tick-=delta
		if tick<=0.0:
			tick=weapons.FIRE_TICK
			burn()
	update()

func burn():
	for p in get_tree().get_nodes_in_group('player'):
		if !p.alive or p.team==team:
			continue
		if p.global_position.distance_to(global_position)<=current_radius():
			p.take_damage(damage,shooter,weapons.GRENADES['molotov']['reward'],0.9,'molotov')

func current_radius():
	return radius*grow

#Abstand Punkt zu Strecke, damit eine Sichtlinie am Kreis geprueft werden kann
func blocks(a,b):
	if kind!='smoke':
		return false
	var ab=b-a
	var len2=ab.length_squared()
	var closest=a
	if len2>0.0:
		var t=(global_position-a).dot(ab)/len2
		if t<0.0:
			t=0.0
		if t>1.0:
			t=1.0
		closest=a+ab*t
	return closest.distance_to(global_position)<=current_radius()

func _draw():
	var r=current_radius()
	if kind=='smoke':
		draw_circle(Vector2(0,0),r,Color(0.72,0.74,0.76,0.93))
		draw_circle(Vector2(0,0),r*0.82,Color(0.79,0.81,0.83,0.96))
	else:
		draw_circle(Vector2(0,0),r,Color(0.85,0.35,0.09,0.42))
		draw_circle(Vector2(0,0),r*0.66,Color(0.95,0.6,0.15,0.55))
