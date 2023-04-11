extends Label


func _ready():
	pass # Replace with function body.

func _process(delta):
	var node = get_node("../../Player")
	var text = "Score: " + str(node.get_points())
	set_text(text)


