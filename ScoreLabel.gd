extends Label

var players = []

func _ready():
	for node in self.get_parent().get_parent().get_children():
		if 'Player' in node.name:
			players.append(node)

func _process(_delta):
	text = ""
	for node in players:
		text = text + "Player ID: " + str(node.name) + " Score: " + str(node.get_points()) + "\n"
	set_text(text)
	#var node = get_node("../../Player")
	#var text = "Score: " + str(node.get_points())
	#set_text(text)


