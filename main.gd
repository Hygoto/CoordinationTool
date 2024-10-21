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
	print(Engine.get_copyright_info())

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
				if !json.data.has("playlistTitle"):
					json.data["playlistTitle"] = f.get_path().get_file().get_basename()
				$OptionButton.add_item(json.data["playlistTitle"])
				if !check_playlist():
					$OptionButton.set_item_disabled($OptionButton.get_item_count()-1, true)
					$OptionButton.set_item_tooltip($OptionButton.get_item_count()-1, "The playlist is missing at least 1 required property.")
				else:
					create_pickorder()
			else:
				print("JSON Parse Error: ", json.get_error_message(), " in ", f.get_path(), " at line ", json.get_error_line())
				print(json.data)
		elif file == "":
			break
	if pools.size() < 1:
		$OptionButton.disabled = true
		$OptionButton.add_theme_color_override("font_disabled_color", Color.RED)
		$OptionButton.add_item("no mappools found")
	else:
		$OptionButton.disabled = false
		select_pool(pools[selected_pool])

func check_playlist():
	var playlist = pools[pools.size()-1]
	if !playlist.has("songs") || typeof(playlist["songs"]) != TYPE_ARRAY:
		return false
	var i = 0
	for song in playlist["songs"]:
		if !song.has("songName"):
			return false
		if !song.has("customData") || typeof(song["customData"]) != TYPE_DICTIONARY:
			pools[pools.size()-1]["songs"][i]["customData"] = {"type": ""}
		elif !song["customData"].has("type"):
			pools[pools.size()-1]["songs"][i]["customData"]["type"] = ""
		if !song.has("hash"):
			pools[pools.size()-1]["songs"][i]["hash"] = ""
		if !song.has("difficulties") || typeof(song["difficulties"]) != TYPE_ARRAY:
			pools[pools.size()-1]["songs"][i]["difficulties"] = [{"name": ""}]
		elif song["difficulties"].size() < 1 || typeof(song["difficulties"][0]) != TYPE_DICTIONARY:
			pools[pools.size()-1]["songs"][i]["difficulties"][0] = {"name": ""}
		elif !song["difficulties"][0].has("name"):
			pools[pools.size()-1]["songs"][i]["difficulties"][0]["name"] = ""
		elif !song.has("levelAuthorName"):
			pools[pools.size()-1]["songs"][i]["levelAuthorName"] = ""
		i += 1
	return true

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
	covers_downloading = covers_downloading - 1
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
		map.set_vars(song["hash"], song["songName"], song["customData"]["type"], song["difficulties"][0]["name"], "user://covers/" + song["hash"].to_lower() + ".jpg",song["levelAuthorName"])
	var players = get_player_names()
	for action in pool["customData"]["pickorder"]:
		if action["type"] != "tiebreaker":
			$PickorderList.add_item(players[action["player"]-1] + " " + action["type"] + ":   ", null, false)
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
	$Player1.emit_signal("text_changed", "")


func _on_randomize_players_pressed():
	if randi() % 2 == 1:
		_on_switch_players_pressed()

func _on_map_chosen(map):
	var action = pools[selected_pool]["customData"]["pickorder"][picks.size()]
	$PickorderList.deselect_all()
	if picks.size() + 1 < $PickorderList.get_item_count():
		$PickorderList.set_item_selectable(picks.size()+1, true)
		$PickorderList.select(picks.size()+1)
		$PickorderList.set_item_selectable(picks.size()+1, false)
	$PickorderList.set_item_text(picks.size(), $PickorderList.get_item_text(picks.size()) + map.title)
	var text
	map.disabled = true
	if action["type"] != "tiebreaker":
		picks.push_back({"type": action["type"], "player": action["player"], "map": map})
		var players = get_player_names()
		text = players[picks.back()["player"]-1] + " " + picks.back()["type"] + "s " + picks.back()["map"].title
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
			var players = get_player_names()
			$PickorderList.set_item_text(picks.size(), players[action["player"]-1] + " " + action["type"] + ":   ")
		else:
			$PickorderList.set_item_text(picks.size(), "tiebreaker:   ")



func _on_copy_list_to_clipboard_pressed():
	var players = get_player_names()
	var text = ""
	for pick in picks:
		if pick["type"] != "tiebreaker":
			text = text + "\n" + players[pick["player"]-1] + " " + pick["type"] + "s " + pick["map"].title
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


func _on_player_text_changed(new_text):
	var players = get_player_names()
	var i = 0
	for action in pools[selected_pool]["customData"]["pickorder"]:
		if action["type"] != "tiebreaker":
			var text = players[action["player"]-1] + " " + action["type"] + ":   "
			if picks.size() > i:
				text += picks[i]["map"].title
			$PickorderList.set_item_text(i, text)
		i = i + 1

func get_player_names():
	var players = [$Player1.text, $Player2.text]
	if players[0].strip_edges() == "":
		players[0] = "Player 1"
	if players[1].strip_edges() == "":
		players[1] = "Player 2"
	return players
