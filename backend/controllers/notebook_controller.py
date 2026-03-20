from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models.user import User
from models.notebook import Notebook
from utils.auth import get_current_user
from utils.vectorstore import collection

router = APIRouter()

# Schema để nhận dữ liệu khi tạo Notebook
class NotebookCreate(BaseModel):
    title: str

# --- 1. LẤY DANH SÁCH NOTEBOOK ---
@router.get("/notebooks/")
async def get_notebooks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    notebooks = db.query(Notebook).filter(Notebook.user_id == current_user.id).order_by(Notebook.created_at.desc()).all()
    
    return {"notebooks": [{"id": nb.id, "title": nb.title, "created_at": nb.created_at} for nb in notebooks]}

# --- 2. TẠO MỚI NOTEBOOK (GIỚI HẠN TỐI ĐA 3) ---
@router.post("/notebooks/")
async def create_notebook(
    request: NotebookCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Kiểm tra số lượng Notebook hiện tại của User
    current_count = db.query(Notebook).filter(Notebook.user_id == current_user.id).count()
    if current_count >= 3:
        raise HTTPException(status_code=400, detail="Bạn đã đạt giới hạn tối đa 3 Notebook. Vui lòng xóa bớt để tạo mới.")

    # Tạo Notebook mới
    new_notebook = Notebook(user_id=current_user.id, title=request.title)
    db.add(new_notebook)
    db.commit()
    db.refresh(new_notebook)

    return {"message": "Tạo Notebook thành công", "notebook": {"id": new_notebook.id, "title": new_notebook.title}}

# --- 3. XÓA NOTEBOOK (XÓA KÉP SQL + CHROMADB) ---
@router.delete("/notebooks/{notebook_id}")
async def delete_notebook(
    notebook_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Tìm Notebook cần xóa và đảm bảo nó thuộc về current_user
    notebook = db.query(Notebook).filter(Notebook.id == notebook_id, Notebook.user_id == current_user.id).first()
    
    if not notebook:
        raise HTTPException(status_code=404, detail="Không tìm thấy Notebook hoặc bạn không có quyền xóa.")

    try:
        # 1. Xóa toàn bộ vector chunks thuộc Notebook này trong ChromaDB
        collection.delete(where={"notebook_id": notebook_id})
        
        # 2. Xóa trong PostgreSQL 
        # (Nhờ config cascade="all, delete-orphan" ở models, các documents và messages bên trong sẽ tự động bị xóa theo)
        db.delete(notebook)
        db.commit()
        
        return {"message": f"Đã xóa Notebook '{notebook.title}' cùng toàn bộ tài liệu và lịch sử chat."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi hệ thống khi xóa Notebook: {str(e)}")