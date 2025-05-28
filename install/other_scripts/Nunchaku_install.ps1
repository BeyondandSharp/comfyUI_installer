param (
    [string]$base_dir
)

# 如果没有指定路径，使用当前所在目录
if ([string]::IsNullOrEmpty($base_dir)) {
    $base_dir = Get-Location
    Write-Host "未指定工作目录，使用当前目录: $base_dir"
}
else {
    # 检查指定的路径是否存在
    if (Test-Path -Path $base_dir -PathType Container) {
        Write-Host "使用指定的工作目录: $base_dir"
    }
    else {
        Write-Error "指定的路径 '$base_dir' 不存在或不是一个目录"
        exit 1
    }
}

# 获取当前脚本的名称
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
$configFullName = "$scriptName.json"
$configBasePath = Join-Path -Path $base_dir -ChildPath $configFullName
Write-Host "configBasePath: $configBasePath" -ForegroundColor Green

# 获取当前脚本的路径
$script_path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$configScriptPath = Join-Path -Path $script_path -ChildPath $configFullName
Write-Host "configScriptPath: $configScriptPath" -ForegroundColor Green

if (Test-Path -Path $configBasePath) {
    $configPath = $configBasePath
} elseif (Test-Path -Path $configScriptPath) {
    $configPath = $configScriptPath
} else {
    Write-Host "未找到配置文件" -ForegroundColor Red
    exit 1
}
Write-Host "配置文件: $configPath" -ForegroundColor Green

$python = "python"
# 查询base_dir下有没有.venv，ember文件夹，有则按顺序使用其中的python
if (Test-Path -Path "$base_dir\.venv" -PathType Container) {
    # 尝试进入虚拟环境
    Write-Host "尝试激活虚拟环境"
    try{
        & .venv\Scripts\Activate
    } catch {
        Write-Error "无法激活虚拟环境，尝试其他"
    }
    
} else {
    Write-Host "查找嵌入式python"
    $emberFolders = Get-ChildItem -Path $base_dir -Directory -Recurse | Where-Object { $_.Name -like "*ember*" }
    Write-Host "找到以下包含'ember'的文件夹："
    foreach ($folder in $emberFolders) {
        Write-Host "- $($folder.FullName)"
        
        # 在文件夹中查找python.exe
        $pythonFiles = Get-ChildItem -Path $folder.FullName -Include "python.exe", "python" -File -Recurse -ErrorAction SilentlyContinue
        
        # 如果找到Python
        if ($pythonFiles.Count -gt 0) {
            $python = $pythonFiles[0].FullName
            Write-Host "  在此文件夹中找到Python: $python" -ForegroundColor Green
            break # 找到第一个就停止搜索
        }
    }

    if ($python -eq "python") {
        Write-Host "使用全局python" -ForegroundColor Red
    }
}

# 测试python是否可用
try {
    $python_version = & $python -V 2>&1
    $python_version = $python_version -replace "Python ", ""
    Write-Host "Python版本: $python_version" -ForegroundColor Green
} catch {
    Write-Error "无法找到Python可执行文件，请检查路径或安装Python"
    exit 1
}

# 查询torch版本
try {
    $torch_version = & $python -c "import torch; print(torch.__version__)" 2>&1
    Write-Host "Torch版本: $torch_version" -ForegroundColor Green
} catch {
    Write-Error "无法找到Torch模块，请检查安装"
    exit 1
}

# 判断当前系统是windows还是linux
$os = $env:OS
if ($os -eq "Windows_NT") {
    Write-Host "当前操作系统: Windows" -ForegroundColor Green
    $os = "win"
} else {
    Write-Host "当前操作系统: Linux" -ForegroundColor Green
    $os = "linux"
}

# 判断是否是64位
if ([Environment]::Is64BitOperatingSystem) {
    Write-Host "当前操作系统: 64位" -ForegroundColor Green
    $arch = "x86_64"
} else {
    Write-Host "当前操作系统: 32位" -ForegroundColor Green
    $arch = "x86"
}

# 读取配置文件
$config = Get-Content -Path $configPath | ConvertFrom-Json
$Nunchaku_whl_dir = $config.Nunchaku_whl_dir

# 获取版本
$Nunchaku_version = $config.version

