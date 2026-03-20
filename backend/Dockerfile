# Start from a slim Python base image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies for underthesea, document parsing, and PostgreSQL
RUN apt-get update && apt-get install -y \
    build-essential \
    libmupdf-dev \
    libglib2.0-dev \
    libmagic-dev \
    gcc \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-vie \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file (create requirements.txt as below)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy all app source code
COPY . .

# Expose FastAPI port
EXPOSE 8000

# Set environment variables (to override .env if needed)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Start FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]