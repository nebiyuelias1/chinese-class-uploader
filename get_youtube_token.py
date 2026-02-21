import os
import json
import sys

try:
    from google_auth_oauthlib.flow import InstalledAppFlow
except ImportError:
    print(
        "Error: 'google-auth-oauthlib' is not installed. Run: pip install google-auth-oauthlib"
    )
    sys.exit(1)

# The scopes required by youtube-upload
SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.force-ssl",
]


def main():
    if not os.path.exists("client_secrets.json"):
        print("Error: 'client_secrets.json' not found in current directory.")
        return

    # 1. Start the flow using your client_secrets.json
    flow = InstalledAppFlow.from_client_secrets_file("client_secrets.json", SCOPES)

    # 2. Run the local server to get credentials
    # This will open your browser or give you a local link
    print("Opening browser for authentication...")
    credentials = flow.run_local_server(port=0)

    # 3. Format the credentials for youtube-upload (oauth2client format)
    # This structure is what the old 'oauth2client' library expects
    token_data = {
        "access_token": credentials.token,
        "refresh_token": credentials.refresh_token,
        "client_id": credentials.client_id,
        "client_secret": credentials.client_secret,
        "token_expiry": credentials.expiry.isoformat() + "Z",
        "token_uri": credentials.token_uri,
        "user_agent": None,
        "revoke_uri": "https://oauth2.googleapis.com/revoke",
        "id_token": None,
        "id_token_jwt": None,
        "token_response": {
            "access_token": credentials.token,
            "expires_in": 3599,
            "refresh_token": credentials.refresh_token,
            "scope": " ".join(SCOPES),
            "token_type": "Bearer",
        },
        "scopes": SCOPES,
        "token_info_uri": "https://oauth2.googleapis.com/tokeninfo",
        "invalid": False,
        "_class": "OAuth2Credentials",
        "_module": "oauth2client.client",
    }

    # 4. Save to the default location for youtube-upload
    credential_path = os.path.expanduser("~/.youtube-upload-credentials.json")
    with open(credential_path, "w") as f:
        json.dump(token_data, f)

    print(f"Success! Credentials saved to {credential_path}")
    print("You can now run 'youtube-upload' without any auth flags.")


if __name__ == "__main__":
    main()
