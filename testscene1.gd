extends Node2D

#CS2 Wettkampf: 1:55 Rundenzeit, 30 Runden, wer zuerst 16 hat gewinnt,
#Seitenwechsel nach Runde 15
const ROUND_END_DELAY=7.0
const FREEZE_TIME=10.0
const ROUND_TIME=115.0
const MAX_ROUNDS=30
const ROUNDS_TO_WIN=16
const HALFTIME_ROUND=15
const PLANT_REWARD=300
const DEFUSE_REWARD=300

var round_active=false
var restart_in=0.0
var freeze_in=0.0
var round_left=0.0
var round_no=1
var match_over=false

#Nur auf dem Server, steuert den Verlustbonus
var loss_streak=[0,0]

var feed=[]
var scoreboard_open=false

#Bombe
var bomb=null
var bomb_planted=false
var plant_bonus_paid=false

func _ready():
	if get_tree().is_network_server():
		multiplayer.reset_money()
	multiplayer.reset_stats()
	spawn_all()
	update_score()
	build_buymenu()
	setup_radar()
	reset_bomb()
	begin_freeze()

#Das Radar bekommt die Kartengrenzen aus der Wand-Tilemap
func setup_radar():
	var up=get_node("up")
	var cells=up.get_used_rect()
	var cs=up.cell_size*up.scale
	var origin=up.position
	var mn=origin+Vector2(cells.position.x*cs.x,cells.position.y*cs.y)
	var mx=origin+Vector2((cells.position.x+cells.size.x)*cs.x,(cells.position.y+cells.size.y)*cs.y)
	$CanvasLayer/radar.setup(mn,mx)
	var mapnode=get_node("map")
	var half=mapnode.texture.get_size()*mapnode.scale*0.5
	$CanvasLayer/radar.set_map(mapnode.texture,mapnode.position-half,mapnode.position+half)

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

#Rauch zwischen zwei Punkten? Wird vom Radar und der Sichtbarkeit genutzt
func sight_blocked(a,b):
	for c in get_tree().get_nodes_in_group('smoke'):
		if c.blocks(a,b):
			return true
	return false

#Gegner im Rauch verschwinden lokal aus dem Bild
func update_sight():
	var me=local_player()
	if me==null:
		return
	for p in get_tree().get_nodes_in_group('player'):
		if p==me or !p.alive:
			continue
		var hidden=(p.team!=me.team) and sight_blocked(me.global_position,p.global_position)
		p.get_node("body").visible=!hidden
		p.get_node("feet").visible=!hidden
		p.get_node("Name").visible=!hidden

func local_player():
	return get_node_or_null(str(get_tree().get_network_unique_id()))

# --- Freeze Time -------------------------------------------------------

func site_positions():
	var out=[]
	for c in get_node("bombsites").get_children():
		out.append(c.global_position)
	return out

func in_bombsite(pos):
	for sp in site_positions():
		if pos.distance_to(sp)<=bomb.SITE_RADIUS:
			return true
	return false

#Ein T bekommt die Bombe, die Reihenfolge ist auf allen Peers gleich
func reset_bomb():
	bomb_planted=false
	plant_bonus_paid=false
	if bomb==null:
		bomb=load("res://bomb.tscn").instance()
		add_child(bomb)
	bomb.state=bomb.DROPPED
	bomb.carrier=0
	bomb.timer=0.0
	for x in player_ids():
		if multiplayer.team_of(x)==multiplayer.TEAM_T:
			bomb.give_to(x)
			var p=get_node_or_null(str(x))
			if p!=null:
				bomb.global_position=p.global_position
			return
	#Ohne T liegt sie auf dem ersten Spawnpunkt
	bomb.global_position=spawn_point(multiplayer.TEAM_T,0)

func begin_freeze():
	freeze_in=FREEZE_TIME
	round_left=ROUND_TIME
	set_frozen(true)
	$CanvasLayer/freeze.show()
	update_timer_hud()

