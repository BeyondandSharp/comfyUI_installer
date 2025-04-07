param (
    [string]$base_dir,
    [string]$bat_name,
    [string]$comfyui_installer_path
) 

$log_path = "$base_dir\comfyui_installer.log"

Start-Transcript -Path $log_path -Append -IncludeInvocationHeader

# 构建函数Write-Log，用于输出日志
function Write-Log {
    param (
        [string]$message
    )
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $log_message = "$time $message"
    Write-Output $message
}

function Refresh-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
}

Write-Log "base_dir: $base_dir"
Write-Log "bat_name: $bat_name"
Write-Log "comfyui_installer_path: $comfyui_installer_path"
# 测试是否有写入权限
$test_file = Join-Path -Path $base_dir -ChildPath "test.txt"
try {
    $null > $test_file
    Remove-Item -Path $test_file
    Write-Log "有写入权限"
} catch {
    Write-Log "没有写入权限"
    pause
    exit
}
# 测试文件夹中是否有bat_name之外的文件与文件夹，询问是否清理,不清理bat自身
$exclude_files = @($bat_name, "comfyui_installer.log")
$files = Get-ChildItem -Path $base_dir -Exclude $exclude_files
if ($files) {
    Write-Log "文件夹中有以下文件或文件夹："
    $files | ForEach-Object { Write-Log $_.Name }
    $choice = Read-Host "是否重新安装？(y重新安装/n更新)"
    if ($choice -eq "y") {
        #二次确认
        Write-Log "所有的模型与节点都将被删除，无法恢复，确认吗"
        $choice = Read-Host "是否清理？(y全部删除/n仅更新)"
        if ($choice -eq "y") {
            #再有5s延迟
            Write-Log "5s后清理...后悔的话请关闭窗口"
            Start-Sleep -Seconds 5
            Write-Log "清理中..."
            $files | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force}
        }
    }
}

# 读取配置文件config.json
Write-Log "读取配置文件"
# 测试base_dir\config.json是否存在
$config_path = Join-Path -Path $base_dir -ChildPath "config.json"
if (Test-Path -Path $config_path) {
    Write-Log "config_path: $config_path"
} else {
    $config_path = Join-Path -Path $comfyui_installer_path -ChildPath "config.json"
    if (Test-Path -Path $config_path) {
        Write-Log "config_path: $config_path"
    } else {
        Write-Log "未找到config.json"
        pause
        exit
    }
}
# 读取config.json
$config = Get-Content -Path $config_path | ConvertFrom-Json

#检测git是否已安装
$git_path = Get-Command -Name "git" -ErrorAction SilentlyContinue
if ($git_path) {
    Write-Log "Git已安装"
} else {
    #安装Git
    $git_installer_dir = $config.git_installer_dir
    Write-Log "git_installer_dir: $git_installer_dir"
    #查找git_installer_dir下最新的安装包
    $git_installer = Get-ChildItem -Path $git_installer_dir -File |
        Where-Object { $_.Name -match "Git-.*-64-bit.exe" } |
        Sort-Object { [Version]($_.Name -replace "Git-", "" -replace "-.*", "") } -Descending |
        Select-Object -First 1
    Write-Log "git_installer: $git_installer"
    # 静默安装Git
    Write-Log "Git安装中..."
    Start-Process -FilePath $git_installer.FullName -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-" -Wait -NoNewWindow
    #检测是否安装成功
    Refresh-Env
    $git_path = Get-Command -Name "git" -ErrorAction SilentlyContinue
    if ($git_path) {
        Write-Log "Git安装成功"
    } else {
        Write-Log "Git安装失败"
        pause
        exit
    }
}

