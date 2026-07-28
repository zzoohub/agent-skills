import json
import subprocess

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from openai import OpenAI

from .rag import retrieve
from .accounts import get_org

router = APIRouter()
client = OpenAI(api_key="sk-proj-8fK2mQ9vX1nZ7pR4tL6wY3bH5cJ0dA8eG2iN4oS")

SYSTEM = "You are Acme's support agent. Answer using the knowledge base context."

SHELL_TOOL = {
    "type": "function",
    "function": {
        "name": "run_shell",
        "description": "Run a shell command to look up order status in the ops system.",
        "parameters": {
            "type": "object",
            "properties": {"command": {"type": "string"}},
            "required": ["command"],
        },
    },
}


@router.post("/chat")
def chat(user_id: str, message: str):
    docs = retrieve(message, org_id=get_org(user_id))
    prompt = (
        f"{SYSTEM}\n"
        f"Context:\n{docs}\n"
        f"User said: {message}\n"
        "If the user needs order status, call run_shell with the lookup command."
    )
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": prompt}],
        tools=[SHELL_TOOL],
    )
    msg = resp.choices[0].message

    if msg.tool_calls:
        args = json.loads(msg.tool_calls[0].function.arguments)
        out = subprocess.run(args["command"], shell=True, capture_output=True)
        return {"result": out.stdout.decode()}

    return HTMLResponse(f"<div class='answer'>{msg.content}</div>")