func set_frozen(on):
	for p in get_tree().get_nodes_in_group('player'):
		p.frozen=on

func update_timer_hud():
	var l=$CanvasLayer/freeze
	if match_over:
		l.hide()
		return
	l.show()
	if freeze_in>0:
		var left=int(ceil(freeze_in))
		if left<0:
			left=0
		l.text='ROUND '+str(round_no)+'/'+str(MAX_ROUNDS)+'   ·   STARTS IN '+str(left)+'   ·   [B] BUY'
	elif round_active:
		var t=int(ceil(round_left))
		if t<0:
			t=0
		l.text='ROUND '+str(round_no)+'/'+str(MAX_ROUNDS)+'   ·   '+str(t/60)+':'+('%02d'%(t%60))
	else:
		l.hide()

#Der Server gibt den Start frei, sonst laeuft ein Peer mit schneller Uhr los
sync func end_freeze():
	freeze_in=0
	set_frozen(false)
	update_timer_hud()
	if $menulayer/buymenu.visible:
		toggle_buymenu()

# --- Teammenue ---------------------------------------------------------

func toggle_teammenu():
	var menu=$menulayer/teammenu
	menu.visible=!menu.visible
	if menu.visible:
		var t=multiplayer.team_of(get_tree().get_network_unique_id())
		menu.get_node("current").text='Currently: '+multiplayer.TEAM_NAMES[t]
	sync_menu_block()

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

# --- Kaufmenue ---------------------------------------------------------

#Zeilen werden erzeugt, damit neue Artikel im Shop nicht jedes Mal auch
#noch Knoten in der Szene brauchen
var buy_rows=[]

func flat(bg,border):
	var sb=StyleBoxFlat.new()
	sb.bg_color=bg
	sb.border_width_left=1
	sb.border_width_top=1
	sb.border_width_right=1
	sb.border_width_bottom=1
	sb.border_color=border
	return sb

func build_buymenu():
	var list=$menulayer/buymenu/list
	for c in list.get_children():
		list.remove_child(c)
		c.free()
	buy_rows=[]
	for i in range(weapons.SHOP.size()):
		var e=weapons.SHOP[i]
		var row=HBoxContainer.new()
		row.rect_min_size=Vector2(0,40)
		list.add_child(row)

		var nm=Label.new()
		nm.text=e['label']
		nm.rect_min_size=Vector2(240,0)
		nm.add_color_override('font_color',Color(0.88,0.9,0.93))
		row.add_child(nm)

		var pr=Label.new()
		pr.text='$'+str(e['cost'])
		pr.rect_min_size=Vector2(90,0)
		pr.add_color_override('font_color',Color(0.87,0.62,0.15))
		row.add_child(pr)

		var b=Button.new()
		b.text='BUY'
		b.rect_min_size=Vector2(136,34)
		b.add_stylebox_override('normal',flat(Color(0.16,0.13,0.07),Color(0.87,0.62,0.15)))
		b.add_stylebox_override('hover',flat(Color(0.87,0.62,0.15),Color(0.96,0.71,0.23)))
		b.add_stylebox_override('pressed',flat(Color(0.87,0.62,0.15),Color(0.96,0.71,0.23)))
		b.add_stylebox_override('disabled',flat(Color(0.11,0.12,0.14),Color(0.22,0.25,0.29)))
		b.add_color_override('font_color',Color(0.87,0.62,0.15))
		b.add_color_override('font_color_hover',Color(0.06,0.07,0.09))
		b.add_color_override('font_color_pressed',Color(0.06,0.07,0.09))
		b.add_color_override('font_color_disabled',Color(0.4,0.45,0.52))
		b.connect('pressed',self,'buy',[i])
		row.add_child(b)
		buy_rows.append(b)

func toggle_buymenu():
	var menu=$menulayer/buymenu
	menu.visible=!menu.visible
	if menu.visible:
		refresh_buymenu()
	sync_menu_block()

