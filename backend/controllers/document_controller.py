import os
import fitz
import docx
import pytesseract
from pdf2image import convert_from_path
from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session

from utils.auth import get_current_user
from models.user import User
from models.notebook import Notebook
from models.document import Document
from database import get_db
from models.document import Document
from utils.chunking import chunk_text
from utils.embedding import get_embedding
from utils.vectorstore import collection, add_chunk

router = APIRouter()

@router.get("/notebooks/{notebook_id}/documents/")
async def get_documents(
    notebook_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # Yêu cầu phải có Token hợp lệ
):
    
    nb = db.query(Notebook).filter(Notebook.id == notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        raise HTTPException(status_code=404, detail="Notebook không tồn tại hoặc không thuộc quyền sở hữu.")

    docs = db.query(Document).filter(Document.notebook_id == notebook_id).all()
    return {"documents": [doc.filename for doc in docs]}

@router.post("/notebooks/{notebook_id}/upload/")
async def upload_document(
    notebook_id: int,
    file: UploadFile = File(...), 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ext = file.filename.split('.')[-1].lower()
    if ext not in ["pdf", "docx", "txt"]:
        return {"error": "Chỉ hỗ trợ .pdf, .docx, .txt"}

    # 1. KIỂM TRA QUYỀN SỞ HỮU
    nb = db.query(Notebook).filter(Notebook.id == notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        return {"error": "Notebook không hợp lệ."}

    # 2. KIỂM TRA GIỚI HẠN 10 TÀI LIỆU
    current_docs = db.query(Document).filter(Document.notebook_id == notebook_id).count()
    if current_docs >= 10:
        return {"error": "Notebook đã đạt giới hạn tối đa 10 tài liệu."}

    # 3. KIỂM TRA TRÙNG LẶP
    existing_doc = db.query(Document).filter(
        Document.notebook_id == notebook_id, 
        Document.filename == file.filename
    ).first()
    
    if existing_doc:
        return {"error": "Tài liệu này đã tồn tại trong Notebook này. Vui lòng đổi tên file khác."}

    # 4. LƯU FILE TẠM VÀ TRÍCH XUẤT VĂN BẢN
    temp_path = f"./storage/{file.filename}"
    os.makedirs("./storage", exist_ok=True)
    with open(temp_path, "wb") as f:
        f.write(await file.read())

    text = ""
    if ext == "pdf":
        # Cách 1: Đọc text layer thông thường bằng PyMuPDF
        doc = fitz.open(temp_path)
        text = "".join([page.get_text() for page in doc])
        
        # Cách 2: Kích hoạt OCR nếu PyMuPDF không đọc được chữ nào (PDF Scan/Ảnh)
        if len(text.strip()) < 50:
            print(f"Phát hiện PDF Scan ({file.filename}). Đang kích hoạt Tesseract OCR...")
            try:
                # Chuyển PDF thành danh sách hình ảnh
                images = convert_from_path(temp_path)
                ocr_text = []
                for img in images:
                    # Quét chữ trên từng ảnh, sử dụng model Tiếng Việt ('vie')
                    ocr_text.append(pytesseract.image_to_string(img, lang='vie'))
                
                text = "\n".join(ocr_text)
            except Exception as e:
                os.remove(temp_path)
                print(f"Lỗi OCR: {str(e)}")
                return {"error": "Hệ thống thiếu thư viện xử lý ảnh (Poppler/Tesseract) để đọc file Scan."}

    elif ext == "docx":
        doc = docx.Document(temp_path)
        text_parts = []
        
        # 1. Đọc các đoạn văn bản bình thường
        for p in doc.paragraphs:
            if p.text.strip():
                text_parts.append(p.text)
                
        # 2. Đọc và format các Bảng (Tables)
        for table in doc.tables:
            text_parts.append("\n[BẮT ĐẦU BẢNG]")
            for row in table.rows:
                # Gom text của các ô trong 1 hàng, cách nhau bằng dấu |
                row_data = [cell.text.replace('\n', ' ').strip() for cell in row.cells]
                text_parts.append(" | ".join(row_data))
            text_parts.append("[KẾT THÚC BẢNG]\n")
            
        text = "\n".join(text_parts)
    else:
        with open(temp_path, encoding="utf-8") as f:
            text = f.read()

    # Xử lý trường hợp file hoàn toàn là ảnh trống không có chữ
    if not text.strip():
        os.remove(temp_path)
        return {"error": "Không thể trích xuất được văn bản nào từ file này."}

    # 5. BĂM NHỎ TEXT VÀ LƯU VÀO CHROMADB
    chunks = chunk_text(text, chunk_size=20, overlap=5) 
    for i, chunk in enumerate(chunks):
        chunk_id = f"{notebook_id}_{file.filename}_{i}" 
        embedding = get_embedding(chunk)
        add_chunk(chunk_id, chunk, embedding, metadata={"notebook_id": notebook_id, "filename": file.filename})

    os.remove(temp_path)

    # 6. LƯU METADATA VÀO SQL
    new_doc = Document(notebook_id=notebook_id, filename=file.filename, filetype=ext)
    db.add(new_doc)
    db.commit()

    return {"message": f"Upload thành công file {file.filename} ({len(chunks)} chunks)"}

def extract_text(file_path, filetype):
    if filetype == "pdf":
        doc = fitz.open(file_path)
        return "".join([page.get_text() for page in doc])
    elif filetype == "docx":
        doc = docx.Document(file_path)
        return "\n".join([para.text for para in doc.paragraphs])
    elif filetype == "txt":
        with open(file_path, encoding="utf-8") as f:
            return f.read()
    raise ValueError("Unsupported filetype: " + filetype)

@router.post("/notebooks/{notebook_id}/documents/")
async def upload_document(
    notebook_id: int,
    user_id: int = Form(...),
    file: UploadFile = File(...)
):
    filename = file.filename
    ext = filename.split('.')[-1].lower()
    filetype = "pdf" if ext == "pdf" else "docx" if ext == "docx" else "txt" if ext == "txt" else None
    
    if not filetype:
        return {"error": "Unsupported file type"}
    
    notebook_folder = os.path.join(UPLOAD_ROOT, str(user_id), str(notebook_id))
    os.makedirs(notebook_folder, exist_ok=True)
    file_path = os.path.join(notebook_folder, filename)

    with open(file_path, "wb") as f:
        f.write(await file.read())
    
    raw_text = extract_text(file_path, filetype)
    chunks = chunk_text(raw_text, chunk_size=20, overlap=5)
    
    chunk_ids = []
    for i, chunk in enumerate(chunks):
        chunk_id = f"{notebook_id}_{filename}_{i}"
        embedding = get_embedding(chunk)
        metadata = {
            "chunk_index": i,
            "notebook_id": int(notebook_id), # ÉP KIỂU INT ĐỂ FILTER CHÍNH XÁC
            "filename": filename,
            "source_type": filetype
        }
        add_chunk(chunk_id, chunk, embedding, metadata)
        chunk_ids.append(chunk_id)
    
    return {"status": "success", "filename": filename, "chunks": len(chunks)}

# --- 5. XÓA TÀI LIỆU ---
@router.delete("/notebooks/{notebook_id}/documents/{filename}")
async def delete_document(
    notebook_id: int,
    filename: str, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 1. Xác thực Notebook có phải của User không
    nb = db.query(Notebook).filter(Notebook.id == notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        raise HTTPException(status_code=404, detail="Notebook không hợp lệ.")

    # 2. Tìm tài liệu đúng trong Notebook đó
    doc = db.query(Document).filter(
        Document.notebook_id == notebook_id, 
        Document.filename == filename
    ).first()
    
    if not doc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài liệu này.")

    try:
        # 3. Xóa vector chunks bằng cả notebook_id và filename
        collection.delete(
            where={
                "$and": [
                    {"notebook_id": notebook_id},
                    {"filename": filename}
                ]
            }
        )
        
        # 4. Xóa SQL
        db.delete(doc)
        db.commit()
        
        return {"message": f"Đã xóa thành công tài liệu: {filename}"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi khi xóa tài liệu: {str(e)}")