extends CharacterBody2D

const SPEED = 200.0

var can_move # false if is during the picking up process
var num_of_points # total num of collected mushrooms
var text # score
var walking_to_mushroom # true if is walking to mushroom
var blocked
var collision_cnt
#var mushroom_array = [] # found mushrooms
#var picked_up_mushrooms = [] # already picked up mushrooms
var closest_mushroom # node to go to
var thread
var mutex
var globals
var direction_vector
var temp_counter
var initial_position_before_avoidance


@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")


func _ready():
	globals = get_node("/root/Test")
	can_move = true
	num_of_points = 0
	text = ""
	animation_tree.active = true
	walking_to_mushroom = false
	closest_mushroom = null
	blocked = false
	mutex = Mutex.new()
	thread = Thread.new()
	thread.start(_thread_function) #a player will perform all it's task in new thread
	temp_counter =0
	collision_cnt = 1
	direction_vector = Vector2.ZERO
	find_all_obstacles()
	initial_position_before_avoidance = Vector2.ZERO

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
	
func get_points():
	return num_of_points

# Function to find all mushrooms + calculate distance + find closest one
func find_mushrooms():
	mutex.lock()
	for node in self.get_parent().get_children():
		if 'Mushroom' in node.name && node not in globals.picked_up_mushrooms && node not in globals.mushroom_array:
			print(node.name, node.position)
			globals.mushroom_array.append(node)	
	mutex.unlock()
	var playerx = self.position.x
	var playery = self.position.y
	var min_distance = 10000
	
	for mushroom in globals.mushroom_array:
		var x = (playerx - mushroom.position.x) * (playerx - mushroom.position.x) 
		var y = (playery - mushroom.position.y) * (playery - mushroom.position.y) 
		if sqrt(x + y) < min_distance:
			min_distance = sqrt(x+y)
			closest_mushroom = mushroom
	print("CLOSEST MUSHROOM IS: ", closest_mushroom.name)
	print("DISTANCE : ", min_distance)
	walking_to_mushroom = true
	return closest_mushroom # returns mushroom with the smallest distance to go to

# Creates direction vector to create movement
func go_to_mushroom(rand_value):
	var direction_vector = [0, 0]
	var bufer = 1 # to make straight movement
	# checking x direction
	if (closest_mushroom.position.x - self.position.x) > bufer:
		direction_vector[0] = 1
	elif (closest_mushroom.position.x - self.position.x) < -bufer:
		direction_vector[0] = -1
	else:
		direction_vector[0] = 0
	# checking y direction
	if (closest_mushroom.position.y - self.position.y) > bufer:
		direction_vector[1] = 1
	elif (closest_mushroom.position.y - self.position.y) < -bufer:
		direction_vector[1] = -1
	else:
		direction_vector[1] = 0
	
	# creating diagonal vectors
	if direction_vector[0] == 1 && direction_vector[1] == 1:
		direction_vector[0] = 0.7
		direction_vector[1] = 0.7
	elif direction_vector[0] == 1 && direction_vector[1] == -1:
		direction_vector[0] = 0.7
		direction_vector[1] = -0.7
	elif direction_vector[0] == -1 && direction_vector[1] == -1:
		direction_vector[0] = -0.7
		direction_vector[1] = -0.7
	elif direction_vector[0] == -1 && direction_vector[1] == 1:
		direction_vector[0] = -0.7
		direction_vector[1] = 0.7
	
	direction_vector[0] = direction_vector[0] * rand_value
	direction_vector[1] = direction_vector[1] * rand_value
	return direction_vector # direction vector
	
func fight_with_player(player):
	if self.num_of_points >= player.num_of_points:
		print("Player ", self.name, " killed ", player.name)
		self.num_of_points += player.num_of_points
		globals.players.erase(player)
		player.queue_free()
	else:
		player.num_of_points += self.num_of_points
		print("Player ", player.name, " killed ", self.name)
		globals.players.erase(self)
		self.queue_free()
		
		
# Find all obstacles in the game
func find_all_obstacles():
	for node in self.get_parent().get_children():
		if 'Bush' in node.name || 'Tree_trunk' in node.name || 'Rock' in node.name: 
			globals.obstacles_in_game.append(node)
			print(node.name, " at ", node.position)
	

