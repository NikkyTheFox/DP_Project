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

var new_shroom_pos_x
var new_shroom_pos_y

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
	set_process(false) # do not run the game until "start" button is pressed
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
			await get_tree().create_timer(time).timeout # wait time
			print("server grzybki robi")
			#rpc("initiate_mushrooms", amount * globals.players.size())
			initiate_mushrooms(amount * players.size())
			mushroom_create_flag = true

# Create muchrooms
func initiate_mushrooms(x):
	if not is_multiplayer_authority():
		return
	for i in x:
		mutex.lock()
		globals.new_shroom_pos(multiplayer.get_unique_id())
		#new_shroom_pos(multiplayer.get_unique_id())
		var pos_x = globals.new_shroom_pos_x
		var pos_y = globals.new_shroom_pos_y
		#var pos_x = new_shroom_pos_x
		#var pos_y = new_shroom_pos_y
		rpc("add_new_mushroom", pos_x, pos_y)
		mutex.unlock()

func new_shroom_pos(peer_id):
	if peer_id == 1:
		new_shroom_pos_x = randi_range(-600, 1900)
		new_shroom_pos_y = randi_range(-300, 1000)

func _exit_tree():
	thread.wait_to_finish()

func _thread_function():
	call_deferred("_process", get_process_delta_time())

# send information from SERVER to all clients about mushroom's position in world
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
	

# from SERVER to all clients and server
# 		add a mushroom to mushroom_array
@rpc("any_peer", "call_local")
func append_mushroom_array(obj):
	self.mushroom_array.append(obj)

# from SERVER to all clients
# 		add an obstacle to obstacle_array
@rpc("any_peer")
func append_obstacles_in_game(obj):
	self.obstacles_in_game.append(obj)

# from SERVER to all clients and server
@rpc("any_peer", "call_local")
func get_players():
	return self.players

# create a new mushroom node and add it to the world scene
func add_mushroom(pos_x, pos_y):
	var mushroom = mushroom_scene.instantiate()
	mushroom.name = "Mushroom_" + str(mushroom_counter)
	mushroom_counter+=1
	mushroom.set_pos(pos_x, pos_y)
	rpc("sync_shroom_position", mushroom, pos_x, pos_y)
	add_child(mushroom)
	shroom_list.append(mushroom)

# can be called ONLY from SERVER
# from SERVER to all clients and server
# add a mushroom
@rpc("authority", "call_local")
func add_new_mushroom(pos_x, pos_y):
	add_mushroom(pos_x,pos_y)

# add new player and set multiplayer_authority (only client can controll the player)
func add_player(peer_id):
	peer_list.append(peer_id)
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	self.players.append(player)

#add new player instance to the client
@rpc
func add_new_player(new_peer_id):
	add_player(new_peer_id)

#add all existing before new connection player instances to the client
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

# add all Tree_trunks, Rocks and Bushes to an array
func find_all_obstacles():
	for node in self.get_children():
		if 'Bush' in node.name || 'Tree_trunk' in node.name || 'Rock' in node.name: 
			self.obstacles_in_game.append(node)
			#print(node.name, " at ", node.position)

# create a client connection to a port
func _on_join_button_pressed():
	enet_peer.create_client("192.168.170.254", PORT)
	multiplayer.multiplayer_peer = enet_peer
	if multiplayer.is_server():
		menu.hide()
	#set_process(true)

# create a server and listen to a port
# add players to server and other clients upon new connection to the port
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

# start the game
func _on_start_button_pressed():
	print("START")
	set_process(true)
	start_physics_process()
	rpc("start_physics_process")

# send SERVER'S mushroom array, obstacles array, players array and freedplayers array to all Clients
@rpc
func sync_globals(mush_arr, obstacles_array, freed_players_array, players_array):
	mushroom_array = mush_arr
	obstacles_in_game = obstacles_array
	freed_players = freed_players_array
	players = players_array

# start physics process (player movement) on all clients
@rpc
func start_physics_process():
	globals = get_node("/root/World")
	print("globals")
	for node in globals.get_children():
		print(node.name)
		if "Player" in node.name:
			print("found playa")
			node.set_physics_process(true)
