from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Text
from sqlalchemy.orm import relationship
import datetime
from database import Base

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(Integer, primary_key=True, index=True)
    notebook_id = Column(Integer, ForeignKey("notebooks.id"))
    role = Column(String)  # Phân loại: "user" hoặc "ai"
    content = Column(Text) # Dùng Text thay vì String để lưu nội dung dài
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    notebook = relationship("Notebook", back_populates="messages")