#检测C++运行库是否已安装
$msvcDlls = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
)
$vc_installed = $true
foreach ($dll in $msvcDlls) {
    if (-not (Get-ChildItem -Path "C:\Windows\System32" -Filter $dll -ErrorAction SilentlyContinue)) {
        $vc_installed = $false
        Write-Output "$dll 未安装"
    } else {
        Write-Output "$dll 已安装"
    }
}
if ($vc_installed) {
    Write-Log "C++运行库已安装"
} else {
    #安装C++运行库
    $vc_redist_installer = $config.vc_redist_installer -replace "/", "\"
    Write-Log "vc_redist_installer: $vc_redist_installer"
    Write-Log "C++运行库安装中..."
    Start-Process -FilePath $vc_redist_installer -ArgumentList "/install /quiet /norestart" -Wait -NoNewWindow
    #检测是否安装成功
    Write-Log "检测C++运行库是否安装成功"
    $vc_redist = $true
    foreach ($dll in $msvcDlls) {
        if (-not (Get-ChildItem -Path "C:\Windows\System32" -Filter $dll -ErrorAction SilentlyContinue)) {
            $vc_redist = $false
            Write-Output "$dll 未安装"
        } else {
            Write-Output "$dll 已安装"
        }
    }
    if ($vc_redist) {
        Write-Log "C++运行库安装成功"
    } else {
        Write-Log "C++运行库安装失败"
        pause
        exit
    }
}

$http_proxy = $config.http_proxy
function proxy_switch{
    param (
        [bool]$switch
    )
    Write-Log "proxy_switch: $switch"
    if($switch){
        $env:HTTP_PROXY = $http_proxy
        $env:HTTPS_PROXY = $http_proxy
    } else {
        $env:HTTP_PROXY = $null
        $env:HTTPS_PROXY = $null
    }
}

# 安装uv
$uv_path = Get-Command -Name "uv" -ErrorAction SilentlyContinue
if ($uv_path) {
    Write-Log "uv已安装"
} else {
    Write-Log "uv未安装，安装中..."
    #安装uv
    proxy_switch $true
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    proxy_switch $false
    #检测是否安装成功
    Refresh-Env
    $uv_path = Get-Command -Name "uv" -ErrorAction SilentlyContinue
    if ($uv_path) {
        Write-Log "uv安装成功"
    } else {
        Write-Log "uv安装失败"
        pause
        exit
    }
}

