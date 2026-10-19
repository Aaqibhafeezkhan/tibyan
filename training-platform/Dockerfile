FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements-alignment.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Optional CTC forced alignment for player word positions (~+125 MB:
# onnxruntime + numpy). The model itself is mounted, not baked in.
ARG WITH_ALIGNMENT=0
RUN if [ "$WITH_ALIGNMENT" = "1" ]; then \
      pip install --no-cache-dir -r requirements-alignment.txt; \
    fi

COPY app ./app
# Media (private recordings + export) is mounted from the host; create the
# data directory for the production bind mount so the app can write even
# before the first mount.
RUN mkdir -p /app/media /app/data /app/models

EXPOSE 8001

CMD ["uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8001", "--workers", "2"]
