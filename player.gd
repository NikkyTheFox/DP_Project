extends CharacterBody2D

const SPEED = 200.0

var can_move # false if is during the picking up process
var num_of_points # total num of collected mushrooms
var text # score
var walking_to_mushroom # true if is walking to mushroom
var blocked
var collision_cnt
var closest_mushroom # node to go to
var thread
var mutex
var direction_vector
var temp_counter
var initial_position_before_avoidance
var stealing_cnt
var collision_flag
var peer # needed to be a client

# some new shit
var globals 
var flaga
var flaga_cnt

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")

func _ready():
	self.position.x = randi_range(-600, 1900)
	self.position.y = randi_range(-300, 1000)
	globals = get_node("/root/World")
	can_move = true
	num_of_points = 0
	text = ""
	animation_tree.active = true
	walking_to_mushroom = false
	closest_mushroom = null
	blocked = false
	flaga = false
	collision_flag = false
	flaga_cnt = 0
	mutex = Mutex.new()
	thread = Thread.new()
	temp_counter = 0
	collision_cnt = 1

	direction_vector = Vector2.ZERO
	initial_position_before_avoidance = Vector2.ZERO
	set_physics_process(false)
	if not is_multiplayer_authority():
		# do not run threat if player is created on Server
		return
	thread.start(_thread_function) #a player will perform all it's task in new thread

# Movement by keyboard
func get_input():
	if can_move == true:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_dir * SPEED
	else:
		velocity = Vector2.ZERO

# Points
func _increase_points():
	num_of_points += 1
	text = "Score: %s" % num_of_points
	rpc("remote_sync_points", num_of_points)
	
func get_points():
	return num_of_points

# Function to find all mushrooms + calculate distance + find closest one
func find_mushrooms():
	mutex.lock()
	globals.mushroom_array.clear()
	for node in self.get_parent().get_children():
		if 'Mushroom' in node.name && node not in globals.mushroom_array:
			globals.mushroom_array.append(node)
			
	mutex.unlock()
	var playerx = self.position.x
	var playery = self.position.y
	var min_distance = 10000
	
	for mushroom in globals.mushroom_array:
		var x = (playerx - mushroom.position.x) * (playerx - mushroom.position.x) 
		var y = (playery - mushroom.position.y) * (playery - mushroom.position.y) 
		if sqrt(x + y) < min_distance:
			min_distance = sqrt(x + y)
			closest_mushroom = mushroom
	walking_to_mushroom = true
	
	return closest_mushroom # returns mushroom with the smallest distance to go to
	
	# Function to find all mushrooms + calculate distance + find closest one
func find_second_closest_mushrooms():
	mutex.lock()
	globals.mushroom_array.clear()
	for node in self.get_parent().get_children():
		if 'Mushroom' in node.name && node not in globals.mushroom_array:
			globals.mushroom_array.append(node)
	mutex.unlock()
	
	var playerx = self.position.x
	var playery = self.position.y
	var min_distance = 10000
	var closest = globals.mushroom_array[0]
	var pre_closest_mushroom = globals.mushroom_array[0]
	
	for mushroom in globals.mushroom_array:
		var x = (playerx - mushroom.position.x) * (playerx - mushroom.position.x) 
		var y = (playery - mushroom.position.y) * (playery - mushroom.position.y) 
		if sqrt(x + y) < min_distance:
			min_distance = sqrt(x + y)
			pre_closest_mushroom = closest
			closest = mushroom
	walking_to_mushroom = true
	
	return globals.mushroom_array[0] # returns mushroom with the smallest distance to go to

# Creates direction vector to create movement
func go_to_mushroom(rand_value):
	var vector = [0, 0]
	var bufer = 1 # to make straight movement
	# checking x direction
	if (closest_mushroom.position.x - self.position.x) > bufer:
		vector[0] = 1
	elif (closest_mushroom.position.x - self.position.x) < -bufer:
		vector[0] = -1
	else:
		vector[0] = 0
	# checking y direction
	if (closest_mushroom.position.y - self.position.y) > bufer:
		vector[1] = 1
	elif (closest_mushroom.position.y - self.position.y) < -bufer:
		vector[1] = -1
	else:
		vector[1] = 0
	
	# creating diagonal vectors
	"""if vector[0] == 1 && vector[1] == 1:
		vector[0] = 0.7
		vector[1] = 0.7
	elif vector[0] == 1 && vector[1] == -1:
		vector[0] = 0.7
		vector[1] = -0.7
	elif vector[0] == -1 && vector[1] == -1:
		vector[0] = -0.7
		vector[1] = -0.7
	elif vector[0] == -1 && vector[1] == 1:
		vector[0] = -0.7
		vector[1] = 0.7"""
		
	vector[0] = vector[0] * 0.7
	vector[1] = vector[1] * 0.7
	
	vector[0] = vector[0] * rand_value
	vector[1] = vector[1] * rand_value
	return vector # direction vector

