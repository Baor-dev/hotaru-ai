import os

DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@db:5432/studydb")
CHROMA_PATH = os.getenv("CHROMA_PATH", "/chroma_data")
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "/storage/uploads")
SECRET_KEY = os.getenv("SECRET_KEY", "XX-REPLACE-ME-XX")