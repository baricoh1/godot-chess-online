extends Node

@onready var http := $HTTPRequest

# Calls your cloud Stockfish bot and returns the best move as String
# Replace the URL below with your own Render-deployed Stockfish server
# (You can find the deployment script in the 'stockfish-server' folder of this repo)
func get_best_move_from_server(fen: String, elo: int) -> String:
	var url = "https://<your-render-stockfish-server-url>/move"  # ← replace this with your own
	var headers = ["Content-Type: application/json"]
	var body = {
		"fen": fen,
		"elo": elo
	}
	var json_data = JSON.stringify(body)

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_data)
	if err != OK:
		push_error("❌ HTTP request failed: %s" % err)
		return "0000"  # fallback move

	var result = await http.request_completed
	var response_code = result[1]
	var response_data = result[3].get_string_from_utf8()

	if response_code == 200:
		print("📦 Raw response from server:", response_data)
		var json = JSON.parse_string(response_data)
		if json and typeof(json) == TYPE_DICTIONARY and json.has("move"):
			var move = json["move"]
			print("✅ Best move from server:", move)
			return move
		else:
			print("❌ Invalid or missing 'move' in server response")
	else:
		print("❌ Server returned error:", response_code)

	return "0000"  # fallback