$use_local_python = $config.use_local_python
$python = "python"
$python_version = $config.python_version
Write-Log "python_version: $python_version"
$pip = "pip"
if ($use_local_python) {
    # 测试是否存在python
    Write-Log "测试是否存在python"
    $hasPython_path = Get-Command -Name "python" -ErrorAction SilentlyContinue
    if ($hasPython_path) {
        & python --version
    } else {
        Write-Log "未找到python，请确认环境变量或修改配置文件"
    }
} else {
    if ($uv_path) {
        Write-Log "uv已安装，将跳过安装python"
    } else {
        Write-Log "uv未安装，使用常规安装"
        #安装python embed
        $python_installer_dir = $config.python_installer_dir
        Write-Log "python_installer_dir: $python_installer_dir"
        #获取需求的最新版本
        $python_embed_version_net = Get-ChildItem -Path $python_installer_dir -Directory |
            Where-Object { $_.Name -match "python-$python_version\.(\d+)-embed-amd64" } |
            Sort-Object { [int]($_.Name -replace "python-$python_version\.", "" -replace "-.*", "") } -Descending |
            Select-Object -First 1 |
            Select-Object -ExpandProperty Name
        $python_embed_version_net = $python_embed_version_net -replace "python-", "" -replace "-.*", ""
        Write-Log "python_embed_version_net: $python_embed_version_net"
        #检查$base_dir\python_embed\python.exe是否存在
        $python_embed_dir = Join-Path -Path $base_dir -ChildPath "python_embed"
        Write-Log "python_embed_dir: $python_embed_dir"
        $python_embed_exe = Join-Path -Path $python_embed_dir -ChildPath "python.exe"
        if (Test-Path -Path $python_embed_exe) {
            Write-Log "Python已安装"
            #检查python版本
            $python_version_current = & $python_embed_exe --version 2>&1
            $python_version_current = $python_version_current -replace "Python ", ""
        }
        Write-Log "python_version_current: $python_version_current"
        #如果python版本不匹配或者python_embed_dir不存在，则安装
        if ($python_version_current -ne $python_embed_version_net -or -not (Test-Path -Path $python_embed_dir)) {
            Write-Log "Python未安装或版本不匹配"
            if (Test-Path -Path $python_embed_dir) {
                Write-Log "删除旧$python_embed_dir"
                Remove-Item -Path $python_embed_dir -Recurse -Force
            }
            $python_embed_dir_net = Join-Path -Path $python_installer_dir -ChildPath "python-$python_embed_version_net-embed-amd64"
            Write-Log "复制$python_embed_dir_net 到 $python_embed_dir"
            Copy-Item -Path $python_embed_dir_net -Destination $python_embed_dir -Recurse -Force
            # 检查安装是否成功
            if (Test-Path -Path $python_embed_exe) {
                Write-Log "Python安装成功"
                $python = Join-Path -Path $python_embed_dir -ChildPath "python"
                #安装pip
                Write-Log "安装pip..."
                $pip_installer_path = Join-Path -Path $python_installer_dir -ChildPath "pip_installer\pip_install.ps1"
                & $pip_installer_path -python_path $python_embed_dir -proxy $http_proxy
                # 修改_pth
                # 查找*._pth
                $pth = Get-ChildItem -Path $python_embed_dir -Filter "*._pth" -Recurse
                if ($pth) {
                    $pth | ForEach-Object {
                        Write-Log "Found $($_.FullName)"
                        $content = Get-Content -Path $_.FullName
                        $newContent = @()
                        #在第一行添加../ComfyUI
                        $newContent += "../ComfyUI"
                        $newContent += $content
                        $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
                        $streamWriter = [System.IO.StreamWriter]::new($_.FullName, $false, $utf8NoBOM)
                        try {
                            $newContent -split "`n" | ForEach-Object { $streamWriter.WriteLine($_) }
                        } finally {
                            $streamWriter.Close()
                        }
                    }
                }
                # 检测pip是否安装成功
                if (Test-Path -Path $python_embed_dir\Scripts\pip.exe) {
                    Write-Log "pip安装成功"
                    $pip = Join-Path -Path $python_embed_dir -ChildPath "Scripts\pip"

                    #设置pip源
                    $pip_config = $config.pip_config
                    Write-Log "pip_ini: $pip_config"

                    #复制pip.ini到python_embed_dir\pip.ini
                    Copy-Item -Path $pip_config -Destination "$python_embed_dir\pip.ini" -Force
                } else {
                    Write-Log "pip安装失败"
                    pause
                    exit
                }
            } else {
                Write-Log "Python安装失败"
                pause
                exit
            }
        } else {
            Write-Log "Python已是需求的版本"
        }
    }
}

# 创建虚拟环境
if ($uv_path) {
    Write-Log "uv已安装，使用uv创建虚拟环境"
    $uv_config = $config.uv_config

    Write-Log "更新uv..."
    Start-Process -FilePath "uv" -ArgumentList "self update" -Wait -NoNewWindow

    $venv_cmd = "venv --config-file $uv_config --directory $base_dir --python $python_version --relocatable"
    try {
        Write-Log "创建虚拟环境中..."
        Start-Process -FilePath "uv" -ArgumentList $venv_cmd -Wait -NoNewWindow
    } catch {
        Write-Log "创建虚拟环境失败"
        pause
        exit
    }
    # 复制$comfyui_installer_path\pip文件夹到.venv\Lib\site-packages
    #Write-Log "复制$comfyui_installer_path\pip 到 $base_dir\.venv\Lib\site-packages"
    #$pip_dir = Join-Path -Path $base_dir -ChildPath ".venv\Lib\site-packages\pip"
    #Copy-Item -Path "$comfyui_installer_path\pip" -Destination $pip_dir -Recurse -Force

    Set-Location $base_dir
    # 激活虚拟环境
    Write-Log "激活虚拟环境中..."
    $venv_activate_cmd = "$base_dir\.venv\Scripts\activate"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $venv_activate_cmd" -Wait -NoNewWindow
    # 如果venv拒绝访问
    if ($?) {
        Write-Log "激活虚拟环境成功"
    } else {
        Write-Log "激活虚拟环境失败"
        pause
        exit
    }
    # 安装pip
    Write-Log "安装pip..."
    $pip_install_cmd = "pip install pip --config-file $uv_config"
    try {
        Start-Process -FilePath "uv" -ArgumentList $pip_install_cmd -Wait -NoNewWindow
    }
    catch {
        Write-Log "安装pip失败"
        pause
        exit
    }
}

