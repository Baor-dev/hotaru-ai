from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
import jwt
import datetime

from database import get_db
from models.user import User

router = APIRouter()

# Khóa bảo mật để mã hóa token (Trong thực tế nên lưu ở file .env)
SECRET_KEY = "hotaru_secret_key" 

class LoginRequest(BaseModel):
    email: str
    password: str

@router.post("/login/")
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    # Tìm user trong DB
    user = db.query(User).filter(User.email == request.email).first()
    
    # Logic MVP: Bypass kiểm tra mã băm (hash), chấp nhận mật khẩu "123456" cho user mồi
    if not user or request.password != "123456":
        raise HTTPException(status_code=400, detail="Sai email hoặc mật khẩu")
    
    # Tạo JWT Token có thời hạn 24 giờ
    payload = {
        "user_id": user.id,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
    
    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": user.id
    }