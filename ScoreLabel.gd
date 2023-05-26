extends Label

var globals

func _ready():
	globals = get_node("/root/World")

func _process(_delta):
	text = ""
	if globals.players is Array:
		for node in globals.players:
			#var shroom
			if is_instance_of(node, EncodedObjectAsID):
				var test = node.get_object_id()
				node = instance_from_id(test)
			#else:
			#	shroom = node
			if node == null: 
				return
			text = text + "Player ID: " + str(node.name) + " Score: " + str(node.get_points()) + "\n"
		set_text(text)

func get_points(obj):
	return obj.get_points()