# pip package install
function pip_install {
    param (
        [string]$r_path
    )
    if ($uv_path) {
        $requirements_cmd = "pip install -r $r_path --config-file $uv_config"
        Write-Log "安装 $r_path"
        Start-Process -FilePath "uv" -ArgumentList $requirements_cmd -Wait -NoNewWindow
        $requirements_cmd = "pip install -r $r_path --upgrade --config-file $uv_config"
        Write-Log "升级 $r_path"
        Start-Process -FilePath "uv" -ArgumentList $requirements_cmd -Wait -NoNewWindow
    } else {
        & $pip config list -v
        $requirements_cmd = "install -r $r_path"
        Write-Log "安装 $r_path"
        Start-Process -FilePath $pip -ArgumentList $requirements_cmd -Wait -NoNewWindow
        $requirements_cmd = "install -r $r_path --upgrade"
        Write-Log "升级 $r_path"
        Start-Process -FilePath $pip -ArgumentList $requirements_cmd -Wait -NoNewWindow
    }
}

$proxy_git = $config.proxy_git
Write-Log "proxy_git: $proxy_git"

function clone_finish {
    param (
        [string]$dir,
        [string]$cmd_clone,
        [string]$branch
    )
    # 包含.git以外的其他文件
    $childs = Get-ChildItem -Path $dir -Force -Exclude ".git"
    if ($childs.Count -gt 0) {
        Write-Log "克隆成功 $cmd_clone"
        
        #切换Branch（强制）
        if ($branch -ne "main" -and $branch -ne "master") {
            Write-Log "切换到 $branch 分支"
            Set-Location $dir
            Start-Process -FilePath "git" -ArgumentList "checkout $branch --force" -Wait -NoNewWindow 
        }

        # requirements安装
        $r_path = Join-Path -Path $dir -ChildPath "requirements.txt"
        if (Test-Path -Path $r_path) {
            Set-Location $base_dir
            pip_install $r_path
        }

        return $true
    } else {
        Write-Log "$name 克隆失败"
        # 删除$dir
        Remove-Item -Path $dir -Recurse -Force
        exit
    }
}

# git clone
function git_clone {
    param (
        [array]$git_list
    )

    # 遍历pre_installed
    foreach ($item in $git_list) {
        $name = $item.name
        $path = $item.path
        $urls = $item.urls
        $branch = $item.branch
        $dir = Join-Path -Path $base_dir -ChildPath $path
        $dir = Join-Path -Path $dir -ChildPath $name
        $force = ""

        if (Test-Path -Path $dir) {
            Write-Log "$name 已存在"
            # 尝试更新
            Write-Log "$name 更新中..."
            $cmd_clone = "-C $dir pull"
            try {
                Write-Log "cmd $cmd_clone"
                proxy_switch $true
                Start-Process -FilePath "git" -ArgumentList $cmd_clone -Wait -NoNewWindow
                proxy_switch $false
                Write-Log "Clone Post $dir $cmd_clone $branch"
                if (clone_finish $dir $cmd_clone $branch) {
                    continue
                } else {
                    throw "克隆结果无效"
                }
            } catch {
                Write-Log "$name 更新失败 将尝试强制克隆"
                $force = "--recurse-submodules"
            }
        }

        Write-Log "$name 克隆中..."
        # 如果url.origin-LAN存在
        if ($urls.origin_LAN) {
            Write-Log "使用本地服务器克隆..."
            $url = $urls.origin_LAN
            $cmd_clone = "clone $url $dir $force"
            Write-Log "cmd $cmd_clone"
            Start-Process -FilePath "git" -ArgumentList $cmd_clone -Wait -NoNewWindow
            Write-Log "Clone Post $dir $cmd_clone $branch"
            if (clone_finish $dir $cmd_clone $branch){
                continue
            }
        }
        if ($urls.origin) {
            # 使用服务器代理
            Write-Log "使用服务器缓存克隆..."
            $url = $urls.origin
            if ($proxy_git){
                # 如果是https的，替换为http
                if ($url -match "^https://") {
                    $url = $url -replace "https://", "http://"
                }
                $url = $urls.origin -replace "http://", "http://$proxy_git/"
                $cmd_clone = "clone $url $dir $force"
                if ($branch -ne "main" -and $branch -ne "master") {
                   $cmd_clone = "clone $url $dir $force -b $branch"
                }
                Write-Log "cmd $cmd_clone"
                Start-Process -FilePath "git" -ArgumentList $cmd_clone -Wait -NoNewWindow
                Write-Log "Clone Post $dir $cmd_clone $branch"
                if (clone_finish $dir $cmd_clone $branch){
                    continue
                }
            } else {
                # 直连
                Write-Log "直连克隆..."
                $cmd_clone = "clone $url $dir $force"
                Write-Log "cmd $cmd_clone"
                proxy_switch $true
                Start-Process -FilePath "git" -ArgumentList $cmd_clone -Wait -NoNewWindow
                proxy_switch $false
                Write-Log "Clone Post $dir $cmd_clone $branch"
                if (clone_finish $dir $cmd_clone $branch){
                    continue
                }
            }
        }
        else {
            Write-Log "$name 克隆失败"
            pause
            exit
        }
    }
}

