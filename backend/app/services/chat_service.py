from sqlalchemy.orm import Session
from app.models.knowledge_base import KnowledgeBase
from app.models.crop import Crop
from app.schemas.chat import ChatRequest, ChatResponse
from sqlalchemy import or_
from app.core.config import settings
from app.core.logging import logger

try:
    from google import genai
    from google.genai import types
except ImportError:
    genai = None

def ask_assistant(db: Session, request: ChatRequest) -> ChatResponse:
    # 1. Retrieval — broad keyword search across multiple KB fields
    query = request.query.lower()
    # Use all meaningful words (length > 2 to catch 'IPM', 'dry', etc.)
    keywords = [word.strip(".,!?") for word in query.split() if len(word.strip(".,!?")) > 2]

    search_filters = []
    for kw in keywords:
        search_filters.append(KnowledgeBase.name.ilike(f"%{kw}%"))
        search_filters.append(KnowledgeBase.symptoms.ilike(f"%{kw}%"))
        search_filters.append(KnowledgeBase.treatment_recommendations.ilike(f"%{kw}%"))
        search_filters.append(KnowledgeBase.prevention_strategies.ilike(f"%{kw}%"))
        search_filters.append(KnowledgeBase.affected_crops.ilike(f"%{kw}%"))

    db_query = db.query(KnowledgeBase)
    if search_filters:
        db_query = db_query.filter(or_(*search_filters))

    # Also optionally filter by crop if crop_id given
    if request.crop_id:
        crop = db.query(Crop).filter(Crop.id == request.crop_id).first()
        if crop:
            db_query = db_query.filter(
                KnowledgeBase.affected_crops.ilike(f"%{crop.crop_type}%")
            )

    retrieved_docs = db_query.limit(5).all()
    context_names = [doc.name for doc in retrieved_docs]

    # 2. Build context text from retrieved docs (if any)
    context_text = ""
    for doc in retrieved_docs:
        context_text += f"--- {doc.name} ---\n"
        if doc.symptoms:
            context_text += f"Symptoms: {doc.symptoms}\n"
        if doc.treatment_recommendations:
            context_text += f"Treatments: {doc.treatment_recommendations}\n"
        if doc.prevention_strategies:
            context_text += f"Prevention: {doc.prevention_strategies}\n"
        if doc.affected_crops:
            context_text += f"Affected Crops: {doc.affected_crops}\n"
        context_text += "\n"

    # 3. Always attempt Gemini — it has vast agronomic knowledge even without KB context
    if settings.GEMINI_API_KEY and genai:
        try:
            client = genai.Client(api_key=settings.GEMINI_API_KEY)

            lang_instruction = (
                f"Respond fluently in {request.language}."
                if request.language
                else "Detect the user's language from their message and respond fluently in that exact same language."
            )

            system_instruction = (
                "You are an expert agronomist and crop doctor for CropDect AI, an AI-powered crop disease detection platform. "
                f"{lang_instruction} "
                "You answer questions about crop diseases, pests, fertilizers, irrigation schedules, soil health, "
                "organic farming, integrated pest management (IPM), and general agronomy. "
                "IMPORTANT: Keep your answers VERY SHORT, concise, and summarized. Get straight to the point. "
                "Provide practical, farmer-friendly advice using brief bullet points. "
                "Include specific dosage rates, timing, and application methods when recommending treatments or fertilizers. "
                "If the user's knowledge base context is provided below, use it to ground your answer; "
                "otherwise draw on your own agronomic expertise. Never say you don't know — "
                "always provide the best possible brief guidance based on established agronomy science."
            )

            # Build multi-turn history contents
            contents = []
            for msg in (request.history or []):
                contents.append(
                    types.Content(
                        role=msg.role,
                        parts=[types.Part(text=msg.content)]
                    )
                )

            # Compose the current turn — inject RAG context only if found
            current_message = request.query
            if context_text:
                current_message += (
                    f"\n\n[Knowledge Base Context — use this to enhance your answer]\n{context_text}"
                )

            contents.append(
                types.Content(
                    role="user",
                    parts=[types.Part(text=current_message)]
                )
            )

            response = client.models.generate_content(
                model='gemini-3.6-flash',
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=0.4,
                    max_output_tokens=1200,
                )
            )
            return ChatResponse(answer=response.text, context_used=context_names)

        except Exception as e:
            logger.error(f"Gemini API Error: {e}")
            return ChatResponse(answer=f"DEBUG ERROR: {str(e)}", context_used=context_names)
