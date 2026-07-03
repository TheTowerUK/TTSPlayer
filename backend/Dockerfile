# TTSPlayer — Backend Dockerfile
# Runs the indexer as a lightweight Python container on the TNAS.
# Build:  docker build -t ttsplayer-backend .
# Run:    docker run --rm -v /volume1/media:/media ttsplayer-backend \
#           python indexer.py --root /media --output /media/catalog.json

FROM python:3.12-slim

# ffprobe for duration extraction
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY indexer.py .

ENTRYPOINT ["python", "indexer.py"]
