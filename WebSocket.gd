extends VBoxContainer

var websocket = WebSocketPeer.new()
var players = {}
var scores = {}
var score_changed = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_connect_pressed():
	websocket.connect_to_url("ws://127.0.0.1:2948/socket")
	$GridContainer/Connect.text = "connected"
	$GridContainer/Connect.disabled = true
	$PollWS.start()

func display_scores():
	$ScoreList.clear()
	for score in scores:
		$ScoreList.add_item(players[str(score)] + ":     " + str(round(scores[str(score)]["Accuracy"] * 10000) / 100) + "%   -   " + str(scores[str(score)]["Score"]))

func _on_poll_ws_timeout():
	websocket.poll()
	var state = websocket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while websocket.get_available_packet_count():
			var packet = JSON.parse_string(websocket.get_packet().get_string_from_utf8())
			print("Packet: ", packet)
			if packet["_type"] == "event" && packet["_event"] == "PlayerJoined":
				players[str(packet["PlayerJoined"]["LUID"])] = packet["PlayerJoined"]["UserName"]
			#There is no reason not to keep data on every player that joined the room. This way you can still resolve their name if they leave right after finishing the map.
			#elif packet["_type"] == "event" && packet["_event"] == "PlayerLeaved":
				# WHY THE FUCK IS THAT EVENT CALLED PlayerLEAVED?
				#players.erase(packet["PlayerLeaved"]["LUID"])
			elif packet["_type"] == "event" && packet["_event"] == "RoomLeaved":
				players.clear()
			elif packet["_type"] == "event" && packet["_event"] == "RoomState" && packet["RoomState"] == "WarmingUp":
				$ScoreList.clear()
				scores.clear()
			elif packet["_type"] == "event" && packet["_event"] == "Score":
				if packet["Score"]["Score"] != 0:
					scores[str(packet["Score"]["LUID"])] = packet["Score"]
					score_changed = true
		if score_changed:
			score_changed = false
			display_scores()
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = websocket.get_close_code()
		var reason = websocket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		$PollWS.stop()
		$GridContainer/Connect.text = "connect to websocket"
		$GridContainer/Connect.disabled = false


func _on_copy_scores_pressed():
	var text = ""
	for score in scores:
		text = text + players[str(score)] + ": " + str(round(scores[str(score)]["Accuracy"] * 10000) / 100) + "% " + str(scores[str(score)]["Score"]) + "\n"
	text.strip_edges()
	DisplayServer.clipboard_set(text)
