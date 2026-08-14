extends KinematicBody2D

#Geschwindigkeiten in Pixel pro Sekunde
export var speed_walk=260
export var speed_run=660
export var health = 100

var bullets=10

var weapon='handgun'

#Wird vom Touch Joystick (CanvasLayer/Joystick/joytop) gesetzt
var touch_dir=Vector2(0,0)
var touch_active=false

#Auf Handy/Tablet wird mit dem Joystick gezielt, sonst mit der Maus
var touch_ui=false

#Zuletzt an die anderen Peers geschickte Animationen
var body_state=''
var feet_state=''

remote var pla=false
remote var rrot=0
remote var rpos=Vector2(0,0)
func _ready():
	touch_ui=OS.has_touchscreen_ui_hint()

func delrest():
	if get_name()!=str(get_tree().get_network_unique_id()):
		$CanvasLayer.queue_free()
		$Camera2D.queue_free()
		$showmask.queue_free()
	elif !touch_ui:
		$CanvasLayer/Joystick.hide()
		$CanvasLayer/fire.hide()
		$CanvasLayer/reload.hide()
	set_network_master(int(get_name()))
	$Name.text=multiplayer.players[int(get_name())]

func _process(delta):
	if is_network_master():
		$CanvasLayer/hp.value=health
		$CanvasLayer/bullets.text=str(bullets)
	if health<=0 and is_network_master():
		var cam=$Camera2D
		remove_child(cam)
		if get_tree().get_nodes_in_group('player').size()>1:
			for x in get_tree().get_nodes_in_group('player'):
				if x != self:
					x.add_child(cam)
					cam.position=Vector2(0,0)
		rpc('del')

#Blickrichtung: Maus am Desktop, Joystick am Touchgeraet
func aim():
	if touch_ui:
		if touch_active:
			rotation=touch_dir.angle()
	else:
		rotation=(get_global_mouse_position()-global_position).angle()

#WASD, faellt auf den Joystick zurueck solange keine Taste gedrueckt ist
func input_direction():
	var dir=Vector2(0,0)
	if Input.is_action_pressed('right'):
		dir.x+=1
	if Input.is_action_pressed('left'):
		dir.x-=1
	if Input.is_action_pressed('backward'):
		dir.y+=1
	if Input.is_action_pressed('forward'):
		dir.y-=1
	if dir!=Vector2(0,0):
		return dir.normalized()
	if touch_active:
		return touch_dir
	return dir

func _physics_process(delta):
	if is_network_master():
		aim()

		var direction=input_direction()
		var walking=Input.is_action_pressed('walk')
		if walking:
			move_and_slide(direction*speed_walk)
		else:
			move_and_slide(direction*speed_run)

		if direction==Vector2(0,0):
			animate_feet('idle')
		else:
			#Laufrichtung relativ zur Blickrichtung, x=vorwaerts y=rechts
			var local=direction.rotated(-rotation)
			if abs(local.y)>abs(local.x):
				if local.y>0:
					animate_feet('strafe-right')
				else:
					animate_feet('strafe-left')
			elif walking:
				animate_feet('walk')
			else:
				animate_feet('run')

		if !pla:
			if direction==Vector2(0,0):
				animate_body(weapon+'-idle')
			else:
				animate_body(weapon+'-move')

		if Input.is_action_just_pressed('fire') and bullets and !pla:
			bullets-=1
			animate_body(weapon+'-shoot',true)
			pla=true
			rset('pla',pla)
			rpc('fire')

		if Input.is_action_just_pressed('reload') and bullets<10 and !pla:
			bullets=10
			animate_body(weapon+'-reload',true)
			pla=true
			rset('pla',pla)

		rpos=position
		rrot=rotation
		rset('rpos',rpos)
		rset('rrot',rrot)

	else:
		rotation=rrot
		position=rpos


sync func fire():
	var direction=Vector2(cos(rotation),sin(rotation))
	var bul=multiplayer.bullet.instance()
	get_parent().add_child(bul)
	bul.global_rotation=global_rotation
	bul.global_position=$firepoint.global_position
	bul.apply_impulse(Vector2(0,0),direction*2000)
#Animations
#Nur bei Wechsel senden, sonst laeuft jeden Frame ein RPC raus
func animate_body(anim,force=false):
	if anim==body_state and !force:
		return
	body_state=anim
	rpc('animation',anim,'')

func animate_feet(anim):
	if anim==feet_state:
		return
	feet_state=anim
	rpc('animation','',anim)

sync func animation(body_anim,feet_anim):

	if feet_anim:
		$feet.play(feet_anim)
	if body_anim:
		if $body.animation==body_anim:
			$body.frame=0
		$body.play(body_anim)
sync func del():
	queue_free()

func _on_body_animation_finished():
	if $body.animation==weapon+'-shoot' or $body.animation==weapon+'-reload':
		pla=false
