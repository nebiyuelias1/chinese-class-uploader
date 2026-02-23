#!/bin/bash

# Configuration
VIDEO_DIR="/home/netale/Videos/chinese_with_chini/"
UPLOADED_DIR="${VIDEO_DIR}/uploaded"
TEMP_DIR="/home/netale/.gemini/tmp/chinese_class_uploads" # Use the provided temp dir as base
YOUTUBE_PLAYLIST_ID="Chinese w/ Chini"
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
while read -r VIDEO_FILE <&3; do
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
    if [ -f "$AUDIO_FILE" ]; then
        log "Audio file already exists: $AUDIO_FILE. Skipping extraction."
    else
        log "Extracting audio to: $AUDIO_FILE"
        ffmpeg -i "$VIDEO_FILE" -vn -ar 44100 -ac 2 -b:a 192k "$AUDIO_FILE"
        if [ $? -ne 0 ]; then
            log "Error: Audio extraction failed for $VIDEO_FILE. Skipping."
            continue
        fi
    fi

    # --- Placeholder for Whisper Transcription ---
    TRANSCRIPTION_FILE_BASE="${TEMP_DIR}/${FILENAME_NO_EXT}" # Whisper will add .txt and .srt
    TRANSCRIPTION_FILE="${TRANSCRIPTION_FILE_BASE}.txt"
    SUBTITLE_FILE="${TRANSCRIPTION_FILE_BASE}.srt"
    
    if [ -f "$TRANSCRIPTION_FILE" ] && [ -f "$SUBTITLE_FILE" ]; then
        log "Transcription files already exist. Skipping transcription."
    else
        log "Transcribing audio to: ${TRANSCRIPTION_FILE_BASE}.{txt,srt}"
        whisper "$AUDIO_FILE" --language Chinese --model small --output_dir "$TEMP_DIR" --output_format all --initial_prompt "以下是繁體中文的課堂內容。"
        if [ $? -ne 0 ]; then
            log "Error: Transcription failed for $AUDIO_FILE. Skipping."
            rm -f "$AUDIO_FILE" # Clean up audio file
            continue
        fi
    fi

    # --- Convert to Traditional Chinese using OpenCC ---
    log "Converting transcription to Traditional Chinese..."
    if [ -f "$TRANSCRIPTION_FILE" ]; then
        opencc -i "$TRANSCRIPTION_FILE" -o "${TRANSCRIPTION_FILE}.tmp" -c /usr/share/opencc/s2t.json && mv "${TRANSCRIPTION_FILE}.tmp" "$TRANSCRIPTION_FILE"
    fi
    if [ -f "$SUBTITLE_FILE" ]; then
        opencc -i "$SUBTITLE_FILE" -o "${SUBTITLE_FILE}.tmp" -c /usr/share/opencc/s2t.json && mv "${SUBTITLE_FILE}.tmp" "$SUBTITLE_FILE"
    fi

    # --- Placeholder for YouTube Metadata Preparation ---
    # Assuming filename is in YYYY-MM-DD HH-MM-SS.mkv format
    FILENAME_ONLY=$(basename "$FILENAME_NO_EXT")
    VIDEO_DATE_TIME=$(echo "$FILENAME_ONLY" | cut -d'.' -f1)
    VIDEO_DATE=$(echo "$VIDEO_DATE_TIME" | cut -d' ' -f1)
    # VIDEO_TIME=$(echo "$VIDEO_DATE_TIME" | cut -d' ' -f2) # Not directly used in title currently

    TITLE="Chinese Class with ${TEACHER_NAME} - ${VIDEO_DATE}"
    
    DESCRIPTION="Recorded on ${VIDEO_DATE_TIME}."

    TAGS="Chinese,Class,Mandarin,${TEACHER_NAME},Language,Learning,${VIDEO_DATE}"

    log "YouTube Title: $TITLE"
    log "YouTube Description (first 100 chars): ${DESCRIPTION:0:100}..."
    log "YouTube Tags: $TAGS"

    # --- Placeholder for YouTube Upload ---
    log "Uploading video to YouTube..."
    # We use a temp file to capture output because unbuffer makes piping difficult
    UPLOAD_LOG="${TEMP_DIR}/upload_${FILENAME_NO_EXT}.log"
    unbuffer youtube-upload --title="$TITLE" --description="$DESCRIPTION" --tags="$TAGS" --playlist="$YOUTUBE_PLAYLIST_ID" --privacy=private --client-secrets="$CLIENT_SECRETS_FILE" "$VIDEO_FILE" --default-language='zh-Hant' --embeddable=True | tee "$UPLOAD_LOG"
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log "Error: YouTube upload failed for $VIDEO_FILE. Skipping."
        rm -f "$AUDIO_FILE" "$TRANSCRIPTION_FILE" "$SUBTITLE_FILE" "$UPLOAD_LOG"
        continue
    fi

    # Extract Video ID from the 'Video URL' line or the standalone ID line
    VIDEO_ID=$(grep -oP "watch\?v=\K[^&\s]+" "$UPLOAD_LOG" | head -n 1)
    
    if [ -z "$VIDEO_ID" ]; then
        # Fallback: look for the ID on a line by itself (often the last line)
        VIDEO_ID=$(tail -n 5 "$UPLOAD_LOG" | grep -v "Adding video to playlist" | grep -oE "^[a-zA-Z0-9_-]{11}$" | tail -n 1)
    fi

    if [ -z "$VIDEO_ID" ]; then
        # Legacy fallback
        VIDEO_ID=$(grep "Video id" "$UPLOAD_LOG" | awk -F"'" '{print $2}')
    fi
    rm -f "$UPLOAD_LOG"

    if [ -n "$VIDEO_ID" ]; then
        log "Video uploaded successfully. Video ID: $VIDEO_ID"
        # --- Upload Subtitles ---
        if [ -f "$SUBTITLE_FILE" ]; then
            log "Uploading subtitles ($SUBTITLE_FILE)..."
            python upload_subtitles.py --video-id "$VIDEO_ID" --file "$SUBTITLE_FILE" --language "zh-Hant" --name "Traditional Chinese"
        else
            log "Warning: Subtitle file not found, skipping caption upload."
        fi
    else
        log "Warning: Could not extract Video ID from upload output. Subtitles will not be uploaded."
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

done 3< <(find "$VIDEO_DIR" -maxdepth 1 -type f \( -name "*.mkv" -o -name "*.mp4" \))

log "Script finished."