if ($Nunchaku_version -eq "latest" -or $Nunchaku_version -eq "dev") {
    # 将Nunchaku_whl_dir下所有文件夹的名称存入数组
    $Nunchaku_whl_dirs = Get-ChildItem -Path $Nunchaku_whl_dir -Directory | Select-Object -ExpandProperty Name
    # 删除名称为prerelease的元素
    $Nunchaku_whl_dirs = $Nunchaku_whl_dirs_latest | Where-Object { $_ -ne "prerelease" }

    # 转换为字典，键为文件夹名称，值为release的类型
    $Nunchaku_whl_release_type = @{}
    foreach ($dir in $Nunchaku_whl_dirs) {
        $Nunchaku_whl_release_type[$dir] = ""
    }
    
    if ($Nunchaku_version -eq "dev"){
        $Nunchaku_whl_dir_dev = Join-Path -Path $Nunchaku_whl_dir -ChildPath "prerelease"
        # 将Nunchaku_whl_dir/prerelease下所有文件夹的名称存入数组
        $Nunchaku_whl_dirs_dev = Get-ChildItem -Path $Nunchaku_whl_dir_dev -Directory | Select-Object -ExpandProperty Name

        foreach ($dir in $Nunchaku_whl_dirs_dev) {
            $Nunchaku_whl_release_type[$dir] = "prerelease"
        }

        # 将Nunchaku_whl_dirs_dev中的元素添加到Nunchaku_whl_dirs中
        $Nunchaku_whl_dirs += $Nunchaku_whl_dirs_dev
    }

    # 按照名称倒序排序
    $Nunchaku_whl_dirs = $Nunchaku_whl_dirs | Sort-Object -Descending
    Write-Host "Nunchaku whl directories: $Nunchaku_whl_dirs" -ForegroundColor Green
} else {
    $Nunchaku_gitid = $Nunchaku_version
    # 在Nunchaku_whl_dir中查找名称为Nunchaku_gitid的文件夹，包括子文件夹
    $Nunchaku_whl_dir = Get-ChildItem -Path $Nunchaku_whl_dir -Directory -Recurse | Where-Object { $_.Name -eq $Nunchaku_gitid } | Select-Object -First 1
}

# python_version 3.12.10 ->312
$python_version = [Version]$python_version
$python_major = $python_version.Major
$python_minor = $python_version.Minor

# torch_version 2.7.0+cu128 -> 2.7
$torch_version = $torch_version -replace "\+.*", ""
$torch_version = [Version]$torch_version
$torch_major = $torch_version.Major
$torch_minor = $torch_version.Minor

# x86_64 -> amd64
if ($os -eq "win" -and $arch -eq "x86_64") {
    $arch = "amd64"
}

# 构建文件名
$Nunchaku_whl_pattern = "nunchaku-*+torch{5}.{6}-cp{3}{4}-cp{3}{4}-{1}_{2}.whl" -f $Nunchaku_version, $os, $arch, $python_major, $python_minor, $torch_major, $torch_minor
Write-Host "Nunchaku whl pattern: $Nunchaku_whl_pattern" -ForegroundColor Green

$Nunchaku_whl_path = $null

if ($Nunchaku_version -eq "latest" -or $Nunchaku_version -eq "dev") {
    # 遍历数组Nunchaku_whl_dirs
    foreach ($dir in $Nunchaku_whl_dirs) {
        $Nunchaku_whl_dir_full = Join-Path -Path $Nunchaku_whl_dir -ChildPath $Nunchaku_whl_release_type[$dir]
        $Nunchaku_whl_dir_full = Join-Path -Path $Nunchaku_whl_dir_full -ChildPath $dir
        Write-Host "Searching in directory: $Nunchaku_whl_dir_full"
        $Nunchaku_whl_obj = Get-ChildItem -Path $Nunchaku_whl_dir_full -Filter $Nunchaku_whl_pattern -File | Select-Object -First 1
        if ($Nunchaku_whl_obj) {
            $Nunchaku_whl_path = $Nunchaku_whl_obj.FullName
            break
        }
    }
} else {
    # 在$Nunchaku_whl_dir中查找符合Nunchaku_whl_pattern的文件
    $Nunchaku_whl_obj = Get-ChildItem -Path $Nunchaku_whl_dir -Filter $Nunchaku_whl_pattern -File | Select-Object -First 1
    $Nunchaku_whl_path = $Nunchaku_whl_obj.FullName
}

Write-Host "Nunchaku whl path: $Nunchaku_whl_path" -ForegroundColor Green
if ($null -eq $Nunchaku_whl_path) {
    Write-Error "未找到符合模式的whl文件，请检查配置文件和目录"
    exit 1
}

# 查询是否有uv
try {
    & $python -m uv --version 2>&1
    $install_cmd = "-m uv pip install --no-cache-dir $Nunchaku_whl_path"
} catch {
    Write-Error "无法找到uv模块，查询pip"
    try {
        & $python -m pip --version 2>&1
        $install_cmd = "-m pip install --no-cache-dir $Nunchaku_whl_path"
    } catch {
        Write-Error "无法找到pip模块，请检查安装"
        exit 1
    }
}

# 安装Nunchaku whl文件
try {
    Write-Host "安装Nunchaku whl文件: $Nunchaku_whl_path" -ForegroundColor Green
    Write-Host "install_cmd:$install_cmd"
    Start-Process -FilePath $python -ArgumentList $install_cmd -Wait -NoNewWindow
} catch {
    Write-Error "安装失败，请检查错误信息"
    exit 1
}
