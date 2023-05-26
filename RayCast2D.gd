extends RayCast2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var direction_to_player = global_position.direction_to(target.global_position)
	rayCast2D.cast_to = direction_to_player * MAX_DISTANCE
	rayCast2D.force_raycast_update()
	var collision_object = rayCast2D.get_collider()
	if collision_object == target:
		do_something_related_to_target()
