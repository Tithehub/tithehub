from flask import Flask, request, jsonify

app = Flask(__name__)

# Simple health check
@app.route("/", methods=["GET"])
def home():
    return "TitheHub Flask app is running ✅", 200

# Example webhook or API endpoint
@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True)
    print(f"📩 Webhook received: {data}")
    return jsonify({"status": "success", "received": data}), 200

if __name__ == "__main__":
    print("🚀 Starting TitheHub app for user: @tithehub")
    app.run(host="0.0.0.0", port=5000)
