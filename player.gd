extends KinematicBody2D

#Geschwindigkeiten in Pixel pro Sekunde
export var speed_walk=260
export var speed_run=660
export var health = 100

var weapon='handgun'
var mag={}
var owned={}
var armor=0
var alive=true
var team=0
var reloading=false

#Waehrend der Freeze Time am Rundenanfang darf gezielt und gekauft, aber
#nicht gelaufen oder geschossen werden
var frozen=false

#Wer zuletzt getroffen hat, damit der Server den Kill verguetet
var last_hit_by=0
var last_reward=0

#Wird vom Touch Joystick (CanvasLayer/Joystick/joytop) gesetzt
var touch_dir=Vector2(0,0)
var touch_active=false

#Auf Handy/Tablet wird mit dem Joystick gezielt, sonst mit der Maus
var touch_ui=false

#Zuletzt an die anderen Peers geschickte Animationen
var body_state=''
var feet_state=''

#Kollisionswerte aus der Szene, zum Wiederherstellen beim Respawn
var col_layer=2
var col_mask=3

#Solange das Teammenue offen ist nimmt der Spieler keine Eingaben an
var menu_open=false

remote var pla=false
remote var rrot=0
remote var rpos=Vector2(0,0)

func _ready():
	touch_ui=OS.has_touchscreen_ui_hint()
	col_layer=collision_layer
	col_mask=collision_mask
	#Alle Spieler teilen sich die Frames aus dem weapons-Singleton
	$body.frames=weapons.body_frames
	$body.animation=weapon+'-idle'
	reset_loadout()

func reset_loadout():
	owned={}
	for w in weapons.ORDER:
		mag[w]=weapons.DATA[w]['mag']
		owned[w]=weapons.FREE.has(w)
	armor=0
	weapon='handgun'

func delrest():
	if get_name()!=str(get_tree().get_network_unique_id()):
		$CanvasLayer.queue_free()
		$Camera2D.queue_free()
		$showmask.queue_free()
	else:
		#Jede Spielerszene bringt current=true mit, der zuletzt gespawnte
		#Spieler gewinnt sonst die Kamera und nimmt sie beim Aufraeumen mit
		$Camera2D.make_current()
		if !touch_ui:
			$CanvasLayer/Joystick.hide()
			$CanvasLayer/fire.hide()
			$CanvasLayer/reload.hide()
	set_network_master(int(get_name()))
	team=multiplayer.team_of(int(get_name()))
	$Name.text=multiplayer.players[int(get_name())]
	$Name.add_color_override('font_color',multiplayer.TEAM_COLORS[team])

func _process(delta):
	if is_network_master():
		$CanvasLayer/hp.value=health
		$CanvasLayer/hp_value.text=str(max(0,health))
		$CanvasLayer/armor_value.text=str(armor)
		$CanvasLayer/money.text='$'+str(multiplayer.money_of(int(get_name())))
		$CanvasLayer/bullets.text=ammo_text()
		$CanvasLayer/crosshair.visible=settings.crosshair and alive and !menu_open
		$CanvasLayer/fps.visible=settings.show_fps
		if settings.show_fps:
			$CanvasLayer/fps.text=str(Engine.get_frames_per_second())+' FPS'
		if alive and health<=0:
			rpc('die')

func ammo_text():
	if weapons.is_melee(weapon):
		return weapon.to_upper()
	return weapon.to_upper()+'  '+str(mag[weapon])+'/'+str(weapons.DATA[weapon]['mag'])

#Blickrichtung: Maus am Desktop, Joystick am Touchgeraet
func aim():
	if menu_open:
		return
	if touch_ui:
		if touch_active:
			rotation=touch_dir.angle()
	else:
		rotation=(get_global_mouse_position()-global_position).angle()

#WASD, faellt auf den Joystick zurueck solange keine Taste gedrueckt ist
func input_direction():
	if menu_open or frozen:
		return Vector2(0,0)
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
		if !alive:
			return
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

		handle_weapon_switch()
		handle_attack()
		handle_reload()

		rpos=position
		rrot=rotation
		rset('rpos',rpos)
		rset('rrot',rrot)

	else:
		rotation=rrot
		position=rpos

