#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import time
from pathlib import Path

def count_chinese_chars(text):
    """计算文本中的汉字数量"""
    return len(re.findall(r'[\u4e00-\u9fff]', text))

def generate_story_prompt(story_title):
    """生成故事提示词"""
    prompt = f"""你是一位专为12岁以下儿童讲故事的亲切 narrator。请根据提供的历史故事题目，创作一篇适合5分钟讲述的旁白文稿。

要求：
1. 语言生动活泼、简单易懂，使用适合儿童理解的词汇和句式
2. 故事内容要有趣味性，可以适当加入拟声词、对话和情感描述
3. 避免暴力、恐怖或过于复杂的成人内容，用儿童能接受的方式讲述历史
4. 开头要有吸引人的开场白（如"亲爱的小朋友们，今天我要给大家讲一个..."）
5. 结尾要有温暖的总结和启发（如"这个故事告诉我们..."）
6. 严格控制字数在1200-1300个汉字之间，确保朗读时长约5分钟（按正常语速每分钟240-260字计算）
7. 保持历史故事的核心事实，但可以用童话般的叙述方式

请严格按照以下格式输出：
- 不要包含任何标题或文件名
- 不要包含"旁白："或"故事开始"等标记
- 直接输出纯净的文稿内容
- 使用中文标点符号
- 确保文本编码为UTF-8

故事题目：{story_title}"""
    return prompt

def read_story_list(file_path):
    """读取故事列表"""
    stories = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('00001|'):
                # 提取序号和故事名称
                parts = line.split('. ', 1)
                if len(parts) == 2:
                    number = parts[0].replace('0000', '').replace('| ', '')
                    title_part = parts[1]
                    # 提取故事名称（去掉括号部分）
                    if ' (' in title_part:
                        story_name = title_part.split(' (')[0]
                    else:
                        story_name = title_part
                    stories.append((number, story_name))
    return stories

def main():
    # 创建输出目录
    output_dir = "上下五千年故事"
    os.makedirs(output_dir, exist_ok=True)
    
    # 读取故事列表
    story_list = read_story_list("list.txt")
    print(f"共找到 {len(story_list)} 个故事")
    
    # 模拟生成过程（实际使用时需要集成AI API）
    for i, (number, story_name) in enumerate(story_list, 1):
        filename = f"{number}.{story_name}.txt"
        filepath = os.path.join(output_dir, filename)
        
        # 检查是否已存在
        if os.path.exists(filepath):
            print(f"跳过已存在的文件: {filename}")
            continue
            
        print(f"正在生成第 {i}/{len(story_list)} 个故事: {story_name}")
        
        # 这里应该调用AI API生成故事内容
        # 由于需要实际的AI服务，这里提供伪代码示例
        story_content = f"""亲爱的小朋友们，今天我要给大家讲一个非常精彩的故事，这个故事叫做《{story_name}》。
        
[这里应该是由AI根据提示词生成的1200-1300字故事内容]

这个故事告诉我们，要学习故事中人物的优秀品质，勇敢面对生活中的挑战！"""
        
        # 验证字数
        chinese_count = count_chinese_chars(story_content)
        if chinese_count < 1200 or chinese_count > 1300:
            print(f"警告: {story_name} 字数不符合要求 ({chinese_count} 字)")
            # 实际使用时可能需要重新生成
        
        # 保存文件
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(story_content)
            
        print(f"已保存: {filename} ({chinese_count} 汉字)")
        
        # 避免请求过于频繁
        time.sleep(1)
    
    print("所有故事生成完成！")

if __name__ == "__main__":
    main()