extends KinematicBody2D

#Geschwindigkeiten in Pixel pro Sekunde
export var speed_walk=260
export var speed_run=660
export var health = 100

var weapon='handgun'
var mag={}
var owned={}
var nades={}
var armor=0

#Blendung durch eine Flashbang, laeuft nur lokal ab
var blind_left=0.0
var blind_total=1.0
var alive=true
var team=0
var reloading=false

#Waehrend der Freeze Time am Rundenanfang darf gezielt und gekauft, aber
#nicht gelaufen oder geschossen werden
var frozen=false

#Wer zuletzt getroffen hat, damit der Server den Kill verguetet
var last_hit_by=0
var last_reward=0
var last_weapon=''
#Wer in diesem Leben wie viel Schaden gemacht hat, fuer Assists
var damagers={}

#Bewegung mit Traegheit. Gegensteuern bremst haerter als Loslassen, das ist
#der 2D-Gegenwert zum Counter-Strafing
const ACCEL=6000.0
const FRICTION=4500.0
const COUNTER_ACCEL=11000.0
var velocity=Vector2(0,0)

#Streuung waechst mit jedem Schuss und faellt in der Feuerpause zurueck
var inaccuracy=0.0
var shot_index=0
var since_shot=9.0

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
	nades={}
	for g in weapons.GRENADE_ORDER:
		nades[g]=0
	armor=0
	blind_left=0.0
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
		$CanvasLayer/nades.text=nade_text()
		var f=$CanvasLayer/flash
		if blind_left>0.0:
			f.show()
			f.color=Color(1,1,1,blind_left/blind_total)
		else:
			f.hide()
		$CanvasLayer/crosshair.visible=settings.crosshair and alive and !menu_open
		if $CanvasLayer/crosshair.visible:
			update_crosshair()
		$CanvasLayer/fps.visible=settings.show_fps
		if settings.show_fps:
			$CanvasLayer/fps.text=str(Engine.get_frames_per_second())+' FPS'
		if alive and health<=0:
			rpc('die')

func nade_text():
	var out=''
	for g in weapons.GRENADE_ORDER:
		if nades.has(g) and nades[g]>0:
			out+=g.to_upper()+' '+str(nades[g])+'   '
	return out

sync func blind(seconds):
	if seconds<=0.05:
		return
	if seconds>blind_left:
		blind_left=seconds
		blind_total=seconds

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
		var top=speed_run
		if walking:
			top=speed_walk
		top*=weapons.DATA[weapon]['move_speed']
		apply_movement(direction,top,delta)
		recover_accuracy(delta)

		#Animationen folgen der tatsaechlichen Geschwindigkeit, nicht der
		#Taste, sonst sieht man das Ausgleiten nicht
		if velocity.length()<40:
			animate_feet('idle')
		else:
			#Laufrichtung relativ zur Blickrichtung, x=vorwaerts y=rechts
			var local=velocity.rotated(-rotation)
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
			if velocity.length()<40:
				animate_body(weapon+'-idle')
			else:
				animate_body(weapon+'-move')

		if blind_left>0.0:
			blind_left-=delta
			if blind_left<0.0:
				blind_left=0.0

		handle_weapon_switch()
		handle_attack()
		handle_reload()
		handle_grenades()

		rpos=position
		rrot=rotation
		rset('rpos',rpos)
		rset('rrot',rrot)

	else:
		rotation=rrot
		position=rpos

#Das Fadenkreuz geht auf, wenn die Streuung waechst. Damit sieht man beim
#Laufen und im Dauerfeuer sofort, wie ungenau man gerade ist
func update_crosshair():
	var gap=5.0+current_spread()*220.0
	var ch=$CanvasLayer/crosshair
	ch.get_node("up").margin_top=-(gap+10.0)
	ch.get_node("up").margin_bottom=-gap
	ch.get_node("down").margin_top=gap
	ch.get_node("down").margin_bottom=gap+10.0
	ch.get_node("left").margin_left=-(gap+10.0)
	ch.get_node("left").margin_right=-gap
	ch.get_node("right").margin_left=gap
	ch.get_node("right").margin_right=gap+10.0

