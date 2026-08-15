extends Node

#Waffendaten. Die Feuerrate steckt in der Abspielgeschwindigkeit der
#shoot-Animation, dadurch passen Bild und Takt immer zusammen.
#mag < 0 heisst Nahkampf ohne Munition.
const DATA={
	'handgun':{
		'slot':1,'mag':12,'damage':25,'auto':false,'pellets':1,'spread':0.0,
		'shoot_speed':7.0,'range':0.0,'kill_reward':300,
		'frames':{'idle':20,'move':20,'shoot':3,'reload':15,'meleeattack':15}
	},
	'rifle':{
		'slot':2,'mag':30,'damage':22,'auto':true,'pellets':1,'spread':0.03,
		'shoot_speed':24.0,'range':0.0,'kill_reward':300,
		'frames':{'idle':20,'move':20,'shoot':3,'reload':20,'meleeattack':15}
	},
	'shotgun':{
		'slot':3,'mag':8,'damage':13,'auto':false,'pellets':6,'spread':0.2,
		'shoot_speed':4.0,'range':0.0,'kill_reward':900,
		'frames':{'idle':20,'move':20,'shoot':3,'reload':20,'meleeattack':15}
	},
	'knife':{
		'slot':4,'mag':-1,'damage':55,'auto':false,'pellets':0,'spread':0.0,
		'shoot_speed':0.0,'range':190.0,'kill_reward':1500,
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