func check_collision_with_obstacles(direction_vector, position):
	var bufer = 30
	var angle = 0.4
	var size = 50
	var temp0 = direction_vector[0]
	var temp1 = direction_vector[1]
	#print("checking pos: ", position, " while on ", self.position)
	for obstacle in globals.obstacles_in_game:
		var right_bound = obstacle.position.x + size + bufer
		var left_bound = obstacle.position.x - size - bufer
		var top_bound = obstacle.position.y - size - bufer
		var low_bound = obstacle.position.y + size + bufer
		if position.x >= left_bound && position.x <= right_bound: # between left and right bound
			if position.y >= top_bound && position.y <= low_bound: # between top and low bound
				if position.x < obstacle.position.x: # you are on left side of obstacle
					direction_vector[0] -= angle # run more left
				elif position.x > obstacle.position.x: # you are on right side of obstacle
					direction_vector[0] += angle # run more right
				else: # you are heading straight on obstacle
					direction_vector[0] += 1 # run 90 degrees
				if position.y < obstacle.position.y: # you are on low (map-top) of obstacle
					direction_vector[1] -= angle # run more to top of map
				elif position.y > obstacle.position.y: # you are on top (map-down) of obstacle
					direction_vector[1] += angle # run more to bottom of map
				else: # you are heading straight on obstacle
					direction_vector[1] += 1
				print("Running from [", temp0, " ", temp1, "] to ", direction_vector)
				self.blocked = true
				return direction_vector
	
	return direction_vector

func unblock_movement_to_mushroom():
	print("Unblocked:> at pos: ", self.position)
	self.blocked = false
	
func calculate_collision_on_way(direction_vector, position):
	var bufor = 50
	if self.blocked == false: # not yet started avoiding collision
		initial_position_before_avoidance = position
		direction_vector = check_collision_with_obstacles(direction_vector, position)	
	elif abs(position.x - initial_position_before_avoidance.x) > bufor && \
		abs(position.y - initial_position_before_avoidance.y) > bufor:
		unblock_movement_to_mushroom() # stop avoiding
	elif self.blocked == true: # still avoiding
		direction_vector = check_collision_with_obstacles(direction_vector, position)	
	return direction_vector


func predict_collisions_on_way(direction_vector, position):
	var vector
	#print("-------------------------------")
	for d in range (1, 50):
		vector = calculate_collision_on_way(direction_vector, position)
		if vector[0] == direction_vector[0] && vector[1] == direction_vector[1]: # there was no collision:>
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
	temp_counter += delta
	if temp_counter > 1:
		#print("My name is " +str(self.name) + " and my thread id is " + str(self.thread.get_id()))
		temp_counter = 0
	# check whether global mushroom array is empty
	if globals.mushroom_array.is_empty():
		walking_to_mushroom = false
	
	# avoid obstacles
	direction_vector = predict_collisions_on_way(direction_vector, self.position)
	velocity[0] = direction_vector[0] * SPEED
	velocity[1] = direction_vector[1] * SPEED
	velocity.normalized()
	# print("MY POSITION : ", self.position, " VELOCITY : ", velocity)

	# if not found a closest mushroom yet:
	if walking_to_mushroom == false:
		closest_mushroom = find_mushrooms()
		print("MY POSITION : ", self.position)
		print("GOING TO : ", closest_mushroom.name)

	# closest mushroom found, movement there:
	if closest_mushroom != null && self.blocked == false:
		var rand_val = randf_range(0.1, 0.9)
		direction_vector = go_to_mushroom(1)
		print("GOING IN DIR : ", direction_vector)
		velocity[0] = direction_vector[0] * SPEED
		velocity[1] = direction_vector[1] * SPEED
		velocity.normalized()
		
	# Movement by keyboard
	# get_input()	
	
	# Changing animations
	if velocity == Vector2.ZERO:
		animation_tree.get("parameters/playback").travel("Idle")
	else:
		animation_tree.get("parameters/playback").travel("Walk")
		animation_tree.set("parameters/Idle/blend_position", velocity)
		animation_tree.set("parameters/Walk/blend_position", velocity)
		
	# Collision
	var collision = move_and_collide(velocity * delta)
	if collision:
		var obj = collision.get_collider()
		# Picking up mushrooms
		if 'Mushroom' in obj.name:	
			can_move = false
			self.blocked = false
			animation_tree.get("parameters/playback").travel("Idle")
			velocity = Vector2.ZERO
			await get_tree().create_timer(3.0).timeout # wait time 
			if obj != null:				
				mutex.lock() #lock mutex in order to prevent changes by other players
				#print("I ve locked the world, it is my precious")
				globals.picked_up_mushrooms.append(obj)
				obj.queue_free() # mushroom dissapear
				print("Picking up a mushroom ", obj.name)
				_increase_points()
				can_move = true
				walking_to_mushroom = false
				globals.mushroom_array.clear()
				closest_mushroom = null
				mutex.unlock()
				#print("I ve unlocked the world, feel free to act on your own will")
			else:
				can_move = true
		elif 'Player' in obj.name:
			fight_with_player(obj)
		else:
			print("I collided with ", obj.name, " at ", self.position)
	else: # no collsion
		collision_cnt = 1




func _exit_tree():
	thread.wait_to_finish()

func _thread_function():
	call_deferred("_physics_process", get_physics_process_delta_time())
