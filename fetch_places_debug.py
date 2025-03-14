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

def make_api_request(url, params, retry_count=3, retry_delay=2):
    """
    Make an API request with retry logic and detailed error handling
    
    Args:
        url (str): API endpoint URL
        params (dict): Query parameters
        retry_count (int): Number of retry attempts
        retry_delay (int): Seconds to wait between retries
        
    Returns:
        tuple: (response_data, error_message)
    """
    for attempt in range(retry_count):
        try:
            logger.debug(f"Making API request to {url}")
            logger.debug(f"Request params: {json.dumps({k: v if k != 'key' else '[REDACTED]' for k, v in params.items()})}")
            
            response = requests.get(url, params=params, timeout=30)
            
            # Log the response status
            logger.debug(f"Response status code: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()

                with open(f"bars_{location.replace(' ', '_')}_raw.json", "w") as f:
                    json.dump(data, f, indent=2)
                    print(f"Raw data also saved to bars_{location.replace(' ', '_')}_raw.json")
                
                # Check for API-level errors
                if data.get('status') != 'OK' and data.get('status') != 'ZERO_RESULTS':
                    error_msg = f"API error: {data.get('status')} - {data.get('error_message', 'No error message')}"
                    logger.error(error_msg)
                    # If we hit a quota or auth error, no point retrying
                    if data.get('status') in ['OVER_QUERY_LIMIT', 'REQUEST_DENIED', 'INVALID_REQUEST']:
                        return None, error_msg
                else:
                    # Success!
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
    Fetch bars for a specific location using Google Places API
    
    Args:
        location (str): City or area name (e.g., "Paris 17th arrondissement")
        country (str): Country name for better accuracy
        max_results (int): Maximum number of results to return
        debug_mode (bool): Whether to print detailed debug information
        
    Returns:
        list: List of bar details
    """
    logger.info(f"Fetching bars in {location}, {country}...")
    
    # Use Places API Text Search to find bars in the location
    search_query = f"bars in {location}, {country}"
    base_url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
    params = {
        "query": search_query,
        "type": "bar",
        "key": GOOGLE_MAPS_API_KEY,
        "rankby": "prominence",  # To get the most popular places
    }
    
    search_results = []
    next_page_token = None
    
    # Fetch initial results
    data, error = make_api_request(base_url, params)
    
    if error:
        logger.error(f"Initial search failed: {error}")
        return []
    
    if debug_mode:
        # Save raw API response for debugging
        with open(f"debug_initial_response_{location.replace(' ', '_')}.json", "w") as f:
            json.dump(data, f, indent=2)
    
    # Add results to our list
    results = data.get("results", [])
    logger.info(f"Initial search returned {len(results)} results")
    search_results.extend(results)
    next_page_token = data.get("next_page_token")
    
    # Fetch additional pages if available (up to max_results places)
    page_count = 1
    while next_page_token and len(search_results) < max_results and page_count < 3:  # Google usually limits to 3 pages
        logger.info(f"Fetching page {page_count + 1} of results...")
        # Google API requires a delay before using next_page_token
        time.sleep(2)
        
        params = {
            "key": GOOGLE_MAPS_API_KEY,
            "pagetoken": next_page_token
        }
        
        data, error = make_api_request(base_url, params)
        
        if error:
            logger.error(f"Failed to fetch additional page: {error}")
            break
        
        if debug_mode:
            # Save raw API response for debugging
            with open(f"debug_page{page_count + 1}_response_{location.replace(' ', '_')}.json", "w") as f:
                json.dump(data, f, indent=2)
        
        results = data.get("results", [])
        logger.info(f"Page {page_count + 1} returned {len(results)} results")
        search_results.extend(results)
        next_page_token = data.get("next_page_token")
        page_count += 1
    
    # Limit to top max_results based on ratings and reviews
    if len(search_results) > max_results:
        # Sort by a combination of rating and popularity
        search_results = sorted(
            search_results, 
            key=lambda x: (x.get("rating", 0) * x.get("user_ratings_total", 0)), 
            reverse=True
        )[:max_results]
    
    bars_detailed = []
    successful = 0
    failed = 0
    
    # Get detailed information for each place
    logger.info(f"Fetching details for {len(search_results)} places...")
    for i, place in enumerate(search_results):
        place_id = place.get("place_id")
        logger.info(f"Processing place {i+1}/{len(search_results)}: {place.get('name', 'Unknown')} (ID: {place_id})")
        
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
    Get detailed information for a specific place
    
    Args:
        place_id (str): Google Place ID
        debug_mode (bool): Whether to print detailed debug information
    
    Returns:
        dict: Structured place details or None on failure
    """
    base_url = "https://maps.googleapis.com/maps/api/place/details/json"
    params = {
        "place_id": place_id,
        "key": GOOGLE_MAPS_API_KEY,
        "fields": "place_id,name,formatted_address,geometry,opening_hours,rating,user_ratings_total"
    }
    
    data, error = make_api_request(base_url, params)
    
    if error:
        logger.error(f"Failed to get details for place {place_id}: {error}")
        return None
    
    if debug_mode:
        # Save raw API response for debugging
        with open(f"debug_place_details_{place_id}.json", "w") as f:
            json.dump(data, f, indent=2)
    
    result = data.get("result", {})
    
    if not result:
        logger.warning(f"No details found for place {place_id}")
        return None
    
    # Extract and format place details
    try:
        place_details = {
            "google_place_id": result.get("place_id", ""),
            "name": result.get("name", ""),
            "address": result.get("formatted_address", ""),
            "latitude": result.get("geometry", {}).get("location", {}).get("lat", 0),
            "longitude": result.get("geometry", {}).get("location", {}).get("lng", 0),
            "availability": format_opening_hours(result.get("opening_hours", {}))
        }
        
        logger.debug(f"Successfully extracted details for {place_details['name']}")
        return place_details
        
    except Exception as e:
        logger.error(f"Error parsing place details for {place_id}: {str(e)}")
        logger.debug(traceback.format_exc())
        return None

def format_opening_hours(opening_hours):
    """
    Format opening hours into the required JSON structure
    
    Args:
        opening_hours (dict): Opening hours data from Google Places API
    
    Returns:
        dict: Formatted availability object
    """
    # Default closed schedule
    default_hours = {"start": "00:00", "end": "00:00"}
    
    # Initialize all days as closed
    availability = {
        "monday": default_hours.copy(),
        "tuesday": default_hours.copy(),
        "wednesday": default_hours.copy(),
        "thursday": default_hours.copy(),
        "friday": default_hours.copy(),
        "saturday": default_hours.copy(),
        "sunday": default_hours.copy(),
    }
    
    # If we have opening hours data, update the availability
    if opening_hours and "periods" in opening_hours:
        for period in opening_hours.get("periods", []):
            # Google uses 0 = Sunday, 1 = Monday, etc.
            # Convert to lowercase day names
            day_map = {
                0: "sunday",
                1: "monday",
                2: "tuesday",
                3: "wednesday",
                4: "thursday",
                5: "friday",
                6: "saturday"
            }
            
            # Get open and close info
            open_info = period.get("open", {})
            close_info = period.get("close", {})
            
            # Skip if we don't have both open and close info
            if not open_info:
                continue
                
            day_num = open_info.get("day")
            day_name = day_map.get(day_num)
            
            # Handle cases where a place might be open 24 hours
            # In that case, there might not be a close time
            if day_name:
                # Format time from "1045" to "10:45"
                open_time = open_info.get("time", "0000")
                formatted_open = f"{open_time[:2]}:{open_time[2:]}"
                
                # If we have close info, use it; otherwise default to "23:59"
                if close_info:
                    close_time = close_info.get("time", "0000")
                    formatted_close = f"{close_time[:2]}:{close_time[2:]}"
                else:
                    formatted_close = "23:59"  # Assume open until midnight if no closing time
                
                availability[day_name] = {
                    "start": formatted_open,
                    "end": formatted_close
                }
    
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