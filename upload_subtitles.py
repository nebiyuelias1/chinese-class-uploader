import os
import json
import sys
import argparse
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Scopes needed for caption upload - using the broader scope to match common uploaders
SCOPES = [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.upload"
]


def load_credentials(token_path, client_secrets_path="client_secrets.json"):
    if not os.path.exists(token_path):
        print(f"Error: Token file not found at {token_path}")
        return None

    with open(token_path, "r") as f:
        token_data = json.load(f)

    # Check if it's the porjo/youtubeuploader format (request.token)
    if "access_token" in token_data and "token_type" in token_data:
        # Standard oauth2.Token format. 
        # We need client_id and client_secret which are usually in client_secrets.json
        client_id = None
        client_secret = None
        if os.path.exists(client_secrets_path):
            with open(client_secrets_path, "r") as f:
                cs_data = json.load(f)
                # client_secrets.json can be "installed" or "web" type
                key = "installed" if "installed" in cs_data else "web"
                client_id = cs_data[key]["client_id"]
                client_secret = cs_data[key]["client_secret"]

        creds = Credentials(
            token=token_data["access_token"],
            refresh_token=token_data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=client_id,
            client_secret=client_secret,
        )
    else:
        # Convert the old oauth2client format to google-auth format
        creds = Credentials(
            token=token_data["access_token"],
            refresh_token=token_data["refresh_token"],
            token_uri=token_data["token_uri"],
            client_id=token_data["client_id"],
            client_secret=token_data["client_secret"],
            scopes=token_data["scopes"],
        )
    return creds


def upload_subtitle(video_id, subtitle_file, language, name):
    # Try local request.token (youtubeuploader) first, then fallback to global home dir
    token_path = "request.token"
    if not os.path.exists(token_path):
        token_path = os.path.expanduser("~/.youtube-upload-credentials.json")
        
    creds = load_credentials(token_path)
    if not creds:
        return

    youtube = build("youtube", "v3", credentials=creds)

    print(f"Uploading subtitle {subtitle_file} for video {video_id}...")

    try:
        media = MediaFileUpload(subtitle_file, mimetype="application/octet-stream", resumable=True)
        request = (
            youtube.captions()
            .insert(
                part="snippet",
                body={
                    "snippet": {
                        "videoId": video_id,
                        "language": language,
                        "name": name,
                        "isDraft": False,
                    }
                },
                media_body=media,
            )
        )
        
        response = None
        while response is None:
            status, response = request.next_chunk()
            if status:
                sys.stdout.write(f"\rUploading subtitle... {int(status.progress() * 100)}%")
                sys.stdout.flush()
        
        print(f"\nSubtitle uploaded successfully. ID: {response['id']}")
    except Exception as e:
        print(f"\nError uploading subtitle: {e}")


def main():
    parser = argparse.ArgumentParser(description="Upload subtitles to a YouTube video.")
    parser.add_argument("--video-id", required=True, help="The YouTube video ID.")
    parser.add_argument("--file", required=True, help="The subtitle file (.srt).")
    parser.add_argument("--language", default="zh-Hant", help="The language code.")
    parser.add_argument("--name", default="Traditional Chinese", help="The caption name.")

    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"Error: File {args.file} not found.")
        sys.exit(1)

    upload_subtitle(args.video_id, args.file, args.language, args.name)


if __name__ == "__main__":
    main()
