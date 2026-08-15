extends Node

#Waffendaten. Die Feuerrate steckt in der Abspielgeschwindigkeit der
#shoot-Animation, dadurch passen Bild und Takt immer zusammen.
#mag < 0 heisst Nahkampf ohne Munition.
const DATA={
	'handgun':{
		'slot':1,'mag':12,'damage':25,'auto':false,'pellets':1,'spread':0.006,
		'shoot_speed':7.0,'range':0.0,'kill_reward':300,
		'recoil':0.030,'recover':0.95,'move_penalty':0.10,'max_spread':0.16,
		'armor_pen':0.25,'move_speed':1.0,
		'falloff_start':700.0,'falloff_end':2200.0,'falloff_min':0.55,
		'pattern':[0.0,0.010,-0.008,0.013,-0.011,0.015],
		'frames':{'idle':20,'move':20,'shoot':3,'reload':15,'meleeattack':15}
	},
	'rifle':{
		'slot':2,'mag':30,'damage':22,'auto':true,'pellets':1,'spread':0.004,
		'shoot_speed':24.0,'range':0.0,'kill_reward':300,
		'recoil':0.020,'recover':1.30,'move_penalty':0.14,'max_spread':0.20,
		'armor_pen':0.70,'move_speed':0.92,
		'falloff_start':1400.0,'falloff_end':3600.0,'falloff_min':0.65,
		'pattern':[0.0,0.012,0.026,0.040,0.050,0.044,0.020,-0.010,-0.036,-0.050,-0.030,0.004,0.028,0.046,0.050],
		'frames':{'idle':20,'move':20,'shoot':3,'reload':20,'meleeattack':15}
	},
	'shotgun':{
		'slot':3,'mag':8,'damage':13,'auto':false,'pellets':6,'spread':0.2,
		'shoot_speed':4.0,'range':0.0,'kill_reward':900,
		'recoil':0.050,'recover':1.10,'move_penalty':0.08,'max_spread':0.34,
		'armor_pen':0.30,'move_speed':0.87,
		'falloff_start':400.0,'falloff_end':1400.0,'falloff_min':0.2,
		'pattern':[0.0,0.030,-0.024,0.036],
		'frames':{'idle':20,'move':20,'shoot':3,'reload':20,'meleeattack':15}
	},
	'knife':{
		'slot':4,'mag':-1,'damage':55,'auto':false,'pellets':0,'spread':0.0,
		'shoot_speed':0.0,'range':190.0,'kill_reward':1500,
		'recoil':0.0,'recover':1.0,'move_penalty':0.0,'max_spread':0.0,
		'armor_pen':0.85,'move_speed':1.05,
		'falloff_start':0.0,'falloff_end':1.0,'falloff_min':1.0,
		'pattern':[],
		'frames':{'idle':20,'move':20,'meleeattack':15}
	}
}

const ORDER=['handgun','rifle','shotgun','knife']

#Pistole und Messer hat jeder, der Rest wird gekauft
const FREE=['handgun','knife']

#Reihenfolge bestimmt die Zeilen im Kaufmenue
const SHOP=[
	{'id':'rifle','label':'RIFLE','cost':2700},
	{'id':'shotgun','label':'SHOTGUN','cost':1200},
	{'id':'kevlar','label':'KEVLAR VEST','cost':650}
]

const ARMOR_FULL=100

func shop_entry(id):
	for e in SHOP:
		if e['id']==id:
			return e
	return null

#Alle Spieler teilen sich eine SpriteFrames. Bei 420 Einzelbildern zu je
#253x216 waeren sonst rund 90 MB Texturen gleichzeitig offen, deshalb wird
#pro Waffe erst beim ersten Einsatz geladen.
var body_frames
var built={}

func _ready():
	body_frames=SpriteFrames.new()
	if body_frames.has_animation('default'):
		body_frames.remove_animation('default')
	build('handgun')

func is_melee(w):
	return DATA[w]['mag']<0

func slot_action(w):
	return 'weapon_'+str(DATA[w]['slot'])

func build(w):
	if built.has(w):
		return
	built[w]=true
	var f=DATA[w]['frames']
	for action in f:
		var anim=w+'-'+action
		body_frames.add_animation(anim)
		if action=='shoot':
			body_frames.set_animation_speed(anim,DATA[w]['shoot_speed'])
		else:
			body_frames.set_animation_speed(anim,12.0)
		body_frames.set_animation_loop(anim,action=='idle' or action=='move')
		for i in range(f[action]):
			var p='res://Top_Down_Survivor/%s/%s/survivor-%s_%s_%d.png'%[w,action,action,w,i]
			body_frames.add_frame(anim,load(p))
