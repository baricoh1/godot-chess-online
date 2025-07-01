extends Node
## MultiplayerManager.gd – Firebase Realtime Database (SSE streaming)

# ───────────────── Firebase constants ─────────────────────────
const FIREBASE_HOST : String = "<your-project-id>.firebaseio.com"  # ← create your own Firebase Realtime DB and paste the host here
const FIREBASE_URL  : String = "https://" + FIREBASE_HOST + "/"

# ───────────────── Scene members ──────────────────────────────
@onready var http : HTTPRequest = HTTPRequest.new()  # REST writes / meta reads

signal move_received(move_data : Dictionary)
signal guest_joined  # 🔔 fired once when status ≠ "empty"

var room_exists      : bool
var game_code        : String
var last_request_type: String
var expected_round   : int = -1  # round we’re waiting for

# ───────────── Streaming members (HTTPClient) ────────────────
var stream      : HTTPClient = HTTPClient.new()
var stream_open : bool       = false
# ─────────────────────────────────────────────────────────────

# ╭──────────────────  LIFECYCLE  ─────────────────────────────╮
func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_request_completed)
# ╰─────────────────────────────────────────────────────────────╯


# ╭───────────────  ROOM MANAGEMENT  ──────────────────────────╮
func create_room(room_code: String) -> void:
	game_code = room_code
	_put("%srooms/%s.json" % [FIREBASE_URL, room_code], {"status": "empty"}, "create")


# Async – returns true if joined successfully, false otherwise
func join_room(code: String) -> bool:
	game_code = code
	var url := "%srooms/%s.json" % [FIREBASE_URL, code]

	# 1) GET existing room meta
	var err := http.request(url)
	if err != OK:
		push_error("HTTP GET failed: %s" % [str(err)])
		return false

	var _http_result = await http.request_completed
	var status_code  = _http_result[1]
	var body         = _http_result[3]
	if status_code != 200:
		push_warning("Room code not found (%d)" % status_code)
		return false

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or data.get("status", "") != "empty":
		push_warning("Room is already occupied")
		return false  # do not join

	# 2) PUT new status to indicate we joined
	var payload := {"status": "One player entered the room"}
	var headers := PackedStringArray(["Content-Type: application/json"])
	err = http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(payload))
	if err != OK:
		push_error("HTTP PUT failed: %s" % [str(err)])
		return false

	await http.request_completed  # wait for PUT response
	return true


# (still available for one-shot checks if you want them elsewhere)
func check_if_waiting(code: String) -> void:
	room_exists = false
	var url := "%srooms/%s.json" % [FIREBASE_URL, code]
	last_request_type = "check"
	http.request(url, [], HTTPClient.METHOD_GET)
# ╰─────────────────────────────────────────────────────────────╯


# ╭────────────────────  SEND MOVE  ───────────────────────────╮
func send_move_to_firebase(from_sq: Vector2i, to_sq: Vector2i, round_num: int) -> void:
	var url := "%srooms/%s.json" % [FIREBASE_URL, game_code]
	var move := {
		"from": {"x": from_sq.x, "y": from_sq.y},
		"to":   {"x": to_sq.x,   "y": to_sq.y},
		"round": round_num
	}
	_put(url, {"status": "occupied", "last_move": move}, "send_move")
# ╰─────────────────────────────────────────────────────────────╯


# ╭───────────────  HOST: WAIT FOR GUEST ──────────────────────╮
func wait_for_guest(room_code: String) -> void:
	if stream_open:
		return
	game_code = room_code

	var tls := TLSOptions.client()
	if stream.connect_to_host(FIREBASE_HOST, 443, tls) != OK:
		push_error("TLS connect failed")
		return
	await _wait_status(HTTPClient.STATUS_CONNECTED)

	var path := "/rooms/%s/status.json?print=silent" % [room_code]
	var hdrs := PackedStringArray(["Accept: text/event-stream"])
	stream.request_raw(HTTPClient.METHOD_GET, path, hdrs, PackedByteArray())
	stream_open = true
# ╰─────────────────────────────────────────────────────────────╯


# ╭────────────── PLAYER: WAIT FOR MOVE ───────────────────────╮
func wait_for_opponent_move(current_round: int) -> Array:
	expected_round = current_round
	_open_move_stream()

	var move: Dictionary = await move_received
	_close_stream()

	var from_v = Vector2i(move["from"]["x"], move["from"]["y"])
	var to_v   = Vector2i(move["to"]["x"],   move["to"]["y"])
	return [from_v, to_v]
# ╰─────────────────────────────────────────────────────────────╯


# ╭────────────── STREAM HELPERS ──────────────────────────────╮
func _open_move_stream() -> void:
	if stream_open:
		return

	var tls := TLSOptions.client()
	if stream.connect_to_host(FIREBASE_HOST, 443, tls) != OK:
		push_error("TLS connect failed")
		return
	await _wait_status(HTTPClient.STATUS_CONNECTED)

	var path := "/rooms/%s/last_move.json?print=silent" % [game_code]
	var hdrs := PackedStringArray(["Accept: text/event-stream"])
	stream.request_raw(HTTPClient.METHOD_GET, path, hdrs, PackedByteArray())
	stream_open = true


func _close_stream() -> void:
	if stream_open:
		stream.close()
		stream_open = false


func _wait_status(target_status: int) -> void:
	while stream.get_status() < target_status:
		stream.poll()
		await get_tree().process_frame
# ╰─────────────────────────────────────────────────────────────╯


# ╭────────────── STREAM READ (status + moves) ────────────────╮
func _process(_delta: float) -> void:
	if not stream_open:
		return

	stream.poll()
	if stream.get_status() != HTTPClient.STATUS_BODY:
		return

	var chunk: PackedByteArray = stream.read_response_body_chunk()
	if chunk.is_empty():
		return

	for raw_line in chunk.get_string_from_utf8().split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("data:"):
			continue

		var json_text := line.substr(5).strip_edges()
		if json_text.is_empty() or json_text == "null":
			continue

		var payload = JSON.parse_string(json_text)
		if payload == null:
			continue

		# 1) STATUS STREAM (host lobby)
		if payload.has("data") and typeof(payload["data"]) == TYPE_STRING:
			var status_str: String = payload["data"]
			if status_str != "empty":
				emit_signal("guest_joined")
				_close_stream()
			continue

		# 2) MOVE STREAM (in-game)
		var move_obj: Dictionary = {}
		if payload.has("data") and typeof(payload["data"]) == TYPE_DICTIONARY:
			move_obj = payload["data"]
		elif typeof(payload) == TYPE_DICTIONARY and payload.has("round"):
			move_obj = payload
		else:
			continue

		if move_obj.has("round") and move_obj["round"] == expected_round + 1:
			emit_signal("move_received", move_obj)
# ╰─────────────────────────────────────────────────────────────╯


# ╭───────────────  REST RESPONSE HANDLER  ────────────────────╮
func _on_request_completed(_res: int, code: int, _hdr: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if last_request_type == "check":
		room_exists = data != null and data.has("status") and data["status"] != "empty"
# ╰─────────────────────────────────────────────────────────────╯


# ╭───────────────  INTERNAL HELPER  ──────────────────────────╮
func _put(url: String, payload: Dictionary, tag: String="") -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify(payload)
	last_request_type = tag
	http.request(url, headers, HTTPClient.METHOD_PUT, body)
# ╰─────────────────────────────────────────────────────────────╯
