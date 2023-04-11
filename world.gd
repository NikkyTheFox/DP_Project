extends Node2D

var mushroom_scene = preload("res://mushroom.tscn")

var mushroom_create_flag

func _ready():
	mushroom_create_flag = true

func _process(delta):
	# Creating new mushrooms during game
	if mushroom_create_flag == true:
		mushroom_create_flag = false
		var time = randi_range(10, 20) # rand time to wait
		var amount = randi_range(0, 4) # rand amount
		await get_tree().create_timer(time).timeout # wait time 
		initiate_mushrooms(amount)
		mushroom_create_flag = true
	
func initiate_mushrooms(x):
	for i in x:
		var m = mushroom_scene.instantiate()
		m.position.x = randi_range(-600, 1900)
		m.position.y = randi_range(-300, 1000)
		add_child(m)
