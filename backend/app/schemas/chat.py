from pydantic import BaseModel
from typing import List, Optional

class ChatMessage(BaseModel):
    role: str  # 'user' or 'model'
    content: str

class ChatRequest(BaseModel):
    query: str
    history: Optional[List[ChatMessage]] = []
    crop_id: Optional[int] = None
    language: Optional[str] = None

class ChatResponse(BaseModel):
    answer: str
    context_used: List[str]
