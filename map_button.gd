extends Button

var title
var category
var diff
var cover
var map_hash

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_vars(new_hash, new_title, new_category, new_diff, new_cover):
	map_hash = new_hash
	title = new_title
	category = new_category
	diff = new_diff
	if FileAccess.file_exists(new_cover):
		cover = ImageTexture.create_from_image(Image.load_from_file(new_cover))
	$Title.text = title
	$Category.text = category
	$Diff.text = diff
	$Cover.texture = cover

func set_title_color(color):
	$Title.add_theme_color_override("font_color", color)

func remove_title_color():
	$Title.remove_theme_color_override("font_color")
