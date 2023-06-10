extends StaticBody2D

var taken
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func set_pos (x,y):
	position.x = x
	position.y = y
	taken = false
	
@rpc("call_local")
func call_taken():
	taken = true
	
func is_taken():
	return taken

@rpc("call_local")
func prepare_delete():
	self.call_deferred("queue_free")

