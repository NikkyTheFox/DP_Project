extends Label


var globals
var root_node

func _ready():
	globals = get_node("/root/Test")
	root_node = get_node("/root")

func _process(_delta):
	text = ""
	for node in globals.players:
		text = text + "Player ID: " + str(node.name) + " Score: " + str(node.get_points()) + "\n"
	set_text(text)
