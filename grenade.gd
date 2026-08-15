extends KinematicBody2D

#Eigene Abprallrechnung statt Physikmaterial, damit das Verhalten nicht von
#der Godot-Version abhaengt
const BOUNCE=0.45
const DAMP=1.1

var kind='he'
var team=-1
var shooter=0
var velocity=Vector2(0,0)
var fuse=1.6

func setup(k,t,who,vel):
	kind=k
	team=t
	shooter=who
	velocity=vel
	fuse=weapons.GRENADES[k]['fuse']

func _physics_process(delta):
	var col=move_and_collide(velocity*delta)
	if col!=null:
		velocity=velocity.bounce(col.normal)*BOUNCE
	velocity=velocity.linear_interpolate(Vector2(0,0),DAMP*delta)
	fuse-=delta
	if fuse<=0.0:
		detonate()

func detonate():
	var d=weapons.GRENADES[kind]
	if kind=='he':
		blast(d['radius'],d['damage'],d['reward'])
	elif kind=='flash':
		flash(d['radius'])
	else:
		var c=load("res://cloud.tscn").instance()
		get_parent().add_child(c)
		c.global_position=global_position
		if kind=='smoke':
			c.setup('smoke',d['radius'],weapons.SMOKE_LIFE,team,shooter,0)
		else:
			c.setup('fire',d['radius'],weapons.FIRE_LIFE,team,shooter,d['damage'])
	queue_free()

#Schaden faellt zur Kante hin auf null ab, Waende schirmen ab
func blast(radius,damage,reward):
	for p in get_tree().get_nodes_in_group('player'):
		if !p.alive:
			continue
		var dist=p.global_position.distance_to(global_position)
		if dist>radius:
			continue
		if wall_between(global_position,p.global_position):
			continue
		var dmg=int(damage*(1.0-dist/radius))
		if dmg<=0:
			continue
		if p.team==team:
			#Eigenes Team nimmt keinen Schaden, so wie im Rest des Spiels
			continue
		p.take_damage(dmg,shooter,reward,0.5,'he')

#Blendwirkung haengt an Entfernung, Blickrichtung und freier Sicht
func flash(radius):
	for p in get_tree().get_nodes_in_group('player'):
		if !p.alive:
			continue
		var to=global_position-p.global_position
		var dist=to.length()
		if dist>radius:
			continue
		if wall_between(global_position,p.global_position):
			continue
		var near=1.0-dist/radius
		var facing=Vector2(cos(p.rotation),sin(p.rotation)).dot(to.normalized())
		if facing<=0.0:
			#Weggedreht wird man kaum geblendet
			facing=0.12
		p.blind(3.0*near*facing)

func wall_between(a,b):
	var space=get_world_2d().direct_space_state
	var hit=space.intersect_ray(a,b,[self],1)
	return !hit.empty()