# steal points from player with lower num_of_points or set own points to 0
func fight_with_player(player, direction_vector):
	if self.num_of_points > player.num_of_points:
		print("Player ", self.name, " stole from ", player.name)
		self.num_of_points += player.num_of_points
		player.num_of_points = 0
		rpc("remote_sync_points", self.num_of_points)
		rpc("remote_sync_points2", player.name, player.num_of_points)
		return direction_vector
	else:
		collision_flag = true
		return direction_vector
	#else:
	#	self.num_of_points = 0
	#	rpc("remote_sync_points", self.num_of_points)

# Find all obstacles in the game
func check_collision_with_obstacles(dir_vector, pos):
	var hit_buffer = 200
	var bufer = 30 #30
	var angle = 0.4
	var size = 	50 #50
	#var temp0 = dir_vector[0]
	#var temp1 = dir_vector[1]
	for obstacle in globals.obstacles_in_game:
		if is_instance_of(obstacle, EncodedObjectAsID):
			var test = obstacle.get_object_id()
			obstacle = instance_from_id(test)
		if obstacle == null:
			break;
		var right_bound = obstacle.position.x + size + bufer
		var left_bound = obstacle.position.x - size - bufer
		var top_bound = obstacle.position.y - size - bufer
		var low_bound = obstacle.position.y + size + bufer
		
		#if player moving torwards obstacle, inside upper and lower bounds of obstacle:
		if pos.y >= top_bound && pos.y <= low_bound && abs(pos.x - obstacle.position.x) < hit_buffer:
			if pos.x < obstacle.position.x && dir_vector[0] < 0: # obstacle to the right and moving right
				var temp_X = dir_vector[0]
				var temp_Y = dir_vector[1]
				dir_vector[0] = -temp_Y
				dir_vector[1] = temp_X
			if pos.x > obstacle.position.x && dir_vector[0] < 0: # obstacle to the left and moving left
				var temp_X = dir_vector[0]
				var temp_Y = dir_vector[1]
				dir_vector[0] = -temp_Y
				dir_vector[1] = temp_X
		#if player moving torwards obstalce, inside left and right bounds:
		if pos.x >= left_bound && pos.x <= right_bound  && abs(pos.y - obstacle.position.y) < hit_buffer:
			if pos.y > obstacle.position.y && dir_vector[1] < 0: # obstacle above and moving up
				var temp_X = dir_vector[0]
				var temp_Y = dir_vector[1]
				dir_vector[0] = -temp_Y
				dir_vector[1] = temp_X
			if pos.y < obstacle.position.y && dir_vector[1] > 0: # obstacle below and moving down
				var temp_X = dir_vector[0]
				var temp_Y = dir_vector[1]
				dir_vector[0] = -temp_Y
				dir_vector[1] = temp_X

		"""
		# player inside obstacle's boundaries:
		if pos.x >= left_bound && pos.x <= right_bound: # between left and right bound
			if pos.y >= top_bound && pos.y <= low_bound: # between top and low bound
				
				
				if pos.x == obstacle.position.x:
					dir_vector[0] = 1 # run 90 degrees right
					dir_vector[1] = 0
				if pos.y == obstacle.position.y:
					dir_vector[1] = 1 # run 90 degrees bottom
					dir_vector[0] = 0
				
				if pos.x < obstacle.position.x: # you are on left side of obstacle
					dir_vector[0] -= angle # go more to the left
				elif pos.x > obstacle.position.x: # you are on right side of obstacle
					dir_vector[0] += angle # go more to the right
				else: # you are heading straight on obstacle
					dir_vector[0] = 1 # run 90 degrees right
					dir_vector[1] = 0
				if pos.y < obstacle.position.y: # you are on low (map-top) of obstacle
					dir_vector[1] -= angle # go more to the top of the screen
				elif pos.y > obstacle.position.y: # you are on top (map-down) of obstacle
					dir_vector[1] += angle # go more to the bottom of the screen
				else: # you are heading straight on obstacle
					dir_vector[1] = 1 # run 90 degrees bottom
					dir_vector[0] = 0
				
				#print("Running from [", temp0, " ", temp1, "] to ", direction_vector)
				self.blocked = true
				#dir_vector.normalized()
				return dir_vector"""
	return dir_vector

func unblock_movement_to_mushroom():
	#print("Unblocked:> at pos: ", self.position)
	self.blocked = false

func calculate_collision_on_way(dir_vector, pos):
	var bufor = 50 #50	
	if self.blocked == false: # not yet started avoiding collision
		initial_position_before_avoidance = pos
		dir_vector = check_collision_with_obstacles(dir_vector, pos)	
	elif abs(pos.x - initial_position_before_avoidance.x) > bufor && \
		abs(pos.y - initial_position_before_avoidance.y) > bufor:
		unblock_movement_to_mushroom() # stop avoiding
	elif self.blocked == true: # still avoiding
		dir_vector = check_collision_with_obstacles(dir_vector, pos)	
	return dir_vector

func predict_collisions_on_way(dir_vector, pos):
	var vector = dir_vector
	for d in range (1, 2): #calculate position in next step
		vector = calculate_collision_on_way(vector, pos)
		if vector[0] == dir_vector[0] && vector[1] == dir_vector[1]: # there was no collision:>
			pass
		else:
			print("FOUND STH !")
		if direction_vector[0] > 0: # going right
			position.x += 1
		elif direction_vector[0] < 0:
			position.x -= 1 # going left
		if direction_vector[1] > 0: # going down
			position.y += 1
		elif direction_vector[1] < 0:
			position.y -= 1	
	return vector

