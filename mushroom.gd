extends StaticBody2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func set_pos (x,y):
	position.x = x
	position.y = y

@rpc("call_local")
func prepare_delete():
	var synchronizer = get_node_or_null("MultiplayerSynchronizer")
	synchronizer.call_deferred("queue_free")
	self.call_deferred("queue_free")
