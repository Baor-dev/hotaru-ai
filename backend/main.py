import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from database import engine, Base, SessionLocal
# Import các model để SQLAlchemy nhận diện được cấu trúc bảng
from models.user import User
from models.notebook import Notebook
from models.document import Document

# Import router tổng từ thư mục api
from api.router import api_router

# Tạo các bảng trong cơ sở dữ liệu
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Hotaru AI Backend")

# 1. MIDDLEWARE: Luôn khai báo đầu tiên để xử lý CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Tạo dữ liệu mồi (Seed Data) cho MVP test
@app.on_event("startup")
def startup_event():
    db = SessionLocal()
    try:
        # Nếu chưa có User 1, tạo mới
        if not db.query(User).filter(User.id == 1).first():
            dummy_user = User(id=1, email="bao.cecomtech@example.com", password_hash="hashed_pw")
            db.add(dummy_user)
            db.commit()
            
        # Nếu chưa có Notebook 1, tạo mới
        if not db.query(Notebook).filter(Notebook.id == 1).first():
            dummy_nb = Notebook(id=1, user_id=1, title="Notebook Mặc Định")
            db.add(dummy_nb)
            db.commit()
    except Exception as e:
        print(f"Lỗi khởi tạo DB: {e}")
    finally:
        db.close()

# 2. API ENDPOINTS: Nạp toàn bộ route từ document_controller và chat_controller
app.include_router(api_router)

# API hỗ trợ hiển thị danh sách mặc định cho file index.html
@app.get("/notebooks/")
async def get_notebooks():
    return JSONResponse({
        "notebooks": [
            {"name": "Kiến trúc phần mềm (Software Architecture)"},
            {"name": "Tài liệu phát triển Odoo & Python"},
            {"name": "Kiến thức Penetration Testing cơ bản"}
        ]
    })

# 3. STATIC FILES: Luôn đặt ở cuối cùng để tránh xung đột route (Catch-all)
public_dir = "../public"
if os.path.isdir(public_dir):
    app.mount("/", StaticFiles(directory=public_dir, html=True), name="static")
else:
    @app.get("/")
    async def root():
        return {"message": "Thư mục public chưa được mount thành công qua Docker volumes."}
    
@app.get("/")
async def serve_frontend():
    return FileResponse(os.path.join(os.path.dirname(__file__), "index.html"))