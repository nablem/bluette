import os
import json
import requests
import logging
import time
from datetime import datetime
from dotenv import load_dotenv
import traceback
from supabase import create_client

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f"bars_fetcher_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('google_maps_bars_fetcher')

# Load environment variables
load_dotenv()
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
# Validate environment variables
if not GOOGLE_MAPS_API_KEY:
    logger.error("Missing GOOGLE_MAPS_API_KEY in .env file")
    raise EnvironmentError("Missing GOOGLE_MAPS_API_KEY in .env file")
if not SUPABASE_URL or not SUPABASE_ANON_KEY:
    logger.error("Missing Supabase credentials in .env file")
    raise EnvironmentError("Missing Supabase credentials in .env file")

def make_api_request(url, headers, data=None, retry_count=1, retry_delay=2, method="POST"):
    """
    Make an API request with retry logic and detailed error handling using POST.

    Args:
        url (str): API endpoint URL
        headers (dict): Request headers
        data (dict): Request payload (JSON)
        retry_count (int): Number of retry attempts
        retry_delay (int): Seconds to wait between retries

    Returns:
        tuple: (response_data, error_message)
    """
    for attempt in range(retry_count):
        try:
            logger.debug(f"Making API request to {url}")
            if data:
                logger.debug(f"Request data: {json.dumps(data)}")

            if data:
                if method == "POST":
                    response = requests.post(url, headers=headers, json=data, timeout=30)
                else:
                    response = requests.get(url, headers=headers, timeout=30)
            else:
                if method == "POST":
                    response = requests.post(url, headers=headers, timeout=30)
                else:
                    response = requests.get(url, headers=headers, timeout=30)
            
            # Log the response status
            logger.debug(f"Response status code: {response.status_code}")

            if response.status_code == 200:
                data = response.json()

                return data, None
            else:
                logger.error(f"HTTP error: {response.status_code}")
                logger.debug(f"Response content: {response.text[:500]}...")

        except requests.RequestException as e:
            logger.error(f"Request failed: {str(e)}")

        # Only retry if we haven't reached max attempts
        if attempt < retry_count - 1:
            logger.info(f"Retrying in {retry_delay} seconds... (Attempt {attempt + 1}/{retry_count})")
            time.sleep(retry_delay)

    return None, f"Failed after {retry_count} attempts"

def fetch_bars(location, country, max_results=30, debug_mode=False):
    """
    Fetch bars for a specific location using Google Places API (searchText).

    Args:
        location (str): City or area name (e.g., "Paris 17th arrondissement")
        country (str): Country name for better accuracy
        max_results (int): Maximum number of results to return (not directly applicable here, as API returns best matches)
        debug_mode (bool): Whether to print detailed debug information

    Returns:
        list: List of bar details
    """
    logger.info(f"Fetching bars in {location}, {country}...")

    # Use Places API searchText to find bars in the location
    search_query = f"bars in {location}, {country}"
    base_url = "https://places.googleapis.com/v1/places:searchText"
    headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_MAPS_API_KEY,
        'X-Goog-FieldMask': 'places.displayName,places.shortFormattedAddress,places.id,places.location'
    }
    data = {
        "textQuery": search_query
    }

    search_results = []
    data_response, error = make_api_request(base_url, headers, data)

    if error:
        logger.error(f"Initial search failed: {error}")
        return []

    if debug_mode:
        # Save raw API response for debugging
        with open(f"debug_initial_response_{location.replace(' ', '_')}.json", "w") as f:
            json.dump(data_response, f, indent=2)

    # Add results to our list
    results = data_response.get("places", [])
    logger.info(f"Initial search returned {len(results)} results")
    search_results.extend(results)

    bars_detailed = []
    successful = 0
    failed = 0

    # Get detailed information for each place
    logger.info(f"Fetching details for {len(search_results)} places...")
    for i, place in enumerate(search_results):
        place_id = place.get("id")
        logger.info(f"Processing place {i+1}/{len(search_results)}: {place.get('displayName', {}).get('text', 'Unknown')} (ID: {place_id})")

        place_details = get_place_details(place_id, debug_mode)
        if place_details:
            bars_detailed.append(place_details)
            successful += 1
        else:
            failed += 1

    logger.info(f"Completed processing {len(search_results)} places")
    logger.info(f"Successfully retrieved details for {successful} places")
    logger.info(f"Failed to retrieve details for {failed} places")

    return bars_detailed

