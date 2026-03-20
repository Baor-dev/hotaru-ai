from fastapi import APIRouter
from controllers import document_controller, chat_controller, auth_controller, notebook_controller
# from controllers import retrieval_controller # Nếu bạn cần dùng sau này

api_router = APIRouter()

# Nhúng các controller vào router chính
api_router.include_router(auth_controller.router, tags=["Authentication"])
api_router.include_router(notebook_controller.router, tags=["Notebook Management"])
api_router.include_router(chat_controller.router, tags=["Chat & Search"])
api_router.include_router(document_controller.router, tags=["Documents Management"])