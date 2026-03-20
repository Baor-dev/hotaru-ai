from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
import datetime
from database import Base

class Notebook(Base):
    __tablename__ = "notebooks"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    owner = relationship("User", back_populates="notebooks")
    # Quan hệ 1-N với Document
    documents = relationship("Document", back_populates="notebook", cascade="all, delete-orphan")
    messages = relationship("Message", back_populates="notebook", cascade="all, delete-orphan")