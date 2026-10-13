# 测试1：直接curl测试
curl -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions `
  -H "Authorization: Bearer YOUR_API_TOKEN" `
  -H "Content-Type: application/json; charset=utf-8" `
  -d '{"model":"kimi-k2.5","messages":[{"role":"user","content":"你好，请用中文回复"}]}'