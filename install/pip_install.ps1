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
# 使用代理下载get-pip.py到$python_path
Invoke-WebRequest -Uri $scriptUrl -OutFile "$python_path\get-pip.py" -Proxy $proxy
# 工作目录切换到$python_path
Write-Host "Set-Location -Path $python_path"
Set-Location -Path $python_path
# 执行get-pip.py
& $python_path\python.exe get-pip.py