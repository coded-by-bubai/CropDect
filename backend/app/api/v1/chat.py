from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.chat import ChatRequest, ChatResponse
from app.services import chat_service
from app.models.user import User

router = APIRouter()

@router.post("/ask", response_model=ChatResponse)
def ask_assistant(
    request: ChatRequest,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
):
    """
    Ask the AI agriculture assistant a question.
    """
    return chat_service.ask_assistant(db=db, request=request)