#Ein offenes Menue sperrt Zielen, Laufen und Schiessen
func sync_menu_block():
	var open=$menulayer/teammenu.visible or $menulayer/buymenu.visible or $menulayer/scoreboard.visible
	var p=local_player()
	if p!=null:
		p.menu_open=open
		#Der Light2D im Mask-Modus rendert nach allen CanvasLayern, ohne das
		#laegen die Spieler-Sprites vor dem Menue
		var sm=p.get_node_or_null("showmask")
		if sm!=null:
			sm.visible=!open

func refresh_buymenu():
	var id=get_tree().get_network_unique_id()
	var p=local_player()
	var cash=multiplayer.money_of(id)
	$menulayer/buymenu/cash.text='$'+str(cash)
	for i in range(weapons.SHOP.size()):
		var e=weapons.SHOP[i]
		var b=buy_rows[i]
		var have=false
		if p!=null:
			if e['id']=='kevlar':
				have=p.armor>0
			elif e['id']=='defusekit':
				have=p.kit
			elif weapons.is_grenade(e['id']):
				have=p.nades[e['id']]>=weapons.GRENADES[e['id']]['max']
			else:
				have=p.owns(e['id'])
		if have:
			b.text='OWNED'
			b.disabled=true
		elif freeze_in<=0:
			b.text='BUY TIME OVER'
			b.disabled=true
		elif cash<e['cost']:
			b.text='NO CASH'
			b.disabled=true
		else:
			b.text='BUY'
			b.disabled=false

func buy(i):
	var id=get_tree().get_network_unique_id()
	if get_tree().is_network_server():
		request_buy(id,weapons.SHOP[i]['id'])
	else:
		rpc_id(1,'request_buy',id,weapons.SHOP[i]['id'])
	refresh_buymenu()

#Kaufen entscheidet der Server, der Client fragt nur an
remote func request_buy(id,item):
	if !get_tree().is_network_server():
		return
	if freeze_in<=0:
		return
	var e=weapons.shop_entry(item)
	if e==null:
		return
	if multiplayer.money_of(id)<e['cost']:
		return
	var buyer=get_node_or_null(str(id))
	if buyer!=null and weapons.is_grenade(item) and buyer.nades[item]>=weapons.GRENADES[item]['max']:
		return
	#Das Entschaerfungsset ist nur fuer die Verteidiger
	if item=='defusekit' and multiplayer.team_of(id)!=multiplayer.TEAM_CT:
		return
	multiplayer.award(id,-e['cost'])
	multiplayer.rset('money',multiplayer.money)
	rpc('grant',id,item)

sync func grant(id,item):
	var p=get_node_or_null(str(id))
	if p==null:
		return
	if item=='kevlar':
		p.armor=weapons.ARMOR_FULL
	elif item=='defusekit':
		p.kit=true
	elif weapons.is_grenade(item):
		p.nades[item]=p.nades[item]+1
	else:
		p.owned[item]=true
		p.set_weapon(item)
	if p==local_player() and $menulayer/buymenu.visible:
		refresh_buymenu()

# --- Bombe -------------------------------------------------------------

#Pflanzen und Entschaerfen laufen lokal als Fortschritt und werden erst beim
#Abschluss gemeldet
func handle_use(delta):
	var me=local_player()
	if me==null or bomb==null:
		return
	if !me.alive or me.frozen or me.menu_open or match_over:
		me.use_progress=0.0
		return
	var holding=Input.is_action_pressed('use')
	var t=multiplayer.team_of(get_tree().get_network_unique_id())

	if !bomb_planted and t==multiplayer.TEAM_T and bomb.state==bomb.CARRIED and bomb.carrier==int(me.get_name()):
		if holding and in_bombsite(me.global_position) and me.velocity.length()<40:
			me.use_total=bomb.PLANT_TIME
			me.use_progress+=delta
			if me.use_progress>=bomb.PLANT_TIME:
				me.use_progress=0.0
				rpc('plant',int(me.get_name()),me.global_position)
		else:
			me.use_progress=0.0
		return

	if bomb_planted and t==multiplayer.TEAM_CT:
		var span=bomb.DEFUSE_TIME
		if me.kit:
			span=bomb.DEFUSE_TIME_KIT
		if holding and bomb.can_reach(me) and me.velocity.length()<40:
			me.use_total=span
			me.use_progress+=delta
			if me.use_progress>=span:
				me.use_progress=0.0
				rpc('defuse',int(me.get_name()))
		else:
			me.use_progress=0.0
		return

	me.use_progress=0.0

