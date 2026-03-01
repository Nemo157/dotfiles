ARG GPU=rocm
FROM docker.io/python:3.12-slim

ARG GPU
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/Nemo157/F5-TTS-Server.git .

# Install torch ecosystem from the platform-specific wheel index so all
# torch packages have matching version strings
RUN if [ "$GPU" = "rocm" ]; then \
        pip install --no-cache-dir torch torchaudio \
            --index-url https://download.pytorch.org/whl/rocm7.1; \
    else \
        pip install --no-cache-dir torch torchaudio \
            --index-url https://download.pytorch.org/whl/cu124; \
    fi

RUN pip install --no-cache-dir torchcodec

RUN pip install --no-cache-dir -r requirements.txt

# Pre-download model weights so the container works fully offline
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('SWivid/F5-TTS', allow_patterns=['F5TTS_v1_Base/*'])"
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('charactr/vocos-mel-24khz')"
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('openai/whisper-large-v3-turbo')"

RUN mkdir -p output

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
