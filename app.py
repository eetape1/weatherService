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
    print("DEBUG: OPENCAGE_API_KEY = FAILED_DECODING", flush=True)

def get_lat_lon(location):
    """Get latitude and longitude with improved validation."""
    params = {
        "q": location,
        "key": OPENCAGE_API_KEY,
        "limit": 1,  # Limit to 1 result
        "min_confidence": 7 
    }
    
    response = requests.get(OPENCAGE_URL, params=params)
    data = response.json()
    
    if response.status_code != 200:
        return None, None
        
    if not data.get("results"):
        return None, None
        
    result = data["results"][0]
    
    # validation checks
    if (
        result.get("confidence") < 7 or  
        not result.get("components") or 
        result.get("components").get("_type") not in ["city", "town", "village", "state", "country"]  # Must be a valid location type
    ):
        return None, None
        
    return result["geometry"]["lat"], result["geometry"]["lng"]

@app.route("/weather", methods=["GET"])
def get_weather():
    location = request.args.get("location")
    if not location:
        return jsonify({"error": "Location parameter is required"}), 400

    # Get latitude and longitude
    latitude, longitude = get_lat_lon(location)
    if latitude is None or longitude is None:
        return jsonify({"error": "Invalid location"}), 404

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