$git_list_path = Join-Path -Path $comfyui_installer_path -ChildPath "git_list.json"
Write-Log "git_list_path: $git_list_path"
$git_list_content = Get-Content -Path $git_list_path | ConvertFrom-Json
$git_list = $git_list_content.git_list
git_clone $git_list

$requirements_path = Join-Path -Path $comfyui_installer_path -ChildPath "requirements.txt"
Set-Location $base_dir
pip_install $requirements_path

#复制run.bat
$run_bat = $config.run_bat
Write-Log "复制$run_bat 到 $base_dir"
Copy-Item -Path $run_bat -Destination $base_dir -Force
#复制uv.toml
Write-Log "复制$uv_config 到 $base_dir\ComfyUI"
Copy-Item -Path $uv_config -Destination "$base_dir\ComfyUI\uv.toml" -Force
#复制comfyui-manager的config.ini
$comfyui_manager_config = $config.comfyui_manager_config
Write-Log "复制$comfyui_manager_config 到 $base_dir\ComfyUI\user\default\ComfyUI-Manager"
if(-not (Test-Path -Path "$base_dir\ComfyUI\user\default\ComfyUI-Manager")) {
    New-Item -Path "$base_dir\ComfyUI\user\default\ComfyUI-Manager" -ItemType Directory -Force
}
Copy-Item -Path $comfyui_manager_config -Destination "$base_dir\ComfyUI\user\default\ComfyUI-Manager\config.ini" -Force
#复制预设workflows
$sample_workflows = $config.sample_workflows
if($sample_workflows){
    $source_path = Join-Path -Path $sample_workflows -ChildPath "*"
    $target_path = Join-Path -Path $base_dir -ChildPath "ComfyUI\user\default\workflows"
    Write-Log "复制$source_path 到 $target_path"
    if(-not (Test-Path -Path "$base_dir\ComfyUI\user\default")) {
        New-Item -Path "$base_dir\ComfyUI\user\default" -ItemType Directory -Force
    }
    Copy-Item -Path $source_path -Destination $target_path -Force -Recurse
}

#查找行"set PATH=%PATH%",替换为"set PATH=$python_embed_dir\Scripts;%PATH%"
$bat_file = Join-Path -Path $base_dir -ChildPath "run.bat"
$bat_content = Get-Content -Path $bat_file
$bat_content = $bat_content -replace "set `"PATH=%PATH%`"", "set `"PATH=$python_embed_dir;$python_embed_dir\Scripts;%PATH%`""
$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
$streamWriter = [System.IO.StreamWriter]::new($bat_file, $false, $utf8NoBOM)
try {
    $bat_content -split "`n" | ForEach-Object { $streamWriter.WriteLine($_) }
} finally {
    $streamWriter.Close()
}


Stop-Transcript
