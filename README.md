# YouTube Chinese Class Uploader

This tool automates the process of extracting audio, transcribing it using OpenAI's Whisper, and uploading video lessons to a private YouTube playlist.

## Prerequisites

### 1. System Requirements
- **Linux** (Tested on Arch Linux)
- **Python 3.12+**
- **FFmpeg** (For audio extraction)

### 2. Required Tools & Libraries
Install the main tools using your package manager and pip:

```bash
# Install youtube-upload (Arch/AUR)
yay -S youtube-upload-git --overwrite "*"

# Install Whisper (OpenAI)
pip install openai-whisper

# Install Authentication helper
pip install google-auth-oauthlib
```

---

## Initial Setup (One-Time)

### 1. Google Cloud Project Setup
To use the YouTube API, you must create your own credentials:
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project named "YouTube Uploader".
3. Enable the **YouTube Data API v3**.
4. Configure the **OAuth Consent Screen**:
   - Set User Type to **External**.
   - Add your email (e.g., `nebiyuelias1@gmail.com`) as a **Test User**.
5. Create **Credentials**:
   - Create an **OAuth 2.0 Client ID**.
   - Select **Desktop app**.
   - Download the JSON file and rename it to `client_secrets.json` in this directory.

### 2. Authorize the Tool
Run the provided helper script to generate the required YouTube token:

```bash
python get_youtube_token.py
```
- A browser window will open.
- Log in with your test user account.
- Click "Advanced" -> "Go to Chinese (unsafe)" to grant permission.
- The script will save your token to `~/.youtube-upload-credentials.json`.

---

## Usage

1. **Place your videos** in the directory specified in the script:
   - Default: `/home/netale/Videos/Chinese with Chini/`
2. **Configure the script** (optional):
   - Edit `upload_chinese_class.sh` to change the `YOUTUBE_PLAYLIST_ID` or `TEACHER_NAME`.
3. **Run the uploader**:

```bash
bash upload_chinese_class.sh
```

### What the script does:
1. **Scans** for `.mkv` or `.mp4` files.
2. **Extracts** audio to a temporary MP3 file.
3. **Transcribes** the audio to Chinese text and SRT subtitles.
4. **Uploads** the video to YouTube as **Private**.
5. **Updates** the title with the date and the description with the transcription.
6. **Moves** the finished files to an `uploaded/` folder.

## Troubleshooting

- **Invalid Client**: Ensure `client_secrets.json` matches the project in Google Cloud Console.
- **Playlist not found**: If the playlist ID doesn't work, try using the **Title** of the playlist in the script instead.
- **Transcription Error**: Ensure `whisper` is in your PATH.
