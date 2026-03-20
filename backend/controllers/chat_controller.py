import requests
from typing import List, Optional
from fastapi import APIRouter, Form, Query, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from openai import OpenAI
from dotenv import load_dotenv

from database import get_db
from models.user import User
from models.notebook import Notebook
from models.message import Message
from utils.auth import get_current_user
from utils.embedding import get_embedding
from utils.vectorstore import collection

import os

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not GROQ_API_KEY:
    raise ValueError("Chưa cấu hình GROQ_API_KEY trong file .env")

client = OpenAI(
    api_key=GROQ_API_KEY, 
    base_url="https://api.groq.com/openai/v1"
)

router = APIRouter()

class ChatRequest(BaseModel):
    notebook_id: int
    query: str
    selected_docs: Optional[List[str]] = []

@router.get("/notebooks/{notebook_id}/history/")
async def get_history(
    notebook_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Xác thực quyền sở hữu Notebook
    nb = db.query(Notebook).filter(Notebook.id == notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        return {"history": []}
        
    messages = db.query(Message).filter(Message.notebook_id == notebook_id).order_by(Message.created_at.asc()).all()
    
    history = []
    for i in range(0, len(messages), 2):
        if i + 1 < len(messages):
            history.append({
                "question": messages[i].content,
                "answer": messages[i+1].content
            })
    return {"history": history}

@router.post("/chat/")
async def chat(
    request: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # Bắt buộc đăng nhập
):

    nb = db.query(Notebook).filter(Notebook.id == request.notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        return {"answer": "Notebook không hợp lệ."}
    
    nb_id = request.notebook_id

    new_user_msg = Message(notebook_id=nb_id, role="user", content=request.query)
    db.add(new_user_msg)
    db.commit()

    recent_messages = db.query(Message).filter(
        Message.notebook_id == nb_id,
        Message.id != new_user_msg.id # Không lấy câu vừa lưu
    ).order_by(Message.created_at.desc()).limit(4).all()

    recent_messages.reverse()

    chat_history_text = ""
    if recent_messages:
        chat_history_text = "LỊCH SỬ HỘI THOẠI TRƯỚC ĐÓ:\n"
        for msg in recent_messages:
            role_name = "Người dùng" if msg.role == "user" else "AI"
            chat_history_text += f"- {role_name}: {msg.content}\n"
        chat_history_text += "\n"

    embedding = get_embedding(request.query)
    where_clause = {"notebook_id": nb_id}
    if request.selected_docs and len(request.selected_docs) > 0:
        where_clause = {"$and": [{"notebook_id": nb_id}, {"filename": {"$in": request.selected_docs}}]}

    results = collection.query(query_embeddings=[embedding], n_results=3, where=where_clause)
    chunks = results["documents"][0] if results and results["documents"] else []
    
    context = "\n".join([f"Tài liệu [{i+1}]: {chunk}" for i, chunk in enumerate(chunks)])
    if not chunks:
        context = "(Không tìm thấy tài liệu liên quan)"

    prompt = f"""Bạn là một trợ lý AI thông minh, chuyên nghiệp và giao tiếp tự nhiên.
    
[NGỮ CẢNH HỘI THOẠI TRƯỚC ĐÓ]
{chat_history_text}

[TÀI LIỆU THAM KHẢO]
{context}

[CÂU HỎI HIỆN TẠI CỦA NGƯỜI DÙNG]
"{request.query}"

[QUY TẮC TRẢ LỜI NGHIÊM NGẶT - BẮT BUỘC TUÂN THỦ]
1. Trả lời TRỰC TIẾP vào câu hỏi. Nói thẳng vào vấn đề.
2. TUYỆT ĐỐI KHÔNG giải thích quá trình suy nghĩ. KHÔNG ĐƯỢC dùng các cụm từ như: "Dựa vào tài liệu...", "Trong lịch sử hội thoại...", "Theo nội dung được cung cấp...", "Để trả lời câu hỏi...".
3. Nếu tài liệu không có thông tin, hãy nói ngắn gọn: "Tài liệu hiện tại không chứa thông tin về vấn đề này."
4. Trình bày đẹp mắt: Dùng in đậm cho từ khóa quan trọng, dùng gạch đầu dòng (bullet points) nếu liệt kê.

Câu trả lời của bạn:
"""

    try:
        # Sử dụng client OpenAI đã cấu hình Groq ở đầu file
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant", # Model của Groq
            messages=[
                {"role": "user", "content": prompt}
            ],
            temperature=0.1
        )
        # Bóc tách câu trả lời từ JSON trả về
        answer = response.choices[0].message.content
    except Exception as e:
        answer = f"Lỗi kết nối Groq AI: {str(e)}"

    new_ai_msg = Message(notebook_id=nb_id, role="ai", content=answer)
    db.add(new_ai_msg)
    db.commit()

    return {"answer": answer}

# --- 2. API SEARCH (TEST VECTOR) ---
@router.post("/search/")
async def search_document(
    request: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Xác thực quyền sở hữu Notebook từ request.notebook_id
    nb = db.query(Notebook).filter(Notebook.id == request.notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        return {"results": []}
        
    nb_id = request.notebook_id
    embedding = get_embedding(request.query)
    
    where_clause = {"notebook_id": nb_id}
    if request.selected_docs and len(request.selected_docs) > 0:
        where_clause = {
            "$and": [
                {"notebook_id": nb_id},
                {"filename": {"$in": request.selected_docs}}
            ]
        }

    results = collection.query(
        query_embeddings=[embedding],
        n_results=5,
        where=where_clause
    )
    
    docs = results["documents"][0] if results and results["documents"] else []
    return {"results": [{"content": doc} for doc in docs]}