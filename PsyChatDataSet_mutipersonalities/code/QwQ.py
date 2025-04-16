import json
import os
from openai import OpenAI

# API 配置
API_KEY = os.getenv("DASHSCOPE_API_KEY")  
BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
MODEL ="qwq-plus-2025-03-05"  

# 初始化 OpenAI 客户端
client = OpenAI(
    api_key=API_KEY,
    base_url=BASE_URL
)

# 生成回答的函数
def generate_answer_via_api(title, description):
    """
    通过 API 生成回答，基于问题标题和描述。
    参数:
        title (str): 问题标题
        description (str): 问题描述
    返回:
        str: API 生成的完整回答
    """
    # 构建 Prompt
    prompt = (
        "请你以一位富有哲理思考力和温柔引导风格的心灵伙伴身份，基于下述的问题及其描述，生成一段富有同理心、深度反思性、并具有心理助益性的回复。"
        "请整合以下认知行为疗法的结构步骤，贯穿式地融入回答中，语言风格应富有哲思意味、使用引人深思的比喻、提问与洞见，创造一种温和探索、引导式对话的氛围。不要分点陈述，整合成一段流畅连贯的文字。"
        "1. 验证与共情：以温柔、诗意的语言回应患者的情感困境，让他们感受到被理解和陪伴。"
        "2. 识别关键思维或信念：捕捉其言语背后的潜在信念或认知模式，像是在沉静的湖面中观察内心的涟漪。"
        "3. 提出挑战或反思：提出开放式、带有哲思意味的问题，引导他们在心灵的花园中重新看待旧有信念。"
        "4. 提供策略或见解：提供柔和但富有启发性的见解，也可引用哲学或隐喻性表达，让策略变得具有意味。"
        "5. 鼓励与前瞻：鼓励他们以觉察之光照亮前行之路，理解成长是一场旅程，每一次思考的转折都是进步的起点。"
        f"问题:{title} 描述:{description}"
        "回答请直接生成内容，不需生成其他说明信息。"
        # "请你以一位幽默、机智、让人忍俊不禁但又恰到好处地戳中要点的情绪陪伴者身份，基于下述的问题及其描述，生成一段轻松风趣、带有心理洞察力的回复。"
        # "请整合以下认知行为疗法的结构步骤，以俏皮、类比、反差、轻松调侃的方式呈现。语言风格可以像在和老朋友聊天，但要确保内容背后仍有扎实的认知支持和帮助性洞见。不要分点陈述，整合成一段连贯、生动的文字。"
        # "1. 验证与共情：以轻松但真诚的方式接住用户的情绪，就像拍拍他们的肩说：‘我懂，这事儿够呛。’"
        # "2. 识别关键思维或信念：用风趣方式指出潜在的思维盲区，比如‘你是不是把事情从小土豆想成了世界末日披萨？’"
        # "3. 提出挑战或反思：提出出其不意但富有启发性的提问，引导他们‘换个脑回路’看问题。"
        # "4. 提供策略或见解：用有趣又实用的方法传达应对策略，比如‘给你的焦虑穿双拖鞋，让它别老满屋乱跑。’"
        # "5. 鼓励与前瞻：用幽默的方式鼓励他们，比如‘Rome wasn’t built in a day，但你可以今天先建个心理帐篷。’"
        # f"问题:{title} 描述:{description}"
        # "回答请直接生成内容，不需生成其他说明信息。"
    )
    
    # 创建流式聊天完成请求
    completion = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": prompt}],
        stream=True,
        max_tokens=1024,    # 控制生成的最大长度
        temperature=0.6,   # 控制创造性
        top_p=0.95         # 核采样参数
    )
    
    # 提取完整回答
    answer_content = ""
    is_answering = False
    
    for chunk in completion:
        if not chunk.choices:
            continue  # 跳过空 chunk
        delta = chunk.choices[0].delta
        # 如果有 reasoning_content，跳过（仅提取回答部分）
        if hasattr(delta, 'reasoning_content') and delta.reasoning_content is not None:
            continue
        # 开始提取回答
        if hasattr(delta, 'content') and delta.content is not None:
            if not is_answering:
                is_answering = True
            answer_content += delta.content
        
    print("回答内容:", answer_content)
    
    return answer_content

# 文件路径
input_file = "/Users/henryking/project/PsyChat/PsyQAset/cPsychQASet-Zh/wenda-data-29623.json"  # 输入数据集文件
output_file = "output.jsonl"  # 输出结果文件（JSON Lines 格式）

# 初始化输出文件（如果不存在）
if not os.path.exists(output_file):
    open(output_file, "w").close()

# 读取已处理的 q_id，避免重复处理
processed_q_ids = set()
if os.path.getsize(output_file) > 0:
    with open(output_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                item = json.loads(line.strip())
                processed_q_ids.add(item["q_id"])

# 读取输入数据
with open(input_file, "r", encoding="utf-8") as f:
    data = json.load(f)

# 逐条处理并保存
for item in data:
    q_id = item["q_id"]
    if q_id in processed_q_ids:
        print(f"跳过已处理的数据: {q_id}")
        continue
    title = item["title"]+"以哲理温柔型的人格给出建议"
    description = item["description"]
    try:
        # 生成回答
        answer = generate_answer_via_api(title, description)
        processed_item = {
            "q_id": q_id,
            "title": title,
            "description": description,
            "answer": answer
        }
        # 立即追加写入文件
        with open(output_file, "a", encoding="utf-8") as f:
            json.dump(processed_item, f, ensure_ascii=False)
            f.write("\n")
        print(f"已处理并保存: {q_id}")
    except Exception as e:
        print(f"处理 {q_id} 时出错: {e}")
        error_str = str(e)
        if "Error code: 400" or "Output data may contain inappropriate content" in error_str:
            print(f"处理 {q_id} 时遇到 HTTP 400 错误: {e}，跳过此条数据")
            continue  # 跳过当前条目，继续处理下一条
        else:
            print(f"处理 {q_id} 时出错: {e}")
            print("程序因非 400 错误停止执行")
            break  # 其他错误时停止执行

# 2200-2472用作测试集
# 2472条以后用作幽默人格
# 2979条以后用作哲理人格

print("处理完成，结果已保存到", output_file)