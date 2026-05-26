from fastapi import FastAPI
from pydantic import BaseModel
import requests

app = FastAPI()

class ChatRequest(BaseModel):
    query: str
    ledger_context: dict

@app.post("/api/chat")
def chat_with_agent(req: ChatRequest):
    # This is where your LangGraph/Qwen integration goes.
    # For now, here is a simple direct call to your local Ollama server:
    
    system_prompt = f"You are Eleghart AI, a financial CFO. User data context: {req.ledger_context}"
    
    ollama_response = requests.post("http://localhost:11434/api/generate", json={
        "model": "qwen2.5", # Ensure you have downloaded this model via Ollama
        "prompt": f"{system_prompt}\n\nUser: {req.query}",
        "stream": False
    })
    
    return {"reply": ollama_response.json()["response"]}