def get_place_details(place_id, debug_mode=False):
    """
    Get detailed information for a specific place using Place Details (v1).

    Args:
        place_id (str): Google Place ID
        debug_mode (bool): Whether to print detailed debug information

    Returns:
        dict: Structured place details or None on failure
    """
    base_url = f"https://places.googleapis.com/v1/places/{place_id}"
    headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_MAPS_API_KEY,
        'X-Goog-FieldMask': 'id,shortFormattedAddress,regularOpeningHours,googleMapsUri,location,displayName,timeZone'
    }

    data, error = make_api_request(base_url, headers, method="GET")

    if error:
        logger.error(f"Failed to get details for place {place_id}: {error}")
        return None

    if debug_mode:
        # Save raw API response for debugging
        with open(f"debug_place_details_{place_id}.json", "w") as f:
            json.dump(data, f, indent=2)

    if not data:
        logger.warning(f"No details found for place {place_id}")
        return None

    # Extract and format place details
    try:
        place_details = {
            "google_place_id": data.get("id", ""),
            "name": data.get("displayName", {}).get("text", ""),
            "address": data.get("shortFormattedAddress", ""),
            "latitude": data.get("location", {}).get("latitude", 0),
            "longitude": data.get("location", {}).get("longitude", 0),
            "availability": format_opening_hours(data.get("regularOpeningHours", {})),
            "google_maps_uri": data.get("googleMapsUri", ""),
            "timezone": data.get("timeZone", {}).get("id", "")
        }

        logger.debug(f"Successfully extracted details for {place_details['name']}")
        return place_details

    except Exception as e:
        logger.error(f"Error parsing place details for {place_id}: {str(e)}")
        logger.debug(traceback.format_exc())
        return None

def format_opening_hours(opening_hours):
    """
    Formats opening hours into the required JSON structure.

    - Removes the arrays, format is 'day': {'start': 'HH:MM', 'end': 'HH:MM'}.
    - If multiple periods for the same day, selects earliest start/latest end.
    - If a closing time is on the *next* day, the current day ends at 23:59,
      and the next day's hours are determined *solely* by its own opening
      times (if any).  Next-day closing times do NOT create 00:00 entries.
    - Only includes days with actual opening hours.

    Args:
        opening_hours (dict): Opening hours data from Google Places API.

    Returns:
        dict: Formatted availability object. Omitted days are fully closed.
    """

    availability = {}

    day_map = {
        0: "sunday",
        1: "monday",
        2: "tuesday",
        3: "wednesday",
        4: "thursday",
        5: "friday",
        6: "saturday",
    }

    if opening_hours and "periods" in opening_hours:
        for period in opening_hours.get("periods", []):
            open_info = period.get("open", {})
            close_info = period.get("close", {})

            if not open_info:
                continue

            open_day_num = open_info.get("day")
            open_day_name = day_map.get(open_day_num)

            if open_day_name:
                open_hour = open_info.get("hour", 0)
                open_minute = open_info.get("minute", 0)
                formatted_open = f"{open_hour:02}:{open_minute:02}"

                if close_info:
                    close_day_num = close_info.get("day")
                    close_hour = close_info.get("hour", 0)
                    close_minute = close_info.get("minute", 0)
                    formatted_close = f"{close_hour:02}:{close_minute:02}"

                    if close_day_num == open_day_num:
                        # Same day closing. Keep earliest start, latest close.
                        if open_day_name not in availability:
                            availability[open_day_name] = {"start": formatted_open, "end": formatted_close}
                        else:
                            availability[open_day_name]["start"] = min(availability[open_day_name]["start"], formatted_open)
                            availability[open_day_name]["end"] = max(availability[open_day_name]["end"], formatted_close)

                    elif close_day_num == (open_day_num + 1) % 7:
                        # Next-day closing.  Set current day to 23:59,
                        # and *ignore* the closing time for the *next* day's hours.
                        if open_day_name not in availability:
                             availability[open_day_name] = {"start": formatted_open, "end": "23:59"}
                        else:
                            availability[open_day_name]["start"] = min(availability[open_day_name]["start"], formatted_open)
                            availability[open_day_name]["end"] = "23:59" #set the current day closing hour at 23:59
                        continue #ignore period

                    else:  # should not happen
                        continue
                else:
                    # No closing time, assume open until 23:59
                    formatted_close = "23:59"
                    if open_day_name not in availability:
                        availability[open_day_name] = {"start": formatted_open, "end": formatted_close}
                    else:
                        availability[open_day_name]["start"] = min(availability[open_day_name]["start"], formatted_open)
                        availability[open_day_name]["end"] = max(availability[open_day_name]["end"], formatted_close)

    return availability

