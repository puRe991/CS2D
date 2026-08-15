extends Control

#Kartengrenzen in Weltkoordinaten, wird von testscene1 gesetzt
var wmin=Vector2(0,0)
var wsize=Vector2(1,1)

#Gegner tauchen nur auf, wenn der lokale Spieler sie tatsaechlich sieht.
#Das Radar ist damit kein Wallhack, sondern gibt weiter was man selbst hat
const SIGHT_RANGE=2400.0
const SIGHT_DOT=0.35

const BG=Color(0.02,0.03,0.04,0.72)
const FRAME=Color(0.55,0.82,0.29,0.75)

#Kartenbild als Untergrund, damit man Struktur statt eines schwarzen
#Kastens sieht
var map_tex=null
var map_min=Vector2(0,0)
var map_max=Vector2(1,1)

func setup(mn,mx):
	wmin=mn
	wsize=mx-mn
	if wsize.x<1.0:
		wsize.x=1.0
	if wsize.y<1.0:
		wsize.y=1.0

func set_map(tex,mn,mx):
	map_tex=tex
	map_min=mn
	map_max=mx

func _process(delta):
	update()

func to_radar(p,size):
	var rel=(p-wmin)/wsize
	return Vector2(rel.x*size.x,rel.y*size.y)

func local_player():
	var id=str(get_tree().get_network_unique_id())
	for p in get_tree().get_nodes_in_group('player'):
		if p.get_name()==id:
			return p
	return null

func spotted(me,other):
	var to=other.global_position-me.global_position
	if to.length()>SIGHT_RANGE:
		return false
	return Vector2(cos(me.rotation),sin(me.rotation)).dot(to.normalized())>SIGHT_DOT

func _draw():
	var size=get_rect().size
	draw_rect(Rect2(Vector2(0,0),size),BG)
	if map_tex!=null:
		var a=to_radar(map_min,size)
		var b=to_radar(map_max,size)
		draw_texture_rect(map_tex,Rect2(a,b-a),false,Color(0.62,0.68,0.72,0.85))
	draw_line(Vector2(0,0),Vector2(size.x,0),FRAME,1.0)
	draw_line(Vector2(size.x,0),size,FRAME,1.0)
	draw_line(size,Vector2(0,size.y),FRAME,1.0)
	draw_line(Vector2(0,size.y),Vector2(0,0),FRAME,1.0)

	var me=local_player()
	if me==null:
		return

	for p in get_tree().get_nodes_in_group('player'):
		if !p.alive:
			continue
		var mate=(p.team==me.team)
		if !mate and !spotted(me,p):
			continue
		var at=to_radar(p.global_position,size)
		if at.x<0 or at.y<0 or at.x>size.x or at.y>size.y:
			continue
		if p==me:
			#Eigene Position mit Blickrichtung
			draw_circle(at,4.0,Color(0.95,0.97,1,1))
			var tip=at+Vector2(cos(me.rotation),sin(me.rotation))*11.0
			draw_line(at,tip,Color(0.95,0.97,1,0.9),2.0)
		elif mate:
			draw_circle(at,3.0,multiplayer.TEAM_COLORS[p.team])
		else:
			draw_circle(at,3.5,Color(0.93,0.32,0.28,1))
