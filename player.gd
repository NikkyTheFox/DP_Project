extends CharacterBody2D

const SPEED = 200.0

var can_move # false if is during the picking up process
var num_of_points # total num of collected mushrooms
var text # score
var walking_to_mushroom # true if is walking to mushroom
var mushroom_array = [] # found mushrooms
var picked_up_mushrooms = [] # already picked up mushrooms
var closest_mushroom # node to go to

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")


func _ready():
	can_move = true
	num_of_points = 0
	text = ""
	animation_tree.active = true
	walking_to_mushroom = false
	closest_mushroom = null

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
	for node in self.get_parent().get_children():
		if 'Mushroom' in node.name && node not in picked_up_mushrooms:
			print(node.name, node.position)
			mushroom_array.append(node)
	
	var playerx = self.position.x
	var playery = self.position.y
	var min_distance = 10000
	var closest_mushroom 
	
	for mushroom in mushroom_array:
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
func go_to_mushroom(closest_mushroom):
	var direction_vector = [0, 0]
	# checking x direction
	if closest_mushroom.position.x > self.position.x:
		direction_vector[0] = 1
	elif closest_mushroom.position.x == self.position.x:
		direction_vector[0] = 0
	else:
		direction_vector[0] = -1
	# checking y direction
	if closest_mushroom.position.y > self.position.y:
		direction_vector[1] = 1
	elif closest_mushroom.position.y == self.position.y:
		direction_vector[1] = 0
	else:
		direction_vector[1] = -1
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

	return direction_vector # direction vector
	

func _physics_process(delta):
	# if not found a closest mushroom yet:
	if walking_to_mushroom == false:
		closest_mushroom = find_mushrooms()
		print("MY POSITION : ", self.position)
		print("GOING TO : ", closest_mushroom.name)
	# closest mushroom found, movement there:
	if closest_mushroom != null:
		var direction_vector = go_to_mushroom(closest_mushroom)
		velocity[0] = direction_vector[0] * SPEED		
		velocity[1] = direction_vector[1] * SPEED
		
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
			animation_tree.get("parameters/playback").travel("Idle")
			await get_tree().create_timer(3.0).timeout # wait time 
			if obj != null:
				picked_up_mushrooms.append(obj)
				obj.queue_free() # mushroom dissapear
				print("Picking up a mushroom ", obj.name)
				_increase_points()
				can_move = true
				walking_to_mushroom = false
				mushroom_array.clear()
				closest_mushroom = null
			else:
				can_move = true
		else:
			print("I collided with ", obj.name)
	
	
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
