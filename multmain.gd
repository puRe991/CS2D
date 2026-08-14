extends Node

remote var players={}
remote var teams={}
remote var score=[0,0]

var self_name

var bullet

const MAX_PLAYERS=10

const TEAM_T=0
const TEAM_CT=1
const TEAM_NAMES=['T','CT']
const TEAM_COLORS=[Color(0.95,0.72,0.24),Color(0.36,0.66,1)]

func _ready():
	bullet=load("res://bullet.tscn")
	get_tree().connect('connected_to_server',self,"connected")
	get_tree().connect('network_peer_connected',self,"player_connected")
	get_tree().connect('network_peer_disconnected',self,"player_disconnected")

func make_server(port,name_i):
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(int(port), MAX_PLAYERS)
	get_tree().set_network_peer(peer)
	get_tree().set_meta("network_peer", peer)
	self_name=name_i
	players={1:name_i}
	teams={1:TEAM_T}
	score=[0,0]

func make_client(ip,port,name_i):
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip,int(port))
	get_tree().set_network_peer(peer)
	get_tree().set_meta("network_peer",peer)
	self_name=name_i

#Der Server verteilt die Teams gleichmaessig
func smaller_team():
	var n=[0,0]
	for x in teams:
		n[teams[x]]+=1
	if n[TEAM_T]<=n[TEAM_CT]:
		return TEAM_T
	return TEAM_CT

func team_of(id):
	if teams.has(id):
		return teams[id]
	return TEAM_T

func team_count(t):
	var n=0
	for x in teams:
		if teams[x]==t:
			n+=1
	return n

remote func add_player(id,name_i):
	if get_tree().is_network_server():
		players[id]=name_i
		teams[id]=smaller_team()
		push_lobby()

#Teamwechsel wird vom Client angefragt, entschieden wird auf dem Server
remote func request_team(id,t):
	if get_tree().is_network_server():
		teams[id]=t
		push_lobby()

func push_lobby():
	rset("players",players)
	rset("teams",teams)
	rset("score",score)

func player_connected(id):
	print('someone connected ',id)

func player_disconnected(id):
	if get_tree().is_network_server():
		players.erase(id)
		teams.erase(id)
		push_lobby()

func connected():
	rpc("add_player",get_tree().get_network_unique_id(),self_name)
