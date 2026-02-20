#!/bin/bash

# Configuration
VIDEO_DIR="/home/netale/Videos/chinese_with_chini/"
UPLOADED_DIR="${VIDEO_DIR}/uploaded"
TEMP_DIR="/home/netale/.gemini/tmp/chinese_class_uploads" # Use the provided temp dir as base
YOUTUBE_PLAYLIST_ID="PLflbVNkVSAPQlZLH-AI_IwJpYu4TilvvA"
TEACHER_NAME="Chini"
CLIENT_SECRETS_FILE="client_secrets.json"

# Ensure necessary directories exist
mkdir -p "$UPLOADED_DIR"
mkdir -p "$TEMP_DIR"

# Function for logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Main script logic
log "Starting Chinese class video processing script."

# Find new video files (e.g., .mkv, .mp4)
# Exclude files already in the UPLOADED_DIR by checking their path
find "$VIDEO_DIR" -maxdepth 1 -type f \( -name "*.mkv" -o -name "*.mp4" \) | while read -r VIDEO_FILE; do
    # Check if the file is within the UPLOADED_DIR, if so, skip it
    if [[ "$VIDEO_FILE" == "$UPLOADED_DIR"* ]]; then
        log "Skipping $VIDEO_FILE as it's already in the uploaded directory."
        continue
    fi

    log "Processing video: $VIDEO_FILE"
    FILENAME=$(basename -- "$VIDEO_FILE")
    FILENAME_NO_EXT="${FILENAME%.*}"

    # --- Placeholder for Audio Extraction ---
    AUDIO_FILE="${TEMP_DIR}/${FILENAME_NO_EXT}.mp3"
    log "Extracting audio to: $AUDIO_FILE"
    ffmpeg -i "$VIDEO_FILE" -vn -ar 44100 -ac 2 -b:a 192k "$AUDIO_FILE"
    if [ $? -ne 0 ]; then
        log "Error: Audio extraction failed for $VIDEO_FILE. Skipping."
        continue
    fi

    # --- Placeholder for Whisper Transcription ---
    TRANSCRIPTION_FILE_BASE="${TEMP_DIR}/${FILENAME_NO_EXT}" # Whisper will add .txt and .srt
    TRANSCRIPTION_FILE="${TRANSCRIPTION_FILE_BASE}.txt"
    SUBTITLE_FILE="${TRANSCRIPTION_FILE_BASE}.srt"
    log "Transcribing audio to: ${TRANSCRIPTION_FILE_BASE}.{txt,srt}"
    whisper "$AUDIO_FILE" --language Chinese --model small --output_dir "$TEMP_DIR" --output_format all --initial_prompt "以下是繁體中文的課堂內容。"
    if [ $? -ne 0 ]; then
        log "Error: Transcription failed for $AUDIO_FILE. Skipping."
        rm -f "$AUDIO_FILE" # Clean up audio file
        continue
    fi

    # --- Placeholder for YouTube Metadata Preparation ---
    # Assuming filename is in YYYY-MM-DD HH-MM-SS.mkv format
    FILENAME_ONLY=$(basename "$FILENAME_NO_EXT")
    VIDEO_DATE_TIME=$(echo "$FILENAME_ONLY" | cut -d'.' -f1)
    VIDEO_DATE=$(echo "$VIDEO_DATE_TIME" | cut -d' ' -f1)
    # VIDEO_TIME=$(echo "$VIDEO_DATE_TIME" | cut -d' ' -f2) # Not directly used in title currently

    TITLE="Chinese Class with ${TEACHER_NAME} - ${VIDEO_DATE}"
    
    DESCRIPTION="Recorded on ${VIDEO_DATE_TIME}.

"
    if [ -s "$TRANSCRIPTION_FILE" ]; then # Check if file exists and is not empty
        DESCRIPTION+="Transcription:
$(cat "$TRANSCRIPTION_FILE")"
    else
        DESCRIPTION+="No transcription available."
    fi

    TAGS="Chinese,Class,Mandarin,${TEACHER_NAME},Language,Learning,${VIDEO_DATE}"

    log "YouTube Title: $TITLE"
    log "YouTube Description (first 100 chars): ${DESCRIPTION:0:100}..."
    log "YouTube Tags: $TAGS"

    # --- Placeholder for YouTube Upload ---
    log "Uploading video to YouTube..."
    # You need to install youtube-upload: pip install google-api-python-client oauth2client youtube-upload
    # And set up CLIENT_SECRETS_FILE and authorize it. See instructions below.
    youtube-upload --title="$TITLE" --description="$DESCRIPTION" --tags="$TAGS" --playlist="$YOUTUBE_PLAYLIST_ID" --privacy=private --client-secrets="$CLIENT_SECRETS_FILE" "$VIDEO_FILE" --default-language='zh-Hans' --embeddable=True --no-publish
    if [ $? -ne 0 ]; then
        log "Error: YouTube upload failed for $VIDEO_FILE. Skipping."
        rm -f "$AUDIO_FILE" "$TRANSCRIPTION_FILE" "$SUBTITLE_FILE" # Clean up temp files if upload fails
        continue
    fi

    # --- Cleanup and Move ---
    log "Upload successful. Moving video, transcription, and subtitles to $UPLOADED_DIR and cleaning up."
    mv "$VIDEO_FILE" "$UPLOADED_DIR"
    if [ -f "$TRANSCRIPTION_FILE" ]; then
        mv "$TRANSCRIPTION_FILE" "$UPLOADED_DIR"
    fi
    if [ -f "$SUBTITLE_FILE" ]; then
        mv "$SUBTITLE_FILE" "$UPLOADED_DIR"
    fi
    rm -f "$AUDIO_FILE"

    log "Finished processing $VIDEO_FILE"
    log "----------------------------------------------------"

done

log "Script finished."
