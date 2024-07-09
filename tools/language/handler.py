import os
import json
from tools.config import LANGUAGE

with open(os.path.join(os.path.dirname(__file__), 'message.json'), 'r', encoding='utf-8') as file:
    message = json.load(file)

async def MESSAGE(key: str) -> str:
    text = message[LANGUAGE][str(key)]
    return text