param (
    [string]$python_path,
    [string]$proxy = "http://192.168.0.100:7897"
)

$scriptUrl = "https://bootstrap.pypa.io/get-pip.py"

Write-Host "Python path: $python_path"
Write-Host "Proxy: $proxy"
Write-Host "Script URL: $scriptUrl"

# 查找*._pth
$pth = Get-ChildItem -Path $python_path -Filter "*._pth" -Recurse
if ($pth) {
    $pth | ForEach-Object {
        Write-Host "Found $($_.FullName)"
        $content = Get-Content -Path $_.FullName
        $newContent = @()
        $content | ForEach-Object {
            $line = $_
            if ($line -eq "#import site") {
                $line = "import site"
                Write-Host "Replace to `"$line`""
            }
            $newContent += $line
        }
        $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
        $streamWriter = [System.IO.StreamWriter]::new($_.FullName, $false, $utf8NoBOM)
        try {
            $newContent -split "`n" | ForEach-Object { $streamWriter.WriteLine($_) }
        } finally {
            $streamWriter.Close()
        }
    }
}

# 使用代理下载get-pip.py到$python_path，如果失败就用本地的
$localPipPath = "$PSScriptRoot\get-pip.py"
try {
    Write-Host "尝试从网络下载 get-pip.py..."
    Invoke-WebRequest -Uri $scriptUrl -OutFile "$python_path\get-pip.py" -Proxy $proxy -ErrorAction Stop
    Write-Host "下载成功!"
} catch {
    Write-Host "网络下载失败: $($_.Exception.Message)"
    if (Test-Path $localPipPath) {
        Write-Host "使用本地 get-pip.py 文件"
        Copy-Item -Path $localPipPath -Destination "$python_path\get-pip.py" -Force
    } else {
        Write-Host "错误: 本地备份文件 $localPipPath 不存在!" -ForegroundColor Red
        exit 1
    }
}

# 工作目录切换到$python_path
Write-Host "Set-Location -Path $python_path"
Set-Location -Path $python_path
# 执行get-pip.py
& $python_path\python.exe get-pip.py