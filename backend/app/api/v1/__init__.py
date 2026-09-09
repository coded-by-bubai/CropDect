# V1 API Package

from fastapi import APIRouter
from app.api.v1 import users, auth, farms, crops, knowledge_base, diagnostics, experts, labs, monitoring, notifications, chat, analytics, admin

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(farms.router, prefix="/farms", tags=["farms"])
api_router.include_router(crops.router, prefix="/crops", tags=["crops"])
api_router.include_router(knowledge_base.router, prefix="/knowledge-base", tags=["knowledge-base"])
api_router.include_router(diagnostics.router, prefix="/diagnostics", tags=["diagnostics"])
api_router.include_router(experts.router, prefix="/experts", tags=["experts"])
api_router.include_router(labs.router, prefix="/labs", tags=["labs"])
api_router.include_router(monitoring.router, prefix="/monitoring", tags=["monitoring"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])

