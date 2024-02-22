extends Control

@export var map_button: PackedScene
var pools = []
var selected_pool = 0
var picks = []
var covers_downloading = 0
const colors = {"pick": Color.GREEN, "ban": Color.RED, "tiebreaker": Color.BLUE}

# Called when the node enters the scene tree for the first time.
func _ready():
	DirAccess.make_dir_absolute("user://covers")
	DirAccess.make_dir_absolute("./pools")
	load_pools()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func load_pools():
	pools.clear()
	$OptionButton.clear()
	var dir = DirAccess.open("./pools")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file.ends_with(".bplist"):
			var f = FileAccess.open("./pools/" + file, FileAccess.READ)
			var content = f.get_as_text()
			var json = JSON.new()
			var error = json.parse(content)
			if error == OK:
				pools.push_back(json.data)
				$OptionButton.add_item(json.data["playlistTitle"])
				create_pickorder()
			else:
				print("JSON Parse Error: ", json.get_error_message(), " in ", "/home/hygoto/Downloads/Tech.bplist", " at line ", json.get_error_line())
				print(json.data)
		elif file == "":
			break
	if pools.size() < 1:
		$OptionButton.disabled = true
		$OptionButton.add_theme_color_override("font_disabled_color", Color.RED)
		$OptionButton.add_item("no mappools found")
	else:
		select_pool(pools[selected_pool])

func _on_download_map_covers_pressed():
	for pool in pools:
		covers_downloading += pool["songs"].size()
		for song in pool["songs"]:
			var request = HTTPRequest.new()
			add_child(request)
			request.request_completed.connect(self._on_image_downloaded)
			request.set_download_file("user://covers/" + song["hash"].to_lower() + ".jpg")
			request.request("https://cdn.beatsaver.com/" + song["hash"].to_lower() + ".jpg")

func _on_image_downloaded(result, response_code, headers, body):
	if covers_downloading == 0:
		select_pool(pools[selected_pool])

func select_pool(pool):
	get_tree().call_group("maps", "queue_free")
	picks.clear()
	$PickorderList.clear()
	var map
	for song in  pool["songs"]:
		map = map_button.instantiate()
		$MarginContainer/SCMaps/MCsad/GCMaps.add_child(map)
		map.pressed.connect(self._on_map_chosen.bind(map))
		map.set_vars(song["hash"], song["songName"], song["customData"]["type"], song["difficulties"][0]["name"], "user://covers/" + song["hash"].to_lower() + ".jpg")
	for action in pool["customData"]["pickorder"]:
		if action["type"] != "tiebreaker":
			$PickorderList.add_item("Player " + str(action["player"]) + " " + action["type"] + ":   ", null, false)
		else:
			$PickorderList.add_item("tiebreaker:   ", null, false)
	$PickorderList.set_item_selectable(0, true)
	$PickorderList.select(0)
	$PickorderList.set_item_selectable(0, false)

func _unhandled_input(event):
	if event.is_action_pressed("undo"):
		_on_undo_pressed()

func _on_option_button_item_selected(index):
	selected_pool = index
	select_pool(pools[selected_pool])


func _on_switch_players_pressed():
	var tmp = $Player1.text
	$Player1.text = $Player2.text
	$Player2.text = tmp


func _on_randomize_players_pressed():
	if randi() % 2 == 1:
		_on_switch_players_pressed()

func _on_map_chosen(map):
	var action = pools[selected_pool]["customData"]["pickorder"][picks.size()]
	$PickorderList.deselect_all()
	$PickorderList.set_item_selectable(picks.size()+1, true)
	$PickorderList.select(picks.size()+1)
	$PickorderList.set_item_selectable(picks.size()+1, false)
	$PickorderList.set_item_text(picks.size(), $PickorderList.get_item_text(picks.size()) + map.title)
	var text
	map.disabled = true
	if action["type"] != "tiebreaker":
		picks.push_back({"type": action["type"], "player": action["player"], "map": map})
		text = get_node("Player" + str(picks.back()["player"])).text + " " + picks.back()["type"] + "s " + picks.back()["map"].title
	else:
		picks.push_back({"type": "tiebreaker", "map": map})
		text = "tiebreaker: " + picks.back()["map"].title
	if $CopyToClipboard.button_pressed:
		DisplayServer.clipboard_set(text)
	map.set_title_color(colors[action["type"]])
	print(text)


func _on_undo_pressed():
	if picks.size() > 0:
		picks.back()["map"].disabled = false
		picks.back()["map"].remove_title_color()
		picks.pop_back()
		$PickorderList.deselect_all()
		$PickorderList.set_item_selectable(picks.size(), true)
		$PickorderList.select(picks.size())
		$PickorderList.set_item_selectable(picks.size(), false)
		var action = pools[selected_pool]["customData"]["pickorder"][picks.size()]
		if action["type"] != "tiebreaker":
			$PickorderList.set_item_text(picks.size(), "Player " + str(action["player"]) + " " + action["type"] + ":   ")
		else:
			$PickorderList.set_item_text(picks.size(), "tiebreaker:   ")



func _on_copy_list_to_clipboard_pressed():
	var text = ""
	for pick in picks:
		if pick["type"] != "tiebreaker":
			text = text + "\n" + get_node("Player" + str(pick["player"])).text + " " + pick["type"] + "s " + pick["map"].title
		else:
			text = text + "\ntiebreaker: " + pick["map"].title
	text = text.strip_edges()
	DisplayServer.clipboard_set(text)

func create_pickorder():
	if !pools.back().has("customData") || !pools.back()["customData"].has("pickorder") || pools.back()["customData"]["pickorder"].size() < pools.back()["songs"].size():
		var pickorder = []
		for n in pools.back()["songs"].size():
			match n % 4:
				0:
					pickorder.push_back({"type": "ban", "player": 2})
				1:
					pickorder.push_back({"type": "ban", "player": 1})
				2:
					pickorder.push_back({"type": "pick", "player": 1})
				3:
					pickorder.push_back({"type": "pick", "player": 2})
		if pickorder.size() == pools.back()["songs"].size() && pickorder.size() % 2 != 0:
			pickorder.pop_back()
			pickorder.push_back({"type": "tiebreaker"})
		if !pools.back().has("customData"):
			pools.back()["customData"] = {}
		pools.back()["customData"]["pickorder"] = pickorder
