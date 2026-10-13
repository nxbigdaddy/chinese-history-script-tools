import pandas as pd

# 读取Excel文件
df = pd.read_excel('上下五千年完整故事目录（至五四运动）.xlsx')

# 生成列表格式
lines = []
for index, row in df.iterrows():
    line = f"{int(row[0])}. {row[1]} ({row[2]})"
    lines.append(line)

# 写入txt文件，使用UTF-8编码
with open('list.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print("转换完成！")