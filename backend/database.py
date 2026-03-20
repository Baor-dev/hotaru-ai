from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# URL kết nối tới container 'db' trong docker-compose
# Format: postgresql://user:password@host:port/dbname
SQLALCHEMY_DATABASE_URL = "postgresql://postgres:postgres@db:5432/studydb"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Dependency để sử dụng trong các API (FastAPI)
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()