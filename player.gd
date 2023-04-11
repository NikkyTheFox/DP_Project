extends CharacterBody2D

const SPEED = 200.0

var can_move
var num_of_points
var text

func _ready():
	can_move = true
	num_of_points = 0
	text = ""

# Movement
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

func _physics_process(delta):
	# Movement
	get_input()	
	# Collision
	var collision = move_and_collide(velocity * delta)
	if collision:
		var obj = collision.get_collider()
		# Picking up mushrooms
		if 'Mushroom' in obj.name:	
			can_move = false
			await get_tree().create_timer(3.0).timeout # wait time 
			if obj != null:
				obj.queue_free() # mushroom dissapear
				print("Picking up a mushroom ", obj.name)
				_increase_points()
				can_move = true
			else:
				can_move = true
		else:
			print("I collided with ", obj.name)
	
	
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
