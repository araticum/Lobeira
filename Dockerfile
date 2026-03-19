FROM python:3.11

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
    curl \
    git \
    tesseract-ocr \
    tesseract-ocr-por \
    libmagic1 \
    poppler-utils \
    p7zip-full \
    unar \
    libreoffice-writer \
    libreoffice-calc \
    libgl1 \
    libglib2.0-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
COPY zip_recursive.py .

RUN mkdir -p /app/storage

EXPOSE 7000

ENV MAX_WORKERS=2
ENV LOG_LEVEL=INFO

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000", "--workers", "1"]
