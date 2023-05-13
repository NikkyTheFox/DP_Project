extends Node2D

var mushroom_scene = preload("res://mushroom.tscn")

var mushroom_create_flag
var thread
var mutex

var temp_counter # not to spam on every frame

func _ready():
	mushroom_create_flag = true
	mutex = Mutex.new()
	thread = Thread.new()
	thread.start(_thread_function)
	temp_counter = 0

func _process(_delta):	
	temp_counter += _delta
	if temp_counter > 1:
		#print("my name is " +str(self.name) + " and my thread id is " + str(self.thread.get_id()))
		temp_counter = 0
	# Creating new mushrooms during game
	if mushroom_create_flag == true:
		mushroom_create_flag = false
		var time = randi_range(10, 20) # rand time to wait
		var amount = randi_range(0, 4) # rand amount
		var num_of_players = 0
		for node in self.get_children():
			if 'Player' in node.name:
				num_of_players += 1
			
		await get_tree().create_timer(time).timeout # wait time 
		initiate_mushrooms(amount * num_of_players)
		mushroom_create_flag = true
	
func initiate_mushrooms(x):
	for i in x:
		mutex.lock()
		var m = mushroom_scene.instantiate()
		m.position.x = randi_range(-600, 1900)
		m.position.y = randi_range(-300, 1000)
		call_deferred("add_child", m)
		mutex.unlock()
		
func _exit_tree():
	thread.wait_to_finish()

func _thread_function():
	call_deferred("_process", get_process_delta_time())
