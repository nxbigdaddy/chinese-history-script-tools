# API配置
$API_ENDPOINT = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
$API_KEY = "YOUR_SECRET"
$MODEL_NAME = "kimi-k2.5"

# 设置路径
$baseDir = "D:\code\50000"
$listFile = "$baseDir\list.txt"
$outputDir = "$baseDir\502"
$progressFile = "$baseDir\progress.json"

# 检查list.txt是否存在
if (-not (Test-Path $listFile)) {
    Write-Host "错误：找不到 list.txt 文件！路径: $listFile" -ForegroundColor Red
    exit 1
}

# 创建输出目录（如果不存在）
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "已创建输出目录: $outputDir" -ForegroundColor Green
}

# 读取进度文件（如果存在）
$progress = @{
    completed = @()
    failed = @()
    lastUpdate = $null
}
if (Test-Path $progressFile) {
    try {
        $savedProgress = Get-Content -Path $progressFile -Encoding UTF8 | ConvertFrom-Json
        if ($savedProgress.completed) { $progress.completed = $savedProgress.completed }
        if ($savedProgress.failed) { $progress.failed = $savedProgress.failed }
        Write-Host "已读取进度文件，已完成: $($progress.completed.Count) 个，失败: $($progress.failed.Count) 个" -ForegroundColor Cyan
    }
    catch {
        Write-Host "进度文件读取失败，将重新开始" -ForegroundColor Yellow
    }
}

# 保存进度函数
function Save-Progress {
    $progress.lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $progress | ConvertTo-Json -Depth 10 | Out-File -FilePath $progressFile -Encoding UTF8
}

# 清理文件名中的非法字符
function Clean-FileName {
    param ([string]$fileName)
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($char in $invalidChars) {
        $fileName = $fileName.Replace($char.ToString(), "")
    }
    $fileName = $fileName -replace '[\s\t\n\r]', ''
    return $fileName
}

# 定义生成故事的函数 - 关键修复：使用UTF-8字节数组发送请求
function Generate-Story {
    param (
        [string]$storyTitle,
        [string]$category
    )
    
    $systemPrompt = "你是一位专为12岁以下儿童讲故事的亲切narrator。请创作一篇适合5分钟讲述的旁白文稿。

要求：
1. 语言生动活泼、简单易懂，使用适合儿童理解的词汇和句式
2. 故事内容要有趣味性，可以适当加入拟声词、对话和情感描述
3. 避免暴力、恐怖或过于复杂的成人内容，用儿童能接受的方式讲述历史
4. 开头要有吸引人的开场白（如'亲爱的小朋友们，今天我要给大家讲一个...'）
5. 结尾要有温暖的总结和启发（如'这个故事告诉我们...'）
6. 严格控制字数在1200-1300个汉字之间，确保朗读时长约5分钟
7. 保持历史故事的核心事实，但可以用童话般的叙述方式

输出要求：
- 不要包含任何标题或文件名
- 不要包含'旁白：'或'故事开始'等标记
- 直接输出纯净的文稿内容
- 使用中文标点符号"

    $userPrompt = "请为以下故事创作旁白文稿：`n故事题目：《$storyTitle》`n故事类型：$category`n`n请直接输出故事内容，不要有任何额外说明。"

    try {
        # 构建请求体
        $body = @{
            model = $MODEL_NAME
            messages = @(
                @{
                    role = "system"
                    content = $systemPrompt
                },
                @{
                    role = "user"
                    content = $userPrompt
                }
            )
            temperature = 0.7
            max_tokens = 2000
        } | ConvertTo-Json -Depth 10
        
        # 关键修复：将JSON字符串转为UTF-8字节数组，避免PowerShell默认编码问题
        $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        
        # 设置请求头
        $headers = @{
            "Authorization" = "Bearer $API_KEY"
            "Content-Type" = "application/json; charset=utf-8"
        }
        
        # 发送请求 - 使用字节数组作为Body
        $response = Invoke-RestMethod -Uri $API_ENDPOINT -Method Post -Headers $headers -Body $utf8Bytes -TimeoutSec 180
        
        if ($response.choices -and $response.choices[0].message.content) {
            $content = $response.choices[0].message.content.Trim()
            
            # 验证内容是否包含中文
            if ($content -match '[\u4e00-\u9fa5]') {
                return $content
            }
            else {
                Write-Host " (警告：API返回内容不含中文)" -ForegroundColor Red -NoNewline
                $preview = $content.Substring(0, [Math]::Min(50, $content.Length))
                Write-Host " 预览: $preview" -ForegroundColor DarkGray
                return $null
            }
        }
        else {
            throw "API返回格式异常"
        }
    }
    catch {
        Write-Host " API错误: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 读取list.txt内容
$content = Get-Content -Path $listFile -Encoding UTF8

# 解析所有故事
$stories = @()
foreach ($line in $content) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    
    if ($line -match '^\s*(\d+)\.\s*([^(]+?)(?:\s*\(([^)]+)\))?\s*$') {
        $stories += @{
            number = $matches[1].Trim()
            name = $matches[2].Trim()
            category = if ($matches[3]) { $matches[3].Trim() } else { "未分类" }
        }
    }
}

$total = $stories.Count
$successCount = $progress.completed.Count
$failedCount = $progress.failed.Count

Write-Host "共发现 $total 个故事，已完成: $successCount，失败: $failedCount`n" -ForegroundColor Cyan

# 处理每个故事
$current = 0
foreach ($story in $stories) {
    $current++
    $number = $story.number
    $storyName = $story.name
    $category = $story.category
    $storyKey = "$number.$storyName"
    
    # 检查是否已完成
    if ($progress.completed -contains $storyKey) {
        Write-Host "[$current/$total] $storyName [已完成，跳过]" -ForegroundColor Gray
        continue
    }
    
    Write-Host "[$current/$total] 正在生成: $storyName ..." -ForegroundColor Yellow -NoNewline
    
    # 构建文件名
    $cleanName = Clean-FileName -fileName $storyName
    $fileName = "$number$cleanName.txt"
    $filePath = Join-Path $outputDir $fileName
    
    # 调用API生成故事
    $storyContent = Generate-Story -storyTitle $storyName -category $category
    
    if ($storyContent -and $storyContent.Length -gt 100) {
        # 写入文件（使用UTF8带BOM）
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($filePath, $storyContent, $utf8WithBom)
        
        # 计算字数
        $charCount = ($storyContent -replace '[^\p{IsCJKUnifiedIdeographs}]', '').Length
        
        # 更新进度
        $progress.completed += $storyKey
        if ($progress.failed -contains $storyKey) {
            $progress.failed = $progress.failed | Where-Object { $_ -ne $storyKey }
        }
        Save-Progress
        
        Write-Host " [成功，${charCount}字]" -ForegroundColor Green
        $successCount++
    }
    else {
        # 记录失败
        if ($progress.failed -notcontains $storyKey) {
            $progress.failed += $storyKey
            Save-Progress
        }
        Write-Host " [失败]" -ForegroundColor Red
        $failedCount++
    }
    
    # 添加延迟
    Start-Sleep -Seconds 2
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "任务完成！" -ForegroundColor Green
Write-Host "总计: $total | 成功: $successCount | 失败: $failedCount" -ForegroundColor White
Write-Host "文件保存在: $outputDir" -ForegroundColor Cyan
Write-Host "进度文件: $progressFile" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($progress.failed.Count -gt 0) {
    Write-Host "`n以下故事生成失败，可重新运行脚本重试：" -ForegroundColor Yellow
    $progress.failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}