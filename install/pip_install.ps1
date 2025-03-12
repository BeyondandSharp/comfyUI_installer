param (
    [string]$python_path,
    [string]$proxy = "http://192.168.0.100:7897"
)

$scriptUrl = "https://bootstrap.pypa.io/get-pip.py"

Write-Host "Python path: $python_path"
Write-Host "Proxy: $proxy"
Write-Host "Script URL: $scriptUrl"

# ����*._pth
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

# ʹ�ô�������get-pip.py��$python_path�����ʧ�ܾ��ñ��ص�
$localPipPath = "$PSScriptRoot\get-pip.py"
try {
    Write-Host "���Դ��������� get-pip.py..."
    Invoke-WebRequest -Uri $scriptUrl -OutFile "$python_path\get-pip.py" -Proxy $proxy -ErrorAction Stop
    Write-Host "���سɹ�!"
} catch {
    Write-Host "��������ʧ��: $($_.Exception.Message)"
    if (Test-Path $localPipPath) {
        Write-Host "ʹ�ñ��� get-pip.py �ļ�"
        Copy-Item -Path $localPipPath -Destination "$python_path\get-pip.py" -Force
    } else {
        Write-Host "����: ���ر����ļ� $localPipPath ������!" -ForegroundColor Red
        exit 1
    }
}

# ����Ŀ¼�л���$python_path
Write-Host "Set-Location -Path $python_path"
Set-Location -Path $python_path
# ִ��get-pip.py
& $python_path\python.exe get-pip.py