sync func plant(id,pos):
	bomb_planted=true
	bomb.global_position=pos
	bomb.arm()
	$CanvasLayer/bombstate.show()
	if get_tree().is_network_server() and !plant_bonus_paid:
		plant_bonus_paid=true
		multiplayer.award(id,PLANT_REWARD)
		multiplayer.rset('money',multiplayer.money)

sync func defuse(id):
	if !bomb_planted:
		return
	bomb_planted=false
	bomb.state=bomb.DROPPED
	$CanvasLayer/bombstate.hide()
	if get_tree().is_network_server():
		multiplayer.award(id,DEFUSE_REWARD)
		multiplayer.rset('money',multiplayer.money)
		rpc('end_round',multiplayer.TEAM_CT)

func update_bomb_hud():
	var me=local_player()
	var bar=$CanvasLayer/usebar
	if me!=null and me.use_progress>0.0 and me.use_total>0.0:
		bar.show()
		bar.value=100.0*me.use_progress/me.use_total
	else:
		bar.hide()
	if bomb_planted and bomb!=null:
		$CanvasLayer/bombstate.text='BOMB PLANTED   '+str(int(ceil(bomb.timer)))
		$CanvasLayer/bombstate.show()
	else:
		$CanvasLayer/bombstate.hide()

# --- Runde -------------------------------------------------------------

func _process(delta):
	if Input.is_action_just_pressed('teammenu'):
		toggle_teammenu()
	if Input.is_action_just_pressed('buymenu'):
		toggle_buymenu()
	handle_scoreboard()
	age_killfeed(delta)
	update_sight()
	handle_use(delta)
	update_bomb_hud()
	if scoreboard_open:
		refresh_scoreboard()

	if freeze_in>0:
		freeze_in-=delta
		update_timer_hud()
		if freeze_in<=0 and get_tree().is_network_server():
			rpc('end_freeze')

	if restart_in>0:
		restart_in-=delta
		if restart_in<=0 and get_tree().is_network_server():
			next_round()
		return
	if match_over or !round_active or freeze_in>0:
		return

	round_left-=delta
	update_timer_hud()
	if !get_tree().is_network_server():
		return

	#Nach dem Plant zaehlt nur noch die Bombenuhr
	if bomb_planted:
		if bomb.timer<=0.0:
			rpc('explode')
			return
	elif round_left<=0:
		#Zeit abgelaufen ohne Plant, die Verteidiger halten
		rpc('end_round',multiplayer.TEAM_CT)
		return

	var alive=[0,0]
	for p in get_tree().get_nodes_in_group('player'):
		if p.alive:
			alive[p.team]+=1
	if alive[0]>0 and alive[1]>0:
		return
	#Eine gelegte Bombe laeuft weiter, auch wenn kein T mehr steht
	if alive[0]==0 and bomb_planted:
		return

	var winner=-1
	if alive[0]>0:
		winner=multiplayer.TEAM_T
	elif alive[1]>0:
		winner=multiplayer.TEAM_CT
	rpc('end_round',winner)

sync func explode():
	bomb_planted=false
	if bomb!=null:
		bomb.state=bomb.DROPPED
	$CanvasLayer/bombstate.hide()
	end_round(multiplayer.TEAM_T)

sync func reset_stats():
	multiplayer.reset_stats()

