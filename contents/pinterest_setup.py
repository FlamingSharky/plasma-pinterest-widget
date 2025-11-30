#!/usr/bin/env python3
"""
Pinterest Widget Authentication Setup
Helps set up authentication for personal Pinterest feed
"""

import json
import os
import sys

def create_auth_config():
    """
    Interactive setup for Pinterest authentication
    """
    print("Pinterest Widget Authentication Setup")
    print("=" * 40)
    print()

    config_file = os.path.expanduser("~/.config/pinterest_widget_auth.json")

    print("To get your personal Pinterest feed, you need to provide authentication cookies.")
    print("This is safe - the data stays on your local machine.")
    print()

    print("Steps to get your Pinterest cookies:")
    print("1. Open Pinterest.com in your browser and make sure you're logged in")
    print("2. Open Developer Tools (F12 or Ctrl+Shift+I)")
    print("3. Go to the 'Network' tab")
    print("4. Refresh the Pinterest page")
    print("5. Click on the first request to pinterest.com")
    print("6. In the 'Headers' section, find 'Request Headers'")
    print("7. Look for the 'Cookie' header and copy its value")
    print()

    print("The cookie value will look something like:")
    print("_auth=1234...; _pinterest_sess=abcd...; csrftoken=xyz...")
    print()

    cookie_string = input("Paste your Pinterest cookie string here: ").strip()

    if not cookie_string:
        print("No cookie provided. Exiting.")
        return False

    # Parse cookie string into individual cookies
    cookies = {}
    csrf_token = ""

    try:
        for cookie_pair in cookie_string.split(';'):
            if '=' in cookie_pair:
                name, value = cookie_pair.strip().split('=', 1)
                cookies[name] = value

                if name == 'csrftoken':
                    csrf_token = value
    except Exception as e:
        print(f"Error parsing cookies: {e}")
        return False

    if not cookies:
        print("No valid cookies found in the string.")
        return False

    # Create auth configuration
    auth_config = {
        "cookies": cookies,
        "headers": {},
        "created": "Created by pinterest_auth_setup.py"
    }

    # Add CSRF token to headers if found
    if csrf_token:
        auth_config["headers"]["X-CSRFToken"] = csrf_token

    # Create config directory if it doesn't exist
    os.makedirs(os.path.dirname(config_file), exist_ok=True)

    # Save configuration
    try:
        with open(config_file, 'w') as f:
            json.dump(auth_config, f, indent=2)

        print(f"\nAuthentication configuration saved to: {config_file}")
        print(f"Found {len(cookies)} cookies")

        if csrf_token:
            print("✓ CSRF token found")
        else:
            print("⚠ No CSRF token found - some features may not work")

        print("\nYou can now use the personal feed option in the Pinterest widget!")
        print("Note: If the authentication stops working, you may need to repeat this process.")

        return True

    except Exception as e:
        print(f"Error saving configuration: {e}")
        return False

def test_auth_config():
    """
    Test existing authentication configuration
    """
    config_file = os.path.expanduser("~/.config/pinterest_widget_auth.json")

    if not os.path.exists(config_file):
        print(f"Authentication file not found: {config_file}")
        print("Run this script without arguments to set up authentication.")
        return False

    try:
        with open(config_file, 'r') as f:
            auth_data = json.load(f)

        cookies = auth_data.get('cookies', {})
        headers = auth_data.get('headers', {})

        print(f"Authentication file found: {config_file}")
        print(f"Cookies: {len(cookies)} found")

        important_cookies = ['_auth', '_pinterest_sess', 'csrftoken']
        for cookie_name in important_cookies:
            if cookie_name in cookies:
                print(f"✓ {cookie_name}: present")
            else:
                print(f"✗ {cookie_name}: missing")

        if 'X-CSRFToken' in headers:
            print("✓ CSRF token header: present")
        else:
            print("✗ CSRF token header: missing")

        # Try to make a test request
        print("\nTesting authentication...")

        import requests

        test_headers = {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
        }
        test_headers.update(headers)

        try:
            response = requests.get(
                'https://www.pinterest.com/',
                cookies=cookies,
                headers=test_headers,
                timeout=10
            )

            if response.status_code == 200:
                print("✓ Authentication appears to be working!")
                return True
            else:
                print(f"✗ Request failed with status code: {response.status_code}")
                print("Your cookies may have expired. Try running setup again.")
                return False

        except requests.exceptions.RequestException as e:
            print(f"✗ Request failed: {e}")
            return False

    except Exception as e:
        print(f"Error reading authentication file: {e}")
        return False

def main():
    """Main function"""
    print()
    
    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        test_auth_config()
    else:
        if create_auth_config():
            print("\nTesting the new configuration...")
            test_auth_config()

if __name__ == '__main__':
    main()
