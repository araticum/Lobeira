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

# Install Python dependencies
# Core deps (obrigatório)
COPY requirements-core.txt .
RUN pip install --no-cache-dir -r requirements-core.txt

# Heavy deps: docling, marker-pdf (opcional — falha não quebra container)
COPY requirements-heavy.txt .
RUN pip install --no-cache-dir -r requirements-heavy.txt || echo "WARNING: heavy deps failed, continuing without them"
# Install torch with ROCm support (AMD Radeon) instead of default CUDA
RUN pip install --no-cache-dir "torch==2.7.0+rocm6.3" "torchvision==0.22.0+rocm6.3" --index-url https://download.pytorch.org/whl/rocm6.3

# Marker (step 3 OCR) — instalado DEPOIS do torch ROCm para evitar conflito
# --no-deps em marker-pdf: pula torch (ROCm já instalado acima, não disponível no PyPI padrão)
# surya-ocr instalado sem --no-deps: pip vê torch>=2.7.0 já satisfeito pelo ROCm, não reinstala
RUN pip install --no-cache-dir marker-pdf --no-deps && \
    pip install --no-cache-dir \
        "surya-ocr>=0.17.1,<0.18.0" \
        "anthropic>=0.46.0,<0.47.0" \
        "filetype>=1.2.0,<2.0.0" \
        "ftfy>=6.1.1,<7.0.0" \
        "google-genai>=1.0.0,<2.0.0" \
        "markdown2>=2.5.2,<3.0.0" \
        "markdownify>=1.1.0,<2.0.0" \
        "openai>=1.65.2,<2.0.0" \
        "pdftext>=0.6.3,<0.7.0" \
        "pydantic-settings>=2.0.3,<3.0.0" \
        "python-dotenv>=1.0.0,<2.0.0" \
        "rapidfuzz>=3.8.1,<4.0.0" \
        "scikit-learn>=1.6.1,<2.0.0" \
        "transformers>=4.45.2,<5.0.0" \
    || echo "WARNING: marker-pdf deps failed — Marker não estará disponível no step 3"

# EasyOCR — usa o torch ROCm já instalado acima (não reinstala torch)
RUN pip install --no-cache-dir easyocr

# RapidOCR + onnxruntime — engine OCR leve para o docling (CPU, sem GPU necessária)
RUN pip install --no-cache-dir onnxruntime rapidocr-onnxruntime

COPY main.py .
COPY zip_recursive.py .

RUN mkdir -p /app/storage

EXPOSE 7000

ENV MAX_WORKERS=2
ENV LOG_LEVEL=INFO

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000", "--workers", "1"]