func _physics_process(delta):
	if not is_multiplayer_authority(): # disable processing for players that are not controlled by Client
		set_physics_process(false)
		return
		
	temp_counter += delta
	if temp_counter > 1:
		temp_counter = 0
	
	if globals.mushroom_array.is_empty():
		walking_to_mushroom = false
		
	flaga_cnt += 1
	
	# do 40 steps to avoid a obstacle that was just hit
	if flaga_cnt > 40:
		flaga = false
		
	# avoid obstacles
	direction_vector = predict_collisions_on_way(direction_vector, self.position)
	velocity[0] = direction_vector[0] * SPEED
	velocity[1] = direction_vector[1] * SPEED
	velocity.normalized()
	
	# if not found a closest mushroom yet:
	if walking_to_mushroom == false:
		closest_mushroom = find_mushrooms()
	
	if collision_flag == true:
		closest_mushroom = find_second_closest_mushrooms()
		print("WALKING TO SECOND MUSH")
	
	# closest mushroom found, movement there:
	if closest_mushroom != null && blocked == false:
		direction_vector = go_to_mushroom(1)
		#print("GOING IN DIR : ", direction_vector)
		velocity[0] = direction_vector[0] * SPEED
		velocity[1] = direction_vector[1] * SPEED
		velocity.normalized()	
		
	
	# Changing animations
	if velocity == Vector2.ZERO:
		animation_tree.get("parameters/playback").travel("Idle")
	else:
		animation_tree.get("parameters/playback").travel("Walk")
		animation_tree.set("parameters/Idle/blend_position", velocity)
		animation_tree.set("parameters/Walk/blend_position", velocity)
	rpc("remote_set_position", global_position)
	# Collision
	if flaga:
		direction_vector[0] = -direction_vector[0]
		direction_vector[1] = -direction_vector[1]
		velocity[0] = direction_vector[0] * SPEED
		velocity[1] = direction_vector[1] * SPEED
		velocity.normalized()
		
	var collision = move_and_collide(velocity * delta)
	if collision:
		var obj = collision.get_collider()
		# Picking up mushrooms
		if 'Mushroom' in obj.name:
			call_deferred("pickup_mushroom", obj)
			collision_flag = false
		elif 'Player' in obj.name:
			direction_vector = fight_with_player(obj, direction_vector)
		else:
			print("I collided with ", obj.name, " at ", self.position)
			#direction_vector = check_collision_with_obstacles(direction_vector, self.position)
			#direction_vector[0] = -direction_vector[0]
			#direction_vector[1] = -direction_vector[1]
			flaga = true
			flaga_cnt = 0
	#else: # no collsion
		
		

func pickup_mushroom(obj):
	var shroom
	if  is_instance_of(obj, EncodedObjectAsID): # needed to get object from objectID
		var test = obj.get_object_id()
		shroom = instance_from_id(test)
		#return
	else:
		shroom = obj
	if shroom == null: return
	can_move = false
	self.blocked = false
	animation_tree.get("parameters/playback").travel("Idle")
	velocity = Vector2.ZERO
	await get_tree().create_timer(3.0).timeout # wait time 
	if shroom != null:				
		mutex.lock() #lock mutex in order to prevent changes by other players
		#print("I ve locked the world, it is my precious")
		if shroom.get_parent() == null:
			return
		rpc("delete_shroom", shroom.name)
		print("Picking up a mushroom ", shroom.name)
		call_deferred("_increase_points") #thread-safe call
		can_move = true
		walking_to_mushroom = false
		rpc("clear_mushroom_array")
		globals.mushroom_array.clear()
		closest_mushroom = null
		mutex.unlock()
		#print("I ve unlocked the world, feel free to act on your own will")
	else:
		can_move = true

# called upon being deleted from tree, wait for thread to join
func _exit_tree():
	thread.wait_to_finish()

# run physics process in new thread
func _thread_function():
	call_deferred("_physics_process", get_physics_process_delta_time())

# send a call to Server and other clients to clear their's mushroom_array
@rpc
func clear_mushroom_array():
	globals.mushroom_array.clear()

# send CLIENT'S position to server and other clients
@rpc("unreliable")
func remote_set_position(authority_position):
	global_position = authority_position

# send information about CLIENT'S points to Server and other Clients
@rpc("unreliable")
func remote_sync_points(points):
	self.num_of_points = points

# send info to a Client to set player points to given number
@rpc("unreliable")
func remote_sync_points2(player_name, points):
	var world = get_node("/root/World")
	if is_multiplayer_authority():
		for node in world.get_children():
			if player_name in node.name:
				node.num_of_points = points

# senc a call to Server and other Clients to delete a given mushroom
# call it locally too
@rpc("any_peer", "call_local", "reliable", 1)
func delete_shroom(node_name):
	var shroom = get_parent().get_node_or_null(NodePath(node_name))
	if shroom == null: return
	shroom.prepare_delete()
