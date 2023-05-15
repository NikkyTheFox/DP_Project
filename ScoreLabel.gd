extends Label


var globals
var root_node

func _ready():
	globals = get_node("/root/Test")
	root_node = get_node("/root")

func _process(_delta):
	text = ""
	for node in globals.players:
		var shroom
		if  is_instance_of(node, EncodedObjectAsID):
			var test = node.get_object_id()
			node = instance_from_id(test)
			#return
		else:
			shroom = node
		if node == null: return
		text = text + "Player ID: " + str(node.name) + " Score: " + str(node.get_points()) + "\n"
	set_text(text)
