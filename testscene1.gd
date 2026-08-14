extends Node2D

const RESTART_DELAY=4.0

var round_active=false
var restart_in=0.0

func _ready():
	spawn_all()
	update_score()

#Reihenfolge muss auf allen Peers gleich sein, sonst stehen die Spieler
#anderswo als beim Nachbarn
func player_ids():
	var ids=[]
	for x in multiplayer.players:
		ids.append(x)
	ids.sort()
	return ids

func spawn_point(t,i):
	var group='spawns T'
	if t==multiplayer.TEAM_CT:
		group='spawns CT'
	var pts=get_node(group).get_children()
	return pts[i%pts.size()].global_position

func spawn_all():
	var used=[0,0]
	for x in player_ids():
		var t=multiplayer.team_of(x)
		var pli=load("res://player.tscn").instance()
		add_child(pli)
		pli.set_name(str(x))
		pli.global_position=spawn_point(t,used[t])
		used[t]+=1
		if x == get_tree().get_network_unique_id():
			pli.set_network_master(get_tree().get_network_unique_id())
	for x in player_ids():
		get_node(str(x)).delrest()
	round_active=both_teams_manned()

#Mit nur einem besetzten Team gibt es nichts zu gewinnen, sonst waere die
#Runde sofort vorbei
func both_teams_manned():
	return multiplayer.team_count(multiplayer.TEAM_T)>0 and multiplayer.team_count(multiplayer.TEAM_CT)>0

func update_score():
	$CanvasLayer/score.text=str(multiplayer.score[0])+'  :  '+str(multiplayer.score[1])

func local_player():
	return get_node_or_null(str(get_tree().get_network_unique_id()))

func toggle_teammenu():
	var menu=$menulayer/teammenu
	menu.visible=!menu.visible
	if menu.visible:
		var t=multiplayer.team_of(get_tree().get_network_unique_id())
		menu.get_node("current").text='Currently: '+multiplayer.TEAM_NAMES[t]
	#Solange das Menue offen ist wird nicht gezielt, geschossen oder gelaufen
	var p=local_player()
	if p!=null:
		p.menu_open=menu.visible
		#Der Light2D im Mask-Modus rendert nach allen CanvasLayern, ohne das
		#hier laegen die Spieler-Sprites vor dem Menue
		var sm=p.get_node_or_null("showmask")
		if sm!=null:
			sm.visible=!menu.visible

func pick_team(t):
	var id=get_tree().get_network_unique_id()
	if get_tree().is_network_server():
		multiplayer.request_team(id,t)
	else:
		multiplayer.rpc_id(1,"request_team",id,t)
	toggle_teammenu()

func _on_pick_t_pressed():
	pick_team(multiplayer.TEAM_T)

func _on_pick_ct_pressed():
	pick_team(multiplayer.TEAM_CT)

func _process(delta):
	if Input.is_action_just_pressed('teammenu'):
		toggle_teammenu()

	if restart_in>0:
		restart_in-=delta
		if restart_in<=0 and get_tree().is_network_server():
			rpc('start_round',multiplayer.teams)
		return
	if !round_active or !get_tree().is_network_server():
		return

	var alive=[0,0]
	for p in get_tree().get_nodes_in_group('player'):
		if p.alive:
			alive[p.team]+=1
	if alive[0]>0 and alive[1]>0:
		return

	var winner=-1
	if alive[0]>0:
		winner=multiplayer.TEAM_T
	elif alive[1]>0:
		winner=multiplayer.TEAM_CT
	rpc('end_round',winner)

sync func end_round(winner):
	round_active=false
	restart_in=RESTART_DELAY
	if winner>=0:
		multiplayer.score[winner]+=1
		$CanvasLayer/won.text=multiplayer.TEAM_NAMES[winner]+' WINS THE ROUND'
	else:
		$CanvasLayer/won.text='DRAW'
	$CanvasLayer/won.show()
	$CanvasLayer/bannerbar.show()
	update_score()

#Der Server schickt die Teamzuordnung mit, sonst verteilt ein Peer mit
#veralteter Liste die Spieler auf andere Basen als der Rest
sync func start_round(teams):
	multiplayer.teams=teams
	restart_in=0
	$CanvasLayer/won.hide()
	$CanvasLayer/bannerbar.hide()
	var used=[0,0]
	for x in player_ids():
		var p=get_node_or_null(str(x))
		if p==null:
			continue
		var t=multiplayer.team_of(x)
		p.respawn(spawn_point(t,used[t]))
		used[t]+=1
	round_active=both_teams_manned()

func _on_play_pressed():
	rpc('start_round',multiplayer.teams)
