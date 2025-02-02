import os
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

# OpenCage & Open Meteo API endpoint for geocoding
OPENCAGE_URL = "https://api.opencagedata.com/geocode/v1/json"
OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
OPENCAGE_API_KEY = os.getenv("OPENCAGE_API_KEY")

# Decode the base64-encoded API key from the environment variable
try:
    OPENCAGE_API_KEY = base64.b64decode(os.getenv("OPENCAGE_API_KEY", "")).decode('utf-8')
    print("Decoding Successful!", flush=True)
    
except Exception as e:
    print(f"DEBUG: OPENCAGE_API_KEY = {OPENCAGE_API_KEY}", flush=True)

def get_lat_lon(location):
    # Query OpenCage API to get latitude and longitude
    params = {
        "q": location,
        "key": OPENCAGE_API_KEY,
    }
    response = requests.get(OPENCAGE_URL, params=params)
    data = response.json()

    if response.status_code == 200 and data["results"]:
        lat = data["results"][0]["geometry"]["lat"]
        lon = data["results"][0]["geometry"]["lng"]
        return lat, lon
    else:
        return None, None

@app.route("/weather", methods=["GET"])
def get_weather():
    location = request.args.get("location")
    if not location:
        return jsonify({"error": "Location parameter is required"}), 400

    # Get latitude and longitude
    latitude, longitude = get_lat_lon(location)
    if latitude is None or longitude is None:
        #return jsonify({"error": "Invalid location"}), 404
        return jsonify({"error": "Invalid location","key": OPENCAGE_API_KEY}), 404

    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current_weather": "true",
    }

    try:
        response = requests.get(OPEN_METEO_URL, params=params)
        data = response.json()

        if response.status_code == 200 and "current_weather" in data:
            weather = data["current_weather"]
            return jsonify({
                "location": location,
                "temperature": weather["temperature"],
                "condition": weather["weathercode"],  # Weather Condtion Code
            })
        else:
            return jsonify({"error": "Weather data not available"}), 404
    except requests.exceptions.RequestException as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