func apply_movement(wish,top,delta):
	var target=wish*top
	var accel=ACCEL
	if wish==Vector2(0,0):
		accel=FRICTION
	elif velocity.length()>1 and wish.dot(velocity.normalized())<0:
		accel=COUNTER_ACCEL
	var diff=target-velocity
	var step=accel*delta
	if diff.length()<=step:
		velocity=target
	else:
		velocity+=diff.normalized()*step
	velocity=move_and_slide(velocity)

func recover_accuracy(delta):
	var d=weapons.DATA[weapon]
	since_shot+=delta
	if inaccuracy>0:
		inaccuracy-=d['recover']*delta
		if inaccuracy<0:
			inaccuracy=0
	#Nach einer Feuerpause faengt das Spraymuster von vorn an
	if since_shot>0.35:
		shot_index=0

#Stillstehen und der erste Schuss sind praezise, Laufen und Dauerfeuer nicht
func current_spread():
	var d=weapons.DATA[weapon]
	var frac=velocity.length()/speed_run
	if frac>1.0:
		frac=1.0
	var sp=d['spread']+inaccuracy+d['move_penalty']*frac
	if sp>d['max_spread'] and d['max_spread']>0:
		sp=d['max_spread']
	return sp

#Das Spraymuster ist fest, der Spieler kann es lernen und ausgleichen
func pattern_offset():
	var pat=weapons.DATA[weapon]['pattern']
	if pat.empty():
		return 0.0
	var i=shot_index
	if i>=pat.size():
		i=pat.size()-1
	return pat[i]

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
		var sp=current_spread()
		var kick=pattern_offset()
		var spreads=[]
		for i in range(d['pellets']):
			spreads.append(kick+rand_range(-sp,sp))
		inaccuracy+=d['recoil']
		shot_index+=1
		since_shot=0.0
		rpc('fire',spreads,d['damage'])

#Granaten wechseln die Waffe nicht, sie fliegen auf Tastendruck
func handle_grenades():
	if pla or menu_open or frozen:
		return
	for g in weapons.GRENADE_ORDER:
		if nades.has(g) and nades[g]>0 and Input.is_action_just_pressed(weapons.GRENADES[g]['key']):
			nades[g]-=1
			rpc('throw_nade',g,rotation)
			return

sync func throw_nade(kind,angle):
	var n=load("res://grenade.tscn").instance()
	get_parent().add_child(n)
	n.global_position=$firepoint.global_position
	n.setup(kind,team,int(get_name()),Vector2(cos(angle),sin(angle))*1250.0)

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
func take_damage(dmg,from_id=0,reward=0,armor_pen=0.0,wname=''):
	if !alive:
		return
	if from_id!=0:
		last_hit_by=from_id
		last_reward=reward
		last_weapon=wname
		if damagers.has(from_id):
			damagers[from_id]+=dmg
		else:
			damagers[from_id]=dmg
	if armor>0:
		#Halber Schaden geht in die Weste, Durchschlag verkleinert den Anteil
		var to_armor=int(dmg*0.5*(1.0-armor_pen))
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
	inaccuracy=0.0
	shot_index=0
	body_state=''

sync func fire(spreads,damage):
	var d=weapons.DATA[weapon]
	for s in spreads:
		var a=rotation+s
		var bul=multiplayer.bullet.instance()
		get_parent().add_child(bul)
		bul.damage=damage
		bul.team=team
		bul.shooter=int(get_name())
		bul.reward=d['kill_reward']
		bul.armor_pen=d['armor_pen']
		bul.wname=weapon
		bul.falloff_start=d['falloff_start']
		bul.falloff_end=d['falloff_end']
		bul.falloff_min=d['falloff_min']
		bul.origin=$firepoint.global_position
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
			p.take_damage(damage,int(get_name()),reward,weapons.DATA[weapon]['armor_pen'],weapon)

sync func die():
	if !alive:
		return
	alive=false
	#Der Server wertet den Tod aus und meldet ihn allen Peers
	if get_tree().is_network_server() and get_parent().has_method('register_death'):
		get_parent().register_death(int(get_name()))
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
	last_weapon=''
	damagers={}
	blind_left=0.0
	velocity=Vector2(0,0)
	inaccuracy=0.0
	shot_index=0
	since_shot=9.0
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
