import json
import os
import re
from typing import List, Optional
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from openai import OpenAI
from dotenv import load_dotenv
from sentence_transformers import CrossEncoder

from database import get_db
from models.user import User
from models.notebook import Notebook
from models.message import Message
from models.document import Document
from utils.auth import get_current_user
from utils.embedding import get_embedding
from utils.vectorstore import collection

load_dotenv()
# ==========================================
# KHAI BÁO PROMPT CHO CÁC LUỒNG XỬ LÝ
# ==========================================
RAG_SYSTEM_PROMPT = """
Bạn là chuyên gia phân tích tài liệu.
CHỈ sử dụng NGỮ CẢNH MỚI NHẤT để trả lời. Không tự bịa thông tin.
Nếu NGỮ CẢNH rỗng, BẮT BUỘC trả lời: "Không đủ thông tin trong tài liệu hiện tại."
BẮT BUỘC trích dẫn nguồn (ví dụ: [1], [2]) ở cuối câu chứa thông tin đó.
"""

TRANSFORM_SYSTEM_PROMPT = """
Bạn là trợ lý AI thông minh chuyên xử lý ngôn ngữ.
Nhiệm vụ của bạn là thực hiện yêu cầu (Dịch thuật, tóm tắt, viết lại...) dựa trên nội dung được cung cấp.
KHÔNG CẦN trích dẫn nguồn [1], [2]. Trả lời trực tiếp, tự nhiên, đúng trọng tâm.
"""

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    raise ValueError("Chưa cấu hình OPENAI_API_KEY trong file .env")

# Chỉ cần truyền API Key, thư viện tự động biết trỏ về Server của OpenAI
client = OpenAI(api_key=OPENAI_API_KEY)

router = APIRouter()

print("Đang khởi tạo AI Re-ranker Model vào RAM...")
reranker = CrossEncoder("cross-encoder/mmarco-mMiniLMv2-L12-H384-v1")
print("AI Re-ranker đã sẵn sàng hoạt động!")

class ChatRequest(BaseModel):
    notebook_id: int
    query: str
    selected_docs: Optional[List[str]] = Field(default_factory=list)