func handle_weapon_switch():
	if pla or menu_open:
		return
	for w in weapons.ORDER:
		if w!=weapon and owns(w) and Input.is_action_just_pressed(weapons.slot_action(w)):
			rpc('set_weapon',w)
			return

func handle_attack():
	if pla or menu_open or frozen:
		return
	var d=weapons.DATA[weapon]
	var pressed=false
	if d['auto']:
		pressed=Input.is_action_pressed('fire')
	else:
		pressed=Input.is_action_just_pressed('fire')
	if !pressed:
		return
	if weapons.is_melee(weapon):
		pla=true
		animate_body(weapon+'-meleeattack',true)
		rpc('melee',d['damage'],d['range'],d['kill_reward'])
	elif mag[weapon]>0:
		mag[weapon]-=1
		pla=true
		animate_body(weapon+'-shoot',true)
		var spreads=[]
		for i in range(d['pellets']):
			spreads.append(rand_range(-d['spread'],d['spread']))
		rpc('fire',spreads,d['damage'])

func handle_reload():
	if pla or menu_open or frozen or weapons.is_melee(weapon):
		return
	if !Input.is_action_just_pressed('reload'):
		return
	if mag[weapon]>=weapons.DATA[weapon]['mag']:
		return
	reloading=true
	pla=true
	animate_body(weapon+'-reload',true)

func owns(w):
	return owned.has(w) and owned[w]

#Einziger Weg, wie Leben verloren geht. Panzerung schluckt die Haelfte,
#bis sie aufgebraucht ist
func take_damage(dmg,from_id=0,reward=0):
	if !alive:
		return
	if from_id!=0:
		last_hit_by=from_id
		last_reward=reward
	if armor>0:
		var to_armor=int(dmg*0.5)
		if to_armor>armor:
			to_armor=armor
		armor-=to_armor
		dmg-=to_armor
	health-=dmg

sync func set_weapon(w):
	#Laedt die Frames auch bei den anderen Peers, die spielen die Animation ab
	weapons.build(w)
	weapon=w
	reloading=false
	pla=false
	body_state=''

sync func fire(spreads,damage):
	for s in spreads:
		var a=rotation+s
		var bul=multiplayer.bullet.instance()
		get_parent().add_child(bul)
		bul.damage=damage
		bul.team=team
		bul.shooter=int(get_name())
		bul.reward=weapons.DATA[weapon]['kill_reward']
		bul.global_rotation=a
		bul.global_position=$firepoint.global_position
		bul.apply_impulse(Vector2(0,0),Vector2(cos(a),sin(a))*2000)

sync func melee(damage,rng,reward):
	var facing=Vector2(cos(rotation),sin(rotation))
	for p in get_tree().get_nodes_in_group('player'):
		if p==self or !p.alive or p.team==team:
			continue
		var to=p.global_position-global_position
		if to.length()<=rng and facing.dot(to.normalized())>0.7:
			p.take_damage(damage,int(get_name()),reward)

sync func die():
	if !alive:
		return
	alive=false
	#Kills verguetet der Server, jeder Peer rechnet Schaden fuer sich
	if get_tree().is_network_server() and get_parent().has_method('award_kill'):
		get_parent().award_kill(last_hit_by,last_reward)
	$body.hide()
	$feet.hide()
	$Name.hide()
	#Die Leiche soll niemanden mehr blockieren und keine Kugeln fangen
	set_collision_layer(0)
	set_collision_mask(0)

sync func respawn(pos):
	alive=true
	health=100
	#Ein Teamwechsel aus dem M-Menue wird erst hier wirksam
	team=multiplayer.team_of(int(get_name()))
	$Name.add_color_override('font_color',multiplayer.TEAM_COLORS[team])
	reloading=false
	pla=false
	last_hit_by=0
	last_reward=0
	reset_loadout()
	set_collision_layer(col_layer)
	set_collision_mask(col_mask)
	position=pos
	rpos=pos
	body_state=''
	feet_state=''
	$body.show()
	$feet.show()
	$Name.show()
	$body.play(weapon+'-idle')
	$feet.play('idle')

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
	var a=$body.animation
	if a==weapon+'-shoot' or a==weapon+'-reload' or a==weapon+'-meleeattack':
		pla=false
		if reloading and a==weapon+'-reload':
			mag[weapon]=weapons.DATA[weapon]['mag']
		reloading=false
