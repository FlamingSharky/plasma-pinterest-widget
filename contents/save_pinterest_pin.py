#!/usr/bin/env python3
"""
Pinterest Pin Saver Script
Saves a pin to your Pinterest profile using the pin ID
"""

import requests
import json
import sys
import argparse
import os
from urllib.parse import quote

def load_pinterest_session():
    """Load Pinterest session data from file (same as fetchpinterest.py)"""
    config_file = os.path.expanduser("~/.config/pinterest_widget_auth.json")

    if not os.path.exists(config_file):
        return None, None

    try:
        with open(config_file, 'r') as f:
            auth_data = json.load(f)

        cookies = auth_data.get('cookies', {})
        auth_headers = auth_data.get('headers', {})
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json, text/javascript, */*, q=0.01',
            'Accept-Language': 'en-US,en;q=0.9',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://www.pinterest.com/',
            'Origin': 'https://www.pinterest.com',
            'Connection': 'keep-alive',
        }
        
        # Add CSRF token from auth data if available
        if 'X-CSRFToken' in auth_headers:
            headers['X-CSRFToken'] = auth_headers['X-CSRFToken']

        return cookies, headers

    except Exception as e:
        print(f"Auth load error: {e}", file=sys.stderr)
        return None, None

class PinterestPinSaver:
    def __init__(self, cookies=None, headers=None):
        """
        Initialize Pinterest Pin Saver
        
        Args:
            cookies (dict): Pinterest session cookies
            headers (dict): Request headers with authentication
        """
        self.session = requests.Session()
        self.base_url = "https://www.pinterest.com"
        
        if headers:
            self.session.headers.update(headers)
        
        if cookies:
            self.session.cookies.update(cookies)
    
    def save_pin(self, pin_id, board_id=None, description="", client_tracking_params=""):
        """
        Save a pin to your Pinterest profile
        
        Args:
            pin_id (str): The ID of the pin to save
            board_id (str, optional): Board ID to save to (if None, saves to default)
            description (str): Description for the saved pin
            client_tracking_params (str): Client tracking parameters
            
        Returns:
            dict: Response from Pinterest API
        """
        
        # Construct the data payload
        data_payload = {
            "options": {
                "carousel_slot_index": 0,
                "clientTrackingParams": client_tracking_params or "CwABAAAAEDMyNjQ1ODkyMTE0ODc5NDgKAAIAAAGYZ_VeSAYAAwAACgAGAAAAAAAAAM4LAAcAAAAKbmdhcGkvcHJvZAA",
                "description": description,
                "is_buyable_pin": False,
                "is_promoted": False,
                "is_removable": False,
                "link": None,
                "pin_id": pin_id,
                "title": ""
            },
            "context": {}
        }
        
        # Add board_id if provided
        if board_id:
            data_payload["options"]["board_id"] = board_id
        
        # Prepare the request data
        request_data = {
            "source_url": f"/pin/{pin_id}/",
            "data": json.dumps(data_payload)
        }
        
        # Make the POST request
        url = f"{self.base_url}/resource/RepinResource/create/"
        
        try:
            response = self.session.post(url, data=request_data, timeout=10)
            
            response.raise_for_status()
            
            # Try to parse JSON response
            try:
                json_response = response.json() if response.content else {}
            except json.JSONDecodeError as json_err:
                return {
                    "success": False,
                    "error": f"JSON decode error: {json_err}. Response: {response.text[:200]}",
                    "status_code": response.status_code,
                    "pin_id": pin_id
                }
            
            return {
                "success": True,
                "status_code": response.status_code,
                "response": json_response,
                "pin_id": pin_id
            }
            
        except requests.exceptions.RequestException as e:
            error_details = str(e)
            if hasattr(e, 'response') and e.response is not None:
                error_details += f" Response: {e.response.text[:200]}"
            
            return {
                "success": False,
                "error": error_details,
                "status_code": getattr(e.response, 'status_code', None) if hasattr(e, 'response') else None,
                "pin_id": pin_id
            }
    
    def get_boards(self):
        """
        Get user's boards (requires authentication)
        
        Returns:
            dict: List of user's boards
        """
        url = f"{self.base_url}/resource/BoardsResource/get/"
        
        try:
            response = self.session.get(url)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            return {"error": str(e)}
    
    def verify_pin_saved(self, saved_pin_id):
        """
        Verify that a pin was actually saved by checking if it exists
        
        Args:
            saved_pin_id (str): The ID of the saved pin to verify
            
        Returns:
            dict: Verification result
        """
        url = f"{self.base_url}/resource/PinResource/get/"
        
        request_data = {
            "source_url": f"/pin/{saved_pin_id}/",
            "data": json.dumps({
                "options": {"id": saved_pin_id},
                "context": {}
            })
        }
        
        try:
            response = self.session.get(url, params=request_data, timeout=10)
            
            if response.status_code == 200:
                return {
                    "exists": True,
                    "pin_id": saved_pin_id,
                    "response": response.json() if response.content else {}
                }
            else:
                return {
                    "exists": False,
                    "pin_id": saved_pin_id,
                    "status_code": response.status_code
                }
                
        except requests.exceptions.RequestException as e:
            return {
                "exists": False,
                "pin_id": saved_pin_id,
                "error": str(e)
            }

def main():
    parser = argparse.ArgumentParser(description='Save Pinterest pins to your profile')
    parser.add_argument('pin_id', help='Pinterest pin ID to save')
    parser.add_argument('--board-id', help='Board ID to save pin to (optional)')
    parser.add_argument('--description', default='', help='Description for the saved pin')
    
    args = parser.parse_args()
    
    # Load Pinterest session using the same method as fetchpinterest.py
    cookies, headers = load_pinterest_session()
    
    if not cookies or not headers:
        print("Error: Pinterest authentication not found")
        print("Please ensure you have ~/.config/pinterest_widget_auth.json configured")
        print("This should contain your Pinterest session cookies and authentication data")
        sys.exit(1)
    
    # Initialize Pinterest saver
    pinterest = PinterestPinSaver(cookies=cookies, headers=headers)
    
    # Save the pin
    print(f"Saving pin {args.pin_id}...")
    result = pinterest.save_pin(
        pin_id=args.pin_id,
        board_id=args.board_id,
        description=args.description
    )
    
    if result["success"]:
        print(f"✅ API reported success for pin {args.pin_id}")
        
        # Extract the saved pin ID from response
        saved_pin_id = None
        if result["response"] and "resource_response" in result["response"]:
            data = result["response"]["resource_response"].get("data", {})
            saved_pin_id = data.get("id")
            board_name = data.get("board", {}).get("name", "Unknown")
            
            print(f"📌 Saved as pin ID: {saved_pin_id}")
            print(f"📋 Saved to board: {board_name}")
            
            # Verify the pin was actually saved
            if saved_pin_id:
                print(f"🔍 Verifying pin {saved_pin_id} exists...")
                verification = pinterest.verify_pin_saved(saved_pin_id)
                
                if verification.get("exists"):
                    print(f"✅ Verification successful - pin {saved_pin_id} exists!")
                else:
                    print(f"❌ Verification failed - pin {saved_pin_id} may not exist")
                    print(f"Verification error: {verification.get('error', 'Unknown error')}")
        
        if result["response"]:
            print(f"\nFull Response: {json.dumps(result['response'], indent=2)}")
    else:
        print(f"❌ Failed to save pin {args.pin_id}")
        print(f"Error: {result['error']}")
        if result.get("status_code"):
            print(f"Status code: {result['status_code']}")

if __name__ == "__main__":
    main()