def store_in_supabase(places):
    """
    Store place data in Supabase
    
    Args:
        places (list): List of place details
    
    Returns:
        bool: Success status
    """
    if not places:
        logger.warning("No places to store in Supabase")
        return False
        
    try:
        # Initialize Supabase client
        logger.info("Connecting to Supabase...")
        supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        
        success_count = 0
        error_count = 0
        
        # Store each place
        logger.info(f"Attempting to store {len(places)} places in Supabase...")
        for place in places:
            try:
                # Validate required fields
                if not place["google_place_id"] or not place["name"]:
                    logger.warning(f"Skipping place with missing required fields: {place}")
                    error_count += 1
                    continue
                    
                # Convert availability to JSONB string
                place_data = place.copy()
                
                # Supabase handles the conversion to JSONB
                # No need to convert to string with json.dumps()
                
                # Upsert (insert or update) the place into the "places" table
                # Using google_place_id as the unique identifier
                logger.debug(f"Storing place: {place_data['name']}")
                response = supabase.table("places").upsert(
                    place_data, 
                    on_conflict="google_place_id"
                ).execute()
                
                # Check for errors
                if hasattr(response, 'error') and response.error:
                    logger.error(f"Error storing {place_data['name']}: {response.error}")
                    error_count += 1
                else:
                    success_count += 1
                    
            except Exception as e:
                logger.error(f"Error processing place for Supabase: {str(e)}")
                logger.debug(traceback.format_exc())
                error_count += 1
        
        logger.info(f"Successfully stored {success_count} places in Supabase")
        if error_count > 0:
            logger.warning(f"Failed to store {error_count} places")
        
        return success_count > 0
    
    except Exception as e:
        logger.error(f"Error connecting to Supabase: {str(e)}")
        logger.debug(traceback.format_exc())
        return False

def main():
    """Main function to run the script"""
    # Get location from user input
    # location = input("Enter city or area (e.g., 'Paris 17th arrondissement'): ")
    # country = "input("Enter country (e.g., 'France'): ")"
    location = os.getenv("LOCATION")
    country = os.getenv("COUNTRY")
    
    # Fetch bars from Google Maps API
    bars = fetch_bars(location, country)
    
    if bars:
        # Store data in Supabase
        store_in_supabase(bars)
        
        # Optional: Save as JSON file for reference
        with open(f"bars_{location.replace(' ', '_')}.json", "w") as f:
            json.dump(bars, f, indent=2)
            print(f"Data also saved to bars_{location.replace(' ', '_')}.json")
    else:
        print("No bars found or error occurred.")

if __name__ == "__main__":
    main()