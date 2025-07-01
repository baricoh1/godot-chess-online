from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)

# Start Stockfish process globally
stockfish = subprocess.Popen(
    ["./stockfish"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    universal_newlines=True,
    bufsize=1
)

# Initialize UCI once
def init_stockfish():
    stockfish.stdin.write("uci\n")
    stockfish.stdin.flush()
    while True:
        line = stockfish.stdout.readline()
        if "uciok" in line:
            break

def get_best_move(fen, elo):
    stockfish.stdin.write("setoption name UCI_LimitStrength value true\n")
    stockfish.stdin.write(f"setoption name UCI_Elo value {elo}\n")
    stockfish.stdin.write(f"position fen {fen}\n")
    stockfish.stdin.write("go movetime 500\n")
    stockfish.stdin.flush()

    while True:
        line = stockfish.stdout.readline().strip()
        if line.startswith("bestmove"):
            return line.split()[1]

@app.route("/", methods=["GET"])
def home():
    return "✔️ Chess Stockfish Server is running!", 200

@app.route("/move", methods=["POST"])
def move():
    data = request.get_json()
    fen = data.get("fen")
    elo = int(data.get("elo", 1500))
    
    if not fen:
        return jsonify({"error": "Missing FEN"}), 400

    move = get_best_move(fen, elo)
    return jsonify({"move": move})

if __name__ == "__main__":
    init_stockfish()
    app.run(host="0.0.0.0", port=8080)

