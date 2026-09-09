# AI Crop Disease Detector

A full-stack agricultural AI application featuring a PyTorch-powered backend for crop disease classification, a Retrieval-Augmented Generation (RAG) chatbot using Google Gemini, and a Flutter mobile/web application based on the AgroScan Intelligence design system.

## ✨ Key Features
- **AI Disease Detection:** PyTorch-based image classification for plant diseases.
- **RAG Gemini Chatbot:** Ask agricultural questions powered by Google Gemini and a custom knowledge base.
- **Role-Based Access Control:** Dedicated dashboards and workflows for **Farmers**, **Experts**, and **Admins**.
- **Expert Consultations & Follow-ups:** Farmers can log follow-ups and receive reviews directly from crop experts.
- **Automated IPM Plans:** AI-generated Integrated Pest Management (IPM) treatment plans.
- **GIS Hotspot Tracking:** Tracks disease outbreaks geographically using PostGIS.
- **Cloudinary Integration:** Fast, asynchronous image uploading.
- **Multi-Platform Support:** Works on Android, iOS, and Web.

## 1. Prerequisites

Before running the project, ensure you have the following installed:
- **Python 3.10+** (for the backend)
- **PostgreSQL & PostGIS** (for geospatial hotspot tracking)
- **Flutter SDK** (for the mobile/web frontend)
- **Android Studio / Xcode** (for running mobile emulators)

## 2. Running the Backend (FastAPI + PyTorch)

The backend powers the AI ML model, the Gemini chatbot, and the core database APIs.

1. Open a terminal and navigate to the backend folder:
   ```bash
   cd backend
   ```
2. Activate the Python virtual environment:
   ```bash
   # On Windows
   .\venv\Scripts\activate
   ```
3. Ensure your PostgreSQL database is running and the `.env` credentials are correct. (Requires Cloudinary & Gemini API keys).
4. Start the FastAPI server:
   ```bash
   uvicorn app.main:app --reload
   ```
   *The backend will now be running on http://127.0.0.1:8000*

## 3. Running the Frontend (Flutter App)

The frontend is the multi-platform application you interact with.

1. Open a **new** terminal window (keep the backend running).
2. Navigate to the frontend folder:
   ```bash
   cd cropdect
   ```
3. Connect a physical device via USB, open a mobile emulator, or use Chrome.
4. Run the app:
   ```bash
   flutter run
   ```

*Note: The Flutter app is configured to hit `10.0.2.2:8000` by default (the Android Emulator's local IP). If testing on a physical phone or Web, update `baseUrl` in `lib/api_client.dart` to your computer's local Wi-Fi IP address (e.g., `192.168.1.x`) or `127.0.0.1` for Web.*
