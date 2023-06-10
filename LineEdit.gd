extends LineEdit

func _ready():
	grab_focus()

func _on_Button_pressed(new_text):
	print(new_text)
