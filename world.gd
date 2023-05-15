extends Node2D

var mushroom_scene = preload("res://mushroom.tscn")

var mushroom_create_flag
var thread
var mutex

var temp_counter # not to spam on every frame
var mushroom_counter = 10
var globals
const STARTING_MUSHROOM_AMOUNT = 20

var shroom_x = 0
var shroom_y = 0

# needed to host as a server
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
var player_scene = preload("res://player.tscn")

@onready var join_button = $JoinButton

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
	temp_counter += _delta
	if temp_counter > 1:
		#print("my name is " +str(self.name) + " and my thread id is " + str(self.thread.get_id()))
		temp_counter = 0
	# Creating new mushrooms during game
	if mushroom_create_flag == true:
		if multiplayer.get_unique_id() == 1:
			print("-------------------")
			print(multiplayer.get_unique_id())
			print("-------------------")
			mushroom_create_flag = false
			var time = randi_range(10, 20) # rand time to wait
			var amount = randi_range(0, 4) # rand amount
			var num_of_players = 0
			for node in self.get_children():
				if 'Player' in node.name:
					num_of_players += 1		
			
			await get_tree().create_timer(time).timeout # wait time
			print("server grzybki robi")
			#rpc("initiate_mushrooms", amount * globals.players.size())
			initiate_mushrooms(2)
			mushroom_create_flag = true

func initiate_mushrooms(x):
	if multiplayer.get_unique_id() != 1:
		return
	for i in x:
		mutex.lock()
		var m = mushroom_scene.instantiate()
		m.name = "Mushroom_" + str(mushroom_counter)
		mushroom_counter = mushroom_counter + 1
		#print("XD " + str(multiplayer.get_unique_id()))
		globals.new_shroom_pos(multiplayer.get_unique_id())
		var pos_x = globals.new_shroom_pos_x
		var pos_y = globals.new_shroom_pos_y
		#m.position.x = randi_range(-600, 1900)
		#m.position.y = randi_range(-300, 1000)
		print("spawned " + str(m.name) + "at position x: " +str(pos_x) + " y: " + str(pos_y) + " on node:" + str(multiplayer.get_unique_id()))
		add_child(m)
		#call_deferred("add_child", m)
		m.set_pos(pos_x,pos_y)
		mutex.unlock()
		
func _exit_tree():
	thread.wait_to_finish()

func _thread_function():
	call_deferred("_process", get_process_delta_time())
	
func add_player(peer_id):
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	call_deferred("add_child", player, true)
	call_deferred("initiate_mushrooms", 10)
	set_process(true)
	#add_child(player)

func remove_player(peer_id):
	var player = get_node_or_null("Player_" + str(peer_id))
	if player:
		player.queue_free()

func find_all_obstacles():
	for node in self.get_children():
		if 'Bush' in node.name || 'Tree_trunk' in node.name || 'Rock' in node.name: 
			globals.obstacles_in_game.append(node)
			#print(node.name, " at ", node.position)

func _on_join_button_pressed():
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer
	if multiplayer.is_server():
		join_button.hide()
	#set_process(true)

func _on_host_button_pressed():
	enet_peer.create_server(PORT) # listen to port
	multiplayer.multiplayer_peer = enet_peer
	if multiplayer.is_server():
		join_button.hide()
	multiplayer.peer_connected.connect(add_player)
	
	#add_player(multiplayer.get_unique_id()) # a player on a server

@rpc("any_peer")
func delete_shroom(obj):
	obj.prepare_delete()
	
@rpc("call_local")
func test2(obj):
	obj.call_deferred("prepare_delete")
