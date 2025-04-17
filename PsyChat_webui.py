"""
Description: Streamlit WebUI for PsyChat multi-personality emotional support chatbot
Author: Jhy99
Date: 2025-04-17
"""

import os
import streamlit as st
from openai import OpenAI

st.logo("logo.png",size="large")
# Initialize API client
api_key = os.getenv("OPENAI_API_KEY") or os.getenv("DASHSCOPE_API_KEY")
if not api_key:
    st.error("环境变量 OPENAI_API_KEY 或 DASHSCOPE_API_KEY 未设置，请先配置 API Key。")
    st.stop()
client = OpenAI(api_key="0", base_url=os.getenv("BASE_URL", "http://101.201.76.166:8000/v1"))  # Default to local server

# Define personalities and prompts
PERSONALITIES = {
    "🧠 理性分析": {"prompt": "You are a rational analyst providing empathetic emotional support. Use clear logic and thoughtful guidance.", "avatar": "💡"},
    "😁 幽默风趣": {"prompt": "You are a humorous companion providing emotional support with wit and warmth. Use light-hearted humor to comfort.", "avatar": "😄"},
    "🌸 哲思温柔": {"prompt": "You are a philosophical and gentle guide offering emotional support with deep insights and soothing tone.", "avatar": "🌸"}
}

# Model configuration
MODEL_NAME = os.getenv("MODEL_NAME", "qwen-2.5-7b-psychat")
#MODEL_NAME = os.getenv("MODEL_NAME", "qwen-plus") 
MODEL_CONFIG = {"max_length": 512, "temperature": 0.9, "top_p": 0.8}

def llm_chat_via_api(system_prompt, messages):
    context = messages[-10:]
    full_messages = [{"role": "system", "content": system_prompt}] + context
    return client.chat.completions.create(
        model=MODEL_NAME,
        messages=full_messages,
        max_tokens=MODEL_CONFIG["max_length"],
        temperature=MODEL_CONFIG["temperature"],
        top_p=MODEL_CONFIG["top_p"],
        stream=True
    )

def main():
    st.set_page_config(page_title="PsyChat 情感支持助手", layout="wide")
    st.markdown(
        """
        <style>
        .stSidebar button { width: 100%; border-radius: 12px; margin: 8px 0; padding: 12px; font-size: 18px; border: 2px solid #ffd1a4; }
        .stSidebar button:hover { background-color: #ffd1a4;}
        </style>
        """, unsafe_allow_html=True
    )

    st.title("PsyChat 多人格情感支持")

    # Session state init
    if "history" not in st.session_state:
        st.session_state.history = {p: [] for p in PERSONALITIES}
    if "selected" not in st.session_state:
        st.session_state.selected = list(PERSONALITIES.keys())[0]

    # Sidebar for personality selection
    st.sidebar.image("PsyChatlogo.png",use_container_width=True)
    st.sidebar.header("选择情感支持人格")
    for p in PERSONALITIES:
        if st.sidebar.button(p, key=p):
            st.session_state.selected = p

    # Render chat history
    selected = st.session_state.selected
    avatar = PERSONALITIES[selected]["avatar"]
    history = st.session_state.history[selected]
    st.header(selected)
    for msg in history:
        role = msg["role"]
        av = avatar if role == "assistant" else "🧑‍💻"
        st.chat_message(role, avatar=av).write(msg["content"])

    # User input
    user_input = st.chat_input(f"与{selected}对话…")
    if user_input:
        # Append and display user message
        history.append({"role": "user", "content": user_input})
        st.chat_message("user", avatar="🧑‍💻").write(user_input)

        # Assistant streaming response
        system_prompt = PERSONALITIES[selected]["prompt"]
        stream = llm_chat_via_api(system_prompt, history)
        assistant_msg = st.chat_message("assistant", avatar=avatar)
        # Use write_stream to render and capture reply
        reply = assistant_msg.write_stream(stream)
        history.append({"role": "assistant", "content": reply})

if __name__ == "__main__":
    main()
