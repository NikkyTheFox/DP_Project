extends Node

#var mushroom_array = [] # found mushrooms
##var picked_up_mushrooms = [] # already picked up mushrooms
#var obstacles_in_game = []
#var freed_players = []
#var players = []
var new_shroom_pos_x
var new_shroom_pos_y


# Called when the node enters the scene tree for the first time.
func _ready():
	new_shroom_pos_x = randi_range(-600, 1900)
	new_shroom_pos_y = randi_range(-600, 1900)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta):
#	pass
	
func new_shroom_pos(peer_id):
	if peer_id == 1:
		new_shroom_pos_x = randi_range(-600, 1900)
		new_shroom_pos_y = randi_range(-300, 1000)
