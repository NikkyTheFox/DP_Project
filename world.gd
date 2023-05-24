extends Node2D

var mushroom_scene = preload("res://mushroom.tscn")

var mushroom_create_flag
var thread
var mutex

var temp_counter # not to spam on every frame
var mushroom_counter = 10
var globals
const STARTING_MUSHROOM_AMOUNT = 20

var peer_list = []
var shroom_list = []
var game_init_bool = false
var game_init_2_bool = false

# needed to host as a server
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
var player_scene = preload("res://player.tscn")

# some new shit
var mushroom_array = [] # found mushrooms
var obstacles_in_game = []
var freed_players = []
var players = []


@onready var menu = $JoinButton
@onready var host_button = $JoinButton/Menu/MarginContainer/VBoxContainer/HostButton
@onready var join_button = $JoinButton/Menu/MarginContainer/VBoxContainer/JoinButton
@onready var start_button = $JoinButton/Menu/MarginContainer/VBoxContainer/StartButton

func _ready():
	set_process(false)
	globals = get_node("/root/Test")
	mushroom_create_flag = true
	mutex = Mutex.new()
	thread = Thread.new()
	temp_counter = 0
	find_all_obstacles()
	thread.start(_thread_function)

func _process(_delta):
	if !game_init_bool:
		game_init_bool = true
		return
	if !game_init_2_bool:
		initiate_mushrooms(5)
		game_init_2_bool = true
	temp_counter += _delta
	if temp_counter > 1:
		temp_counter = 0
	# Creating new mushrooms during game
	rpc("sync_globals", mushroom_array, obstacles_in_game, freed_players, players)
	if mushroom_create_flag == true:
		if is_multiplayer_authority():
			mushroom_create_flag = false
			var time = randi_range(5, 16) # rand time to wait
			var amount = randi_range(1, 4) # rand amount
			var num_of_players = 0
			for node in self.get_children():
				if 'Player' in node.name:
					num_of_players += 1		
			await get_tree().create_timer(time).timeout # wait time
			print("server grzybki robi")
			#rpc("initiate_mushrooms", amount * globals.players.size())
			initiate_mushrooms(amount * players.size())
			mushroom_create_flag = true

func initiate_mushrooms(x):
	if not is_multiplayer_authority():
		return
	for i in x:
		mutex.lock()
		globals.new_shroom_pos(multiplayer.get_unique_id())
		var pos_x = globals.new_shroom_pos_x
		var pos_y = globals.new_shroom_pos_y
		rpc("add_new_mushroom", pos_x, pos_y)
		mutex.unlock()
		
func _exit_tree():
	thread.wait_to_finish()

func _thread_function():
	call_deferred("_process", get_process_delta_time())
	
@rpc("any_peer")
func sync_shroom_position(obj, pos_x, pos_y):
	var shroom
	if  is_instance_of(obj, EncodedObjectAsID):
		var test = obj.get_object_id()
		shroom = instance_from_id(test)
		#return
	else:
		shroom = obj
	if shroom == null: return
	shroom.position.x = pos_x
	shroom.position.y = pos_y
	

@rpc("any_peer", "call_local")
func append_mushroom_array(obj):
	self.mushroom_array.append(obj)
	
@rpc("any_peer")
func append_obstacles_in_game(obj):
	self.obstacles_in_game.append(obj)
	
@rpc("any_peer", "call_local")
func get_players():
	return self.players
	
func add_mushroom(pos_x, pos_y):
	var mushroom = mushroom_scene.instantiate()
	mushroom.name = "Mushroom_" + str(mushroom_counter)
	mushroom_counter+=1
	mushroom.set_pos(pos_x, pos_y)
	rpc("sync_shroom_position", mushroom, pos_x, pos_y)
	add_child(mushroom)
	shroom_list.append(mushroom)
	
@rpc("authority","call_local")
func add_new_mushroom(pos_x, pos_y):
	add_mushroom(pos_x,pos_y)
	
func add_player(peer_id):
	peer_list.append(peer_id)
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	self.players.append(player)

@rpc
func add_new_player(new_peer_id):
	add_player(new_peer_id)
	
@rpc
func add_existing_players(peer_ids):
	for peer_id in peer_ids:
		add_player(peer_id)
	for sh in shroom_list:
		add_child(sh)

func remove_player(peer_id):
	var player = get_node_or_null("Player_" + str(peer_id))
	if player:
		player.queue_free()

func find_all_obstacles():
	for node in self.get_children():
		if 'Bush' in node.name || 'Tree_trunk' in node.name || 'Rock' in node.name: 
			self.obstacles_in_game.append(node)
			#print(node.name, " at ", node.position)

func _on_join_button_pressed():
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer
	if multiplayer.is_server():
		menu.hide()
	#set_process(true)

func _on_host_button_pressed():
	join_button.hide()
	start_button.show()
	enet_peer.create_server(PORT) # listen to port
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(
		func(new_peer_id):
			#await get_tree().create_timer(1).timeout
			rpc_id(new_peer_id, "add_existing_players", peer_list)
			rpc("add_new_player", new_peer_id)
			add_player(new_peer_id)
	)
	
	#add_player(multiplayer.get_unique_id()) # a player on a server

func _on_start_button_pressed():
	set_process(true)

@rpc
func sync_globals(mush_arr, obstacles_array, freed_players_array, players_array):
	mushroom_array = mush_arr
	obstacles_in_game = obstacles_array
	freed_players = freed_players_array
	players = players_array
