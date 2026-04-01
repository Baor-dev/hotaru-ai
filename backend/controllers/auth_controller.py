from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timedelta
from jose import jwt, JWTError
from passlib.context import CryptContext

from fastapi.responses import HTMLResponse
from utils.email_utils import send_verification_email 
import hashlib

from database import get_db
from models.user import User

router = APIRouter()

# 1. KHAI BÁO CÁC SCHEMA (Nếu Anh/Chị đã khai báo ở file schemas.py thì import vào nhé, Tôi tạm để ở đây để tránh lỗi)
class LoginRequest(BaseModel):
    email: str
    password: str

class UserCreate(BaseModel):
    email: str
    password: str

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Hàm kiểm tra mật khẩu
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)
    
# ==========================================
# API ĐĂNG NHẬP
# ==========================================
@router.post("/login/")
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == request.email).first()
    
    is_valid_password = False
    if user:
        # === BẬT LẠI LOGIC CHUẨN ===
        # Dùng hàm verify_password để so khớp pass người dùng gõ với pass đã băm trong DB
        # Lưu ý: Sửa 'user.hashed_password' thành 'user.password' nếu Model database của Anh/Chị đặt tên cột là 'password'
        if verify_password(request.password, user.password_hash): 
            is_valid_password = True

    if not user or not is_valid_password:
        raise HTTPException(status_code=400, detail="Sai email hoặc mật khẩu.")
    
    # CHẶN CỬA XÁC THỰC EMAIL
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Tài khoản chưa được xác thực. Vui lòng kiểm tra hộp thư Email!")
    
    # TẠO TOKEN ĐĂNG NHẬP
    payload = {
        "user_id": user.id,
        "exp": datetime.utcnow() + timedelta(hours=24)
    }

    SECRET_KEY = "hotaru_secret_key"
    ALGORITHM = "HS256"

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    
    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": user.id
    }

# ==========================================
# API ĐĂNG KÝ
# ==========================================
@router.post("/register")
async def register(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email này đã được đăng ký.")

    # TỰ BĂM MẬT KHẨU BẰNG HASHLIB (Không cần thư viện ngoài)
    hashed_pw = get_password_hash(user.password)

    new_user = User(email=user.email, password_hash=hashed_pw, is_active=False)
    
    new_user = User(email=user.email, password_hash=hashed_pw, is_active=False)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # TỰ TẠO TOKEN XÁC THỰC (Không cần gọi hàm bên ngoài)
    payload = {
        "sub": new_user.email,
        "type": "verify",
        "exp": datetime.utcnow() + timedelta(hours=24)
    }

    SECRET_KEY = "hotaru_secret_key"

    verify_token = jwt.encode(payload, SECRET_KEY, algorithm="HS256") # Đảm bảo SECRET_KEY là chuỗi của Anh/Chị

    # Bắn Email
    send_success = send_verification_email(new_user.email, verify_token)
    if not send_success:
        return {"message": "Tạo tài khoản thành công nhưng gửi mail thất bại. Vui lòng liên hệ Admin."}

    return {"message": "Đăng ký thành công! Vui lòng kiểm tra hộp thư email để xác thực tài khoản."}

# ==========================================
# API XÁC THỰC MAIL
# ==========================================
@router.get("/verify/{token}")
async def verify_email(token: str, db: Session = Depends(get_db)):
    # Đưa chìa khóa vào tận tay cho hàm này mở token
    SECRET_KEY = "hotaru_secret_key" 
    
    try:
        # Thay thế ALGORITHM bằng chuỗi cứng "HS256" giống hệt lúc tạo Token
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        email: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        if email is None or token_type != "verify":
            raise HTTPException(status_code=400, detail="Token không hợp lệ.")
            
    except JWTError:
        raise HTTPException(status_code=400, detail="Link xác thực đã hết hạn hoặc không bị chỉnh sửa.")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản.")

    if user.is_active:
        return {"message": "Tài khoản đã được kích hoạt từ trước."}

    # Bật công tắc kích hoạt
    user.is_active = True
    db.commit()

    # Trả về giao diện Web báo thành công
    html_content = """
    <html>
        <body style="display: flex; justify-content: center; align-items: center; height: 100vh; font-family: Arial, sans-serif; background-color: #f0f2f5;">
            <div style="background: white; padding: 40px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); text-align: center;">
                <h1 style="color: #2ecc71;">✅ Xác Thực Thành Công!</h1>
                <p style="font-size: 18px; color: #555;">Tài khoản của bạn đã được kích hoạt.</p>
                <a href="http://localhost:9000/#/auth" style="display: inline-block; margin-top: 20px; padding: 10px 20px; background-color: #3498db; color: white; text-decoration: none; border-radius: 5px;">Quay lại trang Đăng Nhập</a>
            </div>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@router.get("/sync-id")
def sync_user_id(db: Session = Depends(get_db)):
    try:
        # Lệnh SQL ép PostgreSQL nhìn vào ID lớn nhất hiện tại và đếm tiếp từ đó
        query = "SELECT setval(pg_get_serial_sequence('users', 'id'), coalesce(max(id), 1), max(id) IS NOT null) FROM users;"
        db.execute(text(query))
        db.commit()
        return {"message": "Ca phẫu thuật thành công! Bộ đếm ID đã được khôi phục."}
    except Exception as e:
        db.rollback()
        return {"error": f"Lỗi: {str(e)}"}
    
@router.get("/dev/reset-users")
def reset_users(db: Session = Depends(get_db)):
    try:
        # Lệnh SQL mạnh nhất của PostgreSQL để dọn dẹp table
        db.execute(text("TRUNCATE TABLE users RESTART IDENTITY CASCADE;"))
        db.commit()
        
        return {
            "status": "success",
            "message": "🧹 Đã dọn sạch 100% tài khoản rác và reset bộ đếm ID về 1!"
        }
    except Exception as e:
        db.rollback()
        return {"error": f"Lỗi dọn dẹp: {str(e)}"}