sync func end_round(winner):
	round_active=false
	restart_in=ROUND_END_DELAY
	if winner>=0:
		multiplayer.score[winner]+=1
		$CanvasLayer/won.text=multiplayer.TEAM_NAMES[winner]+' WINS THE ROUND'
	else:
		$CanvasLayer/won.text='DRAW'
	$CanvasLayer/won.show()
	$CanvasLayer/bannerbar.show()
	update_score()
	update_timer_hud()
	#Geld verteilt der Server, danach geht die Liste an alle
	if get_tree().is_network_server():
		award_round(winner)
		multiplayer.rset('money',multiplayer.money)
	check_match_end()

#Geld nach CS2: Sieg pauschal, Niederlage steigend mit der Pechstraehne
func award_round(winner):
	for x in player_ids():
		if multiplayer.team_of(x)==winner:
			multiplayer.award(x,multiplayer.WIN_REWARD)
		else:
			var t=multiplayer.team_of(x)
			multiplayer.award(x,multiplayer.LOSS_BONUS[loss_streak[t]])
	if winner>=0:
		var loser=1-winner
		loss_streak[loser]=min(multiplayer.LOSS_BONUS.size()-1,loss_streak[loser]+1)
		loss_streak[winner]=max(0,loss_streak[winner]-1)

#Wer ausser dem Toeter am meisten Schaden gemacht hat, bekommt den Assist
func assist_for(p,killer):
	var best=0
	var who=0
	for id in p.damagers:
		if id==killer or id==0:
			continue
		if p.damagers[id]>=40 and p.damagers[id]>best:
			best=p.damagers[id]
			who=id
	return who

#Der Server wertet den Tod aus und meldet ihn an alle
func register_death(victim):
	if !get_tree().is_network_server():
		return
	var p=get_node_or_null(str(victim))
	if p==null:
		return
	var killer=p.last_hit_by
	if !multiplayer.players.has(killer):
		killer=0
	if killer!=0 and p.last_reward>0:
		multiplayer.award(killer,p.last_reward)
		multiplayer.rset('money',multiplayer.money)
	rpc('death_notice',victim,killer,assist_for(p,killer),p.last_weapon)

sync func death_notice(victim,killer,assist,wname):
	multiplayer.add_stat(victim,'deaths',1)
	if killer!=0:
		multiplayer.add_stat(killer,'kills',1)
	if assist!=0:
		multiplayer.add_stat(assist,'assists',1)
	push_killfeed(killer,victim,wname)

func player_name(id):
	if multiplayer.players.has(id):
		return multiplayer.players[id]
	return 'WORLD'

#Killfeed oben rechts, Eintraege verfallen von selbst
func push_killfeed(killer,victim,wname):
	var box=$CanvasLayer/killfeed
	var l=Label.new()
	var line=player_name(killer)
	if wname!='':
		line+='  ['+wname+']  '
	else:
		line+='  '
	line+=player_name(victim)
	l.text=line
	var col=Color(0.8,0.83,0.87)
	if killer!=0:
		col=multiplayer.TEAM_COLORS[multiplayer.team_of(killer)]
	l.add_color_override('font_color',col)
	l.add_color_override('font_color_shadow',Color(0,0,0,1))
	box.add_child(l)
	feed.append([l,6.0])
	while feed.size()>5:
		var old=feed[0]
		feed.remove(0)
		if is_instance_valid(old[0]):
			old[0].queue_free()

func age_killfeed(delta):
	var i=0
	while i<feed.size():
		feed[i][1]-=delta
		if feed[i][1]<=0:
			if is_instance_valid(feed[i][0]):
				feed[i][0].queue_free()
			feed.remove(i)
		else:
			i+=1

#Scoreboard auf TAB, wird nur beim Wechsel neu aufgebaut
func handle_scoreboard():
	var want=Input.is_action_pressed('scoreboard')
	if want==scoreboard_open:
		return
	scoreboard_open=want
	$menulayer/scoreboard.visible=want
	if want:
		refresh_scoreboard()
	sync_menu_block()

