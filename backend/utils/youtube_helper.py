import re
from youtube_transcript_api import YouTubeTranscriptApi
from fastapi import HTTPException

def extract_video_id(url: str) -> str:
    """Hàm dùng Regex để bóc tách ID video từ link YouTube"""
    pattern = r'(?:v=|\/)([0-9A-Za-z_-]{11}).*'
    match = re.search(pattern, url)
    if match:
        return match.group(1)
    raise HTTPException(status_code=400, detail="Link YouTube không hợp lệ!")

def get_youtube_transcript(url: str) -> str:
    """Hàm cào phụ đề theo chuẩn API mới nhất (khởi tạo Object)"""
    try:
        video_id = extract_video_id(url)
        
        # 1. Khởi tạo đối tượng API (Điểm khác biệt cốt lõi ở đây)
        yt_api = YouTubeTranscriptApi()
        
        # 2. Dùng hàm fetch() để kéo phụ đề về (ưu tiên tiếng Việt, sau đó tiếng Anh)
        transcript_data = yt_api.fetch(video_id, languages=['vi', 'en'])
        
        # 3. Nối tất cả các đoạn text lại với nhau
        full_text = " ".join([item.text for item in transcript_data])
        return full_text
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Lỗi trích xuất phụ đề: {str(e)}")