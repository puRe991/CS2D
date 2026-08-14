extends Control
func _ready():

	if !get_tree().is_network_server():
		$"Start Game".disabled=true
		$"Start Game".text="WAITING FOR HOST"
		$Label.text="Connected to "+multiplayer.self_name+"'s server."
	else:
		print(IP.get_local_addresses())
		$Label.text=PoolStringArray(IP.get_local_addresses()).join("\n")
func _process(delta):
	$ItemList.clear()
	for x in multiplayer.players:
		var line='['+multiplayer.TEAM_NAMES[multiplayer.team_of(x)]+'] '+str(x)+" "+multiplayer.players[x]
		if x == get_tree().get_network_unique_id():
			line+=" (You)"
		$ItemList.add_item(line)
		$ItemList.set_item_custom_fg_color($ItemList.get_item_count()-1,multiplayer.TEAM_COLORS[multiplayer.team_of(x)])

func _on_Start_Game_pressed():
	rpc("start")

#Der Server entscheidet, der Client fragt nur an
func _on_Switch_Team_pressed():
	var id=get_tree().get_network_unique_id()
	var t=multiplayer.TEAM_CT
	if multiplayer.team_of(id)==multiplayer.TEAM_CT:
		t=multiplayer.TEAM_T
	if get_tree().is_network_server():
		multiplayer.request_team(id,t)
	else:
		multiplayer.rpc_id(1,"request_team",id,t)

sync func start():
	get_tree().change_scene("res://testscene1.tscn")