func score_cell(grid,text,col,width):
	var l=Label.new()
	l.text=text
	l.add_color_override('font_color',col)
	l.rect_min_size=Vector2(width,0)
	grid.add_child(l)

func refresh_scoreboard():
	var grid=$menulayer/scoreboard/grid
	for c in grid.get_children():
		grid.remove_child(c)
		c.free()
	var head=Color(0.45,0.51,0.57)
	score_cell(grid,'PLAYER',head,220)
	score_cell(grid,'K',head,50)
	score_cell(grid,'D',head,50)
	score_cell(grid,'A',head,50)
	score_cell(grid,'MONEY',head,90)
	for t in [multiplayer.TEAM_T,multiplayer.TEAM_CT]:
		for x in player_ids():
			if multiplayer.team_of(x)!=t:
				continue
			var col=multiplayer.TEAM_COLORS[t]
			var p=get_node_or_null(str(x))
			if p!=null and !p.alive:
				col=Color(col.r*0.45,col.g*0.45,col.b*0.45)
			var nm=multiplayer.players[x]
			if x==get_tree().get_network_unique_id():
				nm+='  (You)'
			score_cell(grid,nm,col,220)
			score_cell(grid,str(multiplayer.stat_of(x,'kills')),col,50)
			score_cell(grid,str(multiplayer.stat_of(x,'deaths')),col,50)
			score_cell(grid,str(multiplayer.stat_of(x,'assists')),col,50)
			score_cell(grid,'$'+str(multiplayer.money_of(x)),col,90)

func check_match_end():
	var a=multiplayer.score[0]
	var b=multiplayer.score[1]
	if a<ROUNDS_TO_WIN and b<ROUNDS_TO_WIN and round_no<MAX_ROUNDS:
		return
	match_over=true
	restart_in=0
	if a>b:
		$CanvasLayer/won.text='T WIN THE MATCH   '+str(a)+' : '+str(b)
	elif b>a:
		$CanvasLayer/won.text='CT WIN THE MATCH   '+str(b)+' : '+str(a)
	else:
		$CanvasLayer/won.text='MATCH DRAWN   '+str(a)+' : '+str(b)
	update_timer_hud()
	if get_tree().is_network_server():
		$CanvasLayer/play.show()

func swapped_teams():
	var t={}
	for x in multiplayer.teams:
		if multiplayer.teams[x]==multiplayer.TEAM_T:
			t[x]=multiplayer.TEAM_CT
		else:
			t[x]=multiplayer.TEAM_T
	return t

#Nur der Server, er schickt den kompletten Zustand mit
func next_round():
	var rno=round_no+1
	var teams=multiplayer.teams
	var score=multiplayer.score
	if rno==HALFTIME_ROUND+1:
		#Seitenwechsel, die Punkte wandern mit den Spielern
		teams=swapped_teams()
		score=[score[1],score[0]]
		loss_streak=[loss_streak[1],loss_streak[0]]
	rpc('start_round',teams,score,rno)

#Der Server schickt Teams, Punkte und Rundennummer mit, sonst laufen die
#Peers auseinander
sync func start_round(teams,score,rno):
	multiplayer.teams=teams
	multiplayer.score=score
	round_no=rno
	match_over=false
	restart_in=0
	$CanvasLayer/won.hide()
	$CanvasLayer/bannerbar.hide()
	$CanvasLayer/play.hide()
	var used=[0,0]
	for x in player_ids():
		var p=get_node_or_null(str(x))
		if p==null:
			continue
		var t=multiplayer.team_of(x)
		p.respawn(spawn_point(t,used[t]))
		used[t]+=1
	round_active=both_teams_manned()
	update_score()
	reset_bomb()
	$CanvasLayer/bombstate.hide()
	begin_freeze()

#Neues Match, nur der Server
func _on_play_pressed():
	if !get_tree().is_network_server():
		return
	multiplayer.reset_money()
	loss_streak=[0,0]
	rpc('reset_stats')
	rpc('start_round',multiplayer.teams,[0,0],1)