@router.get("/notebooks/{notebook_id}/history/")
async def get_history(
    notebook_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 1. Xác thực quyền (Giữ nguyên)
    nb = db.query(Notebook).filter(Notebook.id == notebook_id, Notebook.user_id == current_user.id).first()
    if not nb:
        return {"history": []}
        
    # 2. Lấy toàn bộ tin nhắn theo thứ tự thời gian
    messages = (
        db.query(Message)
        .filter(Message.notebook_id == notebook_id)
        .order_by(Message.created_at.asc())
        .all()
    )
    
    history = []
    current_pair = None

    for msg in messages:
        if msg.role == "user":
            # Nếu gặp tin nhắn User mới, tạo một cặp Chat mới
            current_pair = {
                "question": msg.content,
                "answer": "",
                "sources": []
            }
            history.append(current_pair)
        
        elif msg.role == "ai" and current_pair is not None:
            # Nếu gặp tin nhắn AI, điền vào cái 'answer' của cặp User gần nhất
            ai_raw_content = msg.content
            answer_text = ai_raw_content
            sources_data = []
            
            if " |||SOURCES||| " in ai_raw_content:
                parts = ai_raw_content.split(" |||SOURCES||| ")
                answer_text = parts[0]
                try:
                    sources_data = json.loads(parts[1])
                except:
                    pass
            
            current_pair["answer"] = answer_text
            current_pair["sources"] = sources_data

    return {"history": history}

def classify_intent(query: str) -> str:
    q = query.lower().strip()

    doc_refs = [
        "tài liệu này", "file này", "văn bản này",
        "pdf này", "docx này"
    ]
    transform_patterns = [
        r'dịch', r'tóm tắt', r'viết lại', r'giải thích', r'rút gọn'
    ]
    meta_patterns = [
        r'nguồn', r'tài liệu nào', r'lấy từ đâu', 
        r'file nào', r'source', r'from where'
    ]

    has_doc = any(ref in q for ref in doc_refs)
    has_transform = any(re.search(p, q) for p in transform_patterns)
    has_meta = any(re.search(p, q) for p in meta_patterns)

    if has_doc and has_transform:
        return "transform_doc"
    if has_doc:
        return "rag"
    if has_meta:
        return "meta"
    if has_transform:
        return "transform_chat"

    return "rag"

# ==========================================
# BỘ TỪ ĐIỂN GIAO TIẾP CƠ BẢN (SMALL TALK / FAQ)
# ==========================================
def get_faq_answer(query: str) -> str:
    """
    Quét câu hỏi của người dùng, nếu khớp với các câu giao tiếp cơ bản 
    thì trả về luôn câu trả lời định sẵn. Nếu không khớp, trả về chuỗi rỗng.
    """
    q = query.lower().strip()
    
    # Chuẩn hóa: xóa bớt các dấu câu ở cuối câu (?!.) để so sánh dễ hơn
    q = re.sub(r'[?!.]+$', '', q).strip()

    # 1. Nhóm chào hỏi
    if q in ["hi", "hello", "xin chào", "chào", "chào bạn", "chào bot", "hé lô", "hi bot"]:
        return "Chào bạn! Mình là Hotaru AI. Mình có thể giúp gì cho bạn hôm nay?"
        
    # 2. Nhóm hỏi danh tính
    if q in ["bạn là ai", "hotaru ai là gì", "mày là ai", "bạn là gì", "hotaru là gì"]:
        return "Mình là Hotaru AI, một trợ lý ảo thông minh. Nhiệm vụ của mình là giúp bạn đọc, phân tích tài liệu và tóm tắt thông tin một cách nhanh chóng nhất!"
        
    # 3. Nhóm hỏi người tạo ra
    if q in ["ai tạo ra bạn", "ai đẻ ra mày", "ai lập trình ra bạn", "bạn của công ty nào"]:
        return "Mình được phát triển bởi các kỹ sư tài năng để trở thành trợ lý đắc lực cho bạn trong công việc."
        
    # 4. Nhóm cảm ơn
    if q in ["cảm ơn", "thank you", "thanks", "cảm ơn bạn", "tuyệt vời", "ok cảm ơn"]:
        return "Không có chi! Nếu bạn cần phân tích thêm tài liệu nào thì cứ gọi mình nhé."

    # Không khớp với từ điển thì trả về rỗng để nhường cho AI thật xử lý
    return ""

@router.post("/chat/")
async def chat(
    request: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # ==========================================
    # 1. KIỂM TRA BẢO MẬT & PHÂN QUYỀN
    # ==========================================
    nb = (
        db.query(Notebook)
        .filter(Notebook.id == request.notebook_id, Notebook.user_id == current_user.id)
        .first()
    )
    if not nb:
        raise HTTPException(status_code=403, detail="Notebook không hợp lệ hoặc không có quyền truy cập.")
    
    nb_id = request.notebook_id

    # ==========================================
    # 2. LƯU TIN NHẮN USER VÀ CHUẨN BỊ LỊCH SỬ
    # ==========================================
    new_user_msg = Message(notebook_id=nb_id, role="user", content=request.query)
    db.add(new_user_msg)
    db.commit()

    recent_messages = db.query(Message).filter(
        Message.notebook_id == nb_id,
        Message.id != new_user_msg.id,
    ).order_by(Message.created_at.desc()).limit(4).all()
    recent_messages.reverse()

    # ==========================================
    # 3. PHÂN LUỒNG XỬ LÝ (INTENT ROUTING)
    # ==========================================
    answer = ""
    unique_sources = [] 
    faq_answer = get_faq_answer(request.query)

    if faq_answer:
        answer = faq_answer
    else:
        intent = classify_intent(request.query)

        # ---------------------------------------------------
        # LUỒNG 1: XỬ LÝ LỊCH SỬ CHAT (Không dùng file)
        # ---------------------------------------------------
        if intent == "transform_chat":
            last_ai_msg = next((m for m in reversed(recent_messages) if m.role == "ai"), None)
            if not last_ai_msg:
                answer = "Không có nội dung trước đó để xử lý."
            else:
                context_text = last_ai_msg.content.split(" |||SOURCES||| ")[0]
                user_prompt = f"Nội dung cần xử lý:\n{context_text}\n\nYêu cầu:\n{request.query}"

                try:
                    response = client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=[
                            {"role": "system", "content": TRANSFORM_SYSTEM_PROMPT},
                            {"role": "user", "content": user_prompt}
                        ],
                        temperature=0.3 
                    )
                    answer = response.choices[0].message.content
                except Exception as e:
                    answer = f"Lỗi kết nối LLM: {str(e)}"
            
        # ---------------------------------------------------
        # LUỒNG 2: HỎI NGUỒN GỐC
        # ---------------------------------------------------
        elif intent == "meta":
            last_ai_msg = next((m for m in reversed(recent_messages) if m.role == "ai"), None)
            if last_ai_msg and " |||SOURCES||| " in last_ai_msg.content:
                try:
                    sources_str = last_ai_msg.content.split(" |||SOURCES||| ")[1]
                    saved_sources = json.loads(sources_str)
                    filenames = [s.get("filename", "Unknown") for s in saved_sources]
                    answer = f"Thông tin ở câu trả lời trước được lấy từ các tài liệu sau: {', '.join(filenames)}"
                    unique_sources = saved_sources 
                except:
                    answer = "Lỗi đọc nguồn tài liệu."
            else:
                answer = "Câu trả lời trước không trích xuất từ tài liệu cụ thể."

        # ---------------------------------------------------
        # LUỒNG 3 & 4: RAG VÀ TRANSFORM_DOC (Cần gọi ChromaDB)
        # ---------------------------------------------------
        else:
            all_docs = db.query(Document).filter(Document.notebook_id == nb_id).all()
            doc_map = {d.filename: d.id for d in all_docs if d.filename}
            
            processed_query = request.query.lower()
            valid_filenames = []

            for doc in all_docs:
                if not doc.filename: continue
                fname = doc.filename.lower().strip()
                if fname and fname in processed_query:
                    valid_filenames.append(fname)
                    processed_query = processed_query.replace(fname, "").strip()

            stop_words = ["phân tích", "tóm tắt", "đọc", "file", "tài liệu", "nội dung"]
            for word in stop_words:
                processed_query = processed_query.replace(word, "").strip()
                
            processed_query = re.sub(r'[^\w\s\+\#\.]', ' ', processed_query)
            processed_query = re.sub(r'\s+', ' ', processed_query).strip()

            search_query = processed_query if processed_query else request.query
            embedding = get_embedding(search_query) 

            if request.selected_docs:
                for doc_identifier in request.selected_docs:
                    if str(doc_identifier).isdigit():
                        fname = next((k for k, v in doc_map.items() if v == int(doc_identifier)), None)
                        if fname: valid_filenames.append(fname.lower().strip())
                    else:
                        valid_filenames.append(str(doc_identifier).lower().strip())

            where_clause = {"notebook_id": nb_id}
            if valid_filenames:
                where_clause = {"$and": [{"notebook_id": nb_id}, {"filename": {"$in": valid_filenames}}]}

            results = collection.query(
                query_embeddings=[embedding],
                n_results=15, 
                where=where_clause
            )
            
            raw_chunks = results["documents"][0] if results and results["documents"] else []
            raw_metadatas = results["metadatas"][0] if results and "metadatas" in results else []
            
            chunks = []
            metadatas = []
            
            if raw_chunks:
                sentence_pairs = [[request.query, chunk] for chunk in raw_chunks]
                try:
                    scores = reranker.predict(sentence_pairs)
                except:
                    scores = [float(len(sentence_pairs) - i) for i in range(len(sentence_pairs))]
                    
                scored_results = sorted(zip(scores, raw_chunks, raw_metadatas), key=lambda x: x[0], reverse=True)
                
                target_k = 6
                final_results = []
                seen_files = set()

                for item in scored_results:
                    fname = item[2].get("filename", "")
                    if fname not in seen_files:
                        final_results.append(item)
                        seen_files.add(fname)

                for item in scored_results:
                    if len(final_results) >= target_k: break
                    if item not in final_results: final_results.append(item)

                final_results.sort(key=lambda x: x[0], reverse=True)
                chunks = [item[1] for item in final_results]
                metadatas = [item[2] for item in final_results]
            
            context_parts = []
            for chunk, meta in zip(chunks, metadatas):
                fname = meta.get("filename", "Unknown")
                
                if fname not in [s["filename"] for s in unique_sources]:
                    doc_id = doc_map.get(fname, fname) 
                    unique_sources.append({
                        "ref_id": len(unique_sources) + 1, 
                        "filename": fname,
                        "id": doc_id 
                    })
                
                ref_map = {s["filename"]: s["ref_id"] for s in unique_sources}
                ref_id = ref_map[fname]
                context_parts.append(f"[Tài liệu {ref_id}]\nFile: {fname}\nNội dung:\n{chunk}\n")

            # Ghép context và giới hạn độ dài
            full_context = "\n".join(context_parts) if chunks else "(Không tìm thấy tài liệu liên quan)"
            MAX_CONTEXT_CHARS = 8000
            final_context = full_context[:MAX_CONTEXT_CHARS]

            # Phân tách luồng xử lý LLM dựa trên Intent
            if intent == "transform_doc":
                user_prompt = f"""[NGỮ CẢNH TỪ TÀI LIỆU]
{final_context}

[CHỈ THỊ CỦA NGƯỜI DÙNG]
{request.query}"""
                sys_prompt = """Bạn là trợ lý chuyên gia xử lý nội dung tài liệu.
Nhiệm vụ của bạn là thực hiện [CHỈ THỊ CỦA NGƯỜI DÙNG] dựa TRÊN ĐÚNG [NGỮ CẢNH TỪ TÀI LIỆU] được cung cấp.

BỘ QUY TẮC THỰC THI:
1. Xác định ý định: Đọc [CHỈ THỊ CỦA NGƯỜI DÙNG] để xác định họ muốn Dịch, Tóm tắt, Giải thích hay Viết lại.
2. Nếu là Dịch: Chuyển ngữ toàn bộ nội dung sang ngôn ngữ đích một cách tự nhiên, đúng văn phong.
3. Nếu là Tóm tắt: Giữ lại các luận điểm cốt lõi, loại bỏ từ ngữ rườm rà.
4. Nếu là Giải thích: Làm rõ các thuật ngữ chuyên môn, diễn đạt lại cho dễ hiểu.
5. Kỷ luật Dữ liệu: TUYỆT ĐỐI KHÔNG thêm thắt thông tin bên ngoài. KHÔNG bỏ sót dữ kiện quan trọng.
6. Định dạng: KHÔNG CẦN trích dẫn nguồn kiểu [1], [2]. Trả lời trực tiếp vào vấn đề."""
            
            else:  # Luồng RAG mặc định
                chat_history_text = ""
                if recent_messages:
                    chat_history_text = "=====================\nLỊCH SỬ HỘI THOẠI\n=====================\n"
                    for msg in recent_messages:
                        role_name = "Người dùng" if msg.role == "user" else "AI"
                        clean_content = msg.content.split(" |||SOURCES||| ")[0] 
                        chat_history_text += f"- {role_name}: {clean_content}\n"
                    chat_history_text += "\n"
                
                user_prompt = f"{chat_history_text}=====================\nNGỮ CẢNH MỚI NHẤT\n=====================\n{final_context}\n\n=====================\nCÂU HỎI HIỆN TẠI\n=====================\n{request.query}"
                sys_prompt = RAG_SYSTEM_PROMPT

            try:
                response = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[
                        {"role": "system", "content": sys_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    temperature=0.3 if intent == "transform_doc" else 0.1 
                )
                answer = response.choices[0].message.content
            except Exception as e:
                answer = f"Lỗi kết nối LLM: {str(e)}"

    # ==========================================
    # 4. LƯU CÂU TRẢ LỜI AI VÀO DB VÀ TRẢ VỀ API
    # ==========================================
    encoded_content = answer
    if unique_sources:
        sources_json = json.dumps(unique_sources)
        encoded_content = f"{answer} |||SOURCES||| {sources_json}"
    
    new_ai_msg = Message(notebook_id=nb_id, role="ai", content=encoded_content)
    db.add(new_ai_msg)
    db.commit()

    return {"answer": answer, "sources": unique_sources}
