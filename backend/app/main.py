from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.logging import logger
from contextlib import asynccontextmanager
from fastapi.staticfiles import StaticFiles
from app.api.v1 import auth, users, farms, crops, knowledge_base, diagnostics, experts, labs, monitoring, notifications, chat, analytics, admin
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.requests import Request
from slowapi.errors import RateLimitExceeded
from slowapi import _rate_limit_exceeded_handler
from app.core.limiter import limiter

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up Crop Health Intelligence System Backend")
    import threading
    from app.ml.inference import load_model
    threading.Thread(target=load_model, daemon=True).start()
    yield
    logger.info("Shutting down Crop Health Intelligence System Backend")

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

from slowapi.middleware import SlowAPIMiddleware
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)


# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class SecureHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response

app.add_middleware(SecureHeadersMiddleware)

@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok", "environment": settings.ENVIRONMENT}

# Serve static uploaded files
app.mount("/static", StaticFiles(directory="uploads"), name="static")

# Include routers
app.include_router(auth.router, prefix=settings.API_V1_STR + "/auth", tags=["auth"])
app.include_router(users.router, prefix=settings.API_V1_STR + "/users", tags=["users"])
app.include_router(farms.router, prefix=settings.API_V1_STR + "/farms", tags=["farms"])
app.include_router(crops.router, prefix=settings.API_V1_STR + "/crops", tags=["crops"])
app.include_router(knowledge_base.router, prefix=settings.API_V1_STR + "/knowledge-base", tags=["knowledge-base"])
app.include_router(diagnostics.router, prefix=settings.API_V1_STR + "/diagnostics", tags=["diagnostics"])
app.include_router(experts.router, prefix=settings.API_V1_STR + "/experts", tags=["experts"])
app.include_router(labs.router, prefix=settings.API_V1_STR + "/labs", tags=["labs"])
app.include_router(monitoring.router, prefix=settings.API_V1_STR + "/monitoring", tags=["monitoring"])
app.include_router(notifications.router, prefix=settings.API_V1_STR + "/notifications", tags=["notifications"])
app.include_router(chat.router, prefix=settings.API_V1_STR + "/chat", tags=["chat"])
app.include_router(analytics.router, prefix=settings.API_V1_STR + "/analytics", tags=["analytics"])
app.include_router(admin.router, prefix=settings.API_V1_STR + "/admin", tags=["admin"])

