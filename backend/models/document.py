from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
import datetime
from database import Base

class Document(Base):
    __tablename__ = "documents"
    
    id = Column(Integer, primary_key=True, index=True)
    notebook_id = Column(Integer, ForeignKey("notebooks.id"))
    filename = Column(String, index=True)
    filetype = Column(String)
    content = Column(String)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    notebook = relationship("Notebook", back_populates="documents")