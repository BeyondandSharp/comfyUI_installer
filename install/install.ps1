param (
    [string]$base_dir,
    [string]$bat_name,
    [string]$comfyui_installer_path
) 

$log_path = "$base_dir\comfyui_installer.log"

Start-Transcript -Path $log_path -Append -IncludeInvocationHeader

# ��������Write-Log�����������־
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
# �����Ƿ���д��Ȩ��
$test_file = Join-Path -Path $base_dir -ChildPath "test.txt"
try {
    $null > $test_file
    Remove-Item -Path $test_file
    Write-Log "��д��Ȩ��"
} catch {
    Write-Log "û��д��Ȩ��"
    pause
    exit
}
# �����ļ������Ƿ���bat_name֮����ļ����ļ��У�ѯ���Ƿ�����,������bat����
$exclude_files = @($bat_name, "comfyui_installer.log")
$files = Get-ChildItem -Path $base_dir -Exclude $exclude_files
if ($files) {
    Write-Log "�ļ������������ļ����ļ��У�"
    $files | ForEach-Object { Write-Log $_.Name }
    $choice = Read-Host "�Ƿ����°�װ��(y���°�װ/n����)"
    if ($choice -eq "y") {
        #����ȷ��
        Write-Log "���е�ģ����ڵ㶼����ɾ�����޷��ָ���ȷ����"
        $choice = Read-Host "�Ƿ�����(yȫ��ɾ��/n������)"
        if ($choice -eq "y") {
            #����5s�ӳ�
            Write-Log "5s������...��ڵĻ���رմ���"
            Start-Sleep -Seconds 5
            Write-Log "������..."
            $files | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force}
        }
    }
}

# ��ȡ�����ļ�config.json
Write-Log "��ȡ�����ļ�"
# ����base_dir\config.json�Ƿ����
$config_path = Join-Path -Path $base_dir -ChildPath "config.json"
if (Test-Path -Path $config_path) {
    Write-Log "config_path: $config_path"
} else {
    $config_path = Join-Path -Path $comfyui_installer_path -ChildPath "config.json"
    if (Test-Path -Path $config_path) {
        Write-Log "config_path: $config_path"
    } else {
        Write-Log "δ�ҵ�config.json"
        pause
        exit
    }
}
# ��ȡconfig.json
$config = Get-Content -Path $config_path | ConvertFrom-Json

#���git�Ƿ��Ѱ�װ
$git_path = Get-Command -Name "git" -ErrorAction SilentlyContinue
if ($git_path) {
    Write-Log "Git�Ѱ�װ"
} else {
    #��װGit
    $git_installer_dir = $config.git_installer_dir
    Write-Log "git_installer_dir: $git_installer_dir"
    #����git_installer_dir�����µİ�װ��
    $git_installer = Get-ChildItem -Path $git_installer_dir -File |
        Where-Object { $_.Name -match "Git-.*-64-bit.exe" } |
        Sort-Object { [Version]($_.Name -replace "Git-", "" -replace "-.*", "") } -Descending |
        Select-Object -First 1
    Write-Log "git_installer: $git_installer"
    # ��Ĭ��װGit
    Write-Log "Git��װ��..."
    Start-Process -FilePath $git_installer.FullName -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-" -Wait -NoNewWindow
    #����Ƿ�װ�ɹ�
    Refresh-Env
    $git_path = Get-Command -Name "git" -ErrorAction SilentlyContinue
    if ($git_path) {
        Write-Log "Git��װ�ɹ�"
    } else {
        Write-Log "Git��װʧ��"
        pause
        exit
    }
}

#���C++���п��Ƿ��Ѱ�װ
$msvcDlls = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
)
$vc_installed = $true
foreach ($dll in $msvcDlls) {
    if (-not (Get-ChildItem -Path "C:\Windows\System32" -Filter $dll -ErrorAction SilentlyContinue)) {
        $vc_installed = $false
        Write-Output "$dll δ��װ"
    } else {
        Write-Output "$dll �Ѱ�װ"
    }
}
if ($vc_installed) {
    Write-Log "C++���п��Ѱ�װ"
} else {
    #��װC++���п�
    $vc_redist_installer = $config.vc_redist_installer -replace "/", "\"
    Write-Log "vc_redist_installer: $vc_redist_installer"
    Write-Log "C++���пⰲװ��..."
    Start-Process -FilePath $vc_redist_installer -ArgumentList "/install /quiet /norestart" -Wait -NoNewWindow
    #����Ƿ�װ�ɹ�
    Write-Log "���C++���п��Ƿ�װ�ɹ�"
    $vc_redist = $true
    foreach ($dll in $msvcDlls) {
        if (-not (Get-ChildItem -Path "C:\Windows\System32" -Filter $dll -ErrorAction SilentlyContinue)) {
            $vc_redist = $false
            Write-Output "$dll δ��װ"
        } else {
            Write-Output "$dll �Ѱ�װ"
        }
    }
    if ($vc_redist) {
        Write-Log "C++���пⰲװ�ɹ�"
    } else {
        Write-Log "C++���пⰲװʧ��"
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

# ��װuv
$uv_path = Get-Command -Name "uv" -ErrorAction SilentlyContinue
if ($uv_path) {
    Write-Log "uv�Ѱ�װ"
} else {
    Write-Log "uvδ��װ����װ��..."
    #��װuv
    proxy_switch $true
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    proxy_switch $false
    #����Ƿ�װ�ɹ�
    Refresh-Env
    $uv_path = Get-Command -Name "uv" -ErrorAction SilentlyContinue
    if ($uv_path) {
        Write-Log "uv��װ�ɹ�"
    } else {
        Write-Log "uv��װʧ��"
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
    # �����Ƿ����python
    Write-Log "�����Ƿ����python"
    $hasPython_path = Get-Command -Name "python" -ErrorAction SilentlyContinue
    if ($hasPython_path) {
        & python --version
    } else {
        Write-Log "δ�ҵ�python����ȷ�ϻ����������޸������ļ�"
    }
} else {
    if ($uv_path) {
        Write-Log "uv�Ѱ�װ����������װpython"
    } else {
        Write-Log "uvδ��װ��ʹ�ó��氲װ"
        #��װpython embed
        $python_installer_dir = $config.python_installer_dir
        Write-Log "python_installer_dir: $python_installer_dir"
        #��ȡ��������°汾
        $python_embed_version_net = Get-ChildItem -Path $python_installer_dir -Directory |
            Where-Object { $_.Name -match "python-$python_version\.(\d+)-embed-amd64" } |
            Sort-Object { [int]($_.Name -replace "python-$python_version\.", "" -replace "-.*", "") } -Descending |
            Select-Object -First 1 |
            Select-Object -ExpandProperty Name
        $python_embed_version_net = $python_embed_version_net -replace "python-", "" -replace "-.*", ""
        Write-Log "python_embed_version_net: $python_embed_version_net"
        #���$base_dir\python_embed\python.exe�Ƿ����
        $python_embed_dir = Join-Path -Path $base_dir -ChildPath "python_embed"
        Write-Log "python_embed_dir: $python_embed_dir"
        $python_embed_exe = Join-Path -Path $python_embed_dir -ChildPath "python.exe"
        if (Test-Path -Path $python_embed_exe) {
            Write-Log "Python�Ѱ�װ"
            #���python�汾
            $python_version_current = & $python_embed_exe --version 2>&1
            $python_version_current = $python_version_current -replace "Python ", ""
        }
        Write-Log "python_version_current: $python_version_current"
        #���python�汾��ƥ�����python_embed_dir�����ڣ���װ
        if ($python_version_current -ne $python_embed_version_net -or -not (Test-Path -Path $python_embed_dir)) {
            Write-Log "Pythonδ��װ��汾��ƥ��"
            if (Test-Path -Path $python_embed_dir) {
                Write-Log "ɾ����$python_embed_dir"
                Remove-Item -Path $python_embed_dir -Recurse -Force
            }
            $python_embed_dir_net = Join-Path -Path $python_installer_dir -ChildPath "python-$python_embed_version_net-embed-amd64"
            Write-Log "����$python_embed_dir_net �� $python_embed_dir"
            Copy-Item -Path $python_embed_dir_net -Destination $python_embed_dir -Recurse -Force
            # ��鰲װ�Ƿ�ɹ�
            if (Test-Path -Path $python_embed_exe) {
                Write-Log "Python��װ�ɹ�"
                $python = Join-Path -Path $python_embed_dir -ChildPath "python"
                #��װpip
                Write-Log "��װpip..."
                $pip_installer_path = Join-Path -Path $python_installer_dir -ChildPath "pip_installer\pip_install.ps1"
                & $pip_installer_path -python_path $python_embed_dir -proxy $http_proxy
                # �޸�_pth
                # ����*._pth
                $pth = Get-ChildItem -Path $python_embed_dir -Filter "*._pth" -Recurse
                if ($pth) {
                    $pth | ForEach-Object {
                        Write-Log "Found $($_.FullName)"
                        $content = Get-Content -Path $_.FullName
                        $newContent = @()
                        #�ڵ�һ�����../ComfyUI
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
                # ���pip�Ƿ�װ�ɹ�
                if (Test-Path -Path $python_embed_dir\Scripts\pip.exe) {
                    Write-Log "pip��װ�ɹ�"
                    $pip = Join-Path -Path $python_embed_dir -ChildPath "Scripts\pip"

                    #����pipԴ
                    $pip_config = $config.pip_config
                    Write-Log "pip_ini: $pip_config"

                    #����pip.ini��python_embed_dir\pip.ini
                    Copy-Item -Path $pip_config -Destination "$python_embed_dir\pip.ini" -Force
                } else {
                    Write-Log "pip��װʧ��"
                    pause
                    exit
                }
            } else {
                Write-Log "Python��װʧ��"
                pause
                exit
            }
        } else {
            Write-Log "Python��������İ汾"
        }
    }
}

# �������⻷��
if ($uv_path) {
    Write-Log "uv�Ѱ�װ��ʹ��uv�������⻷��"
    $uv_config = $config.uv_config

    Write-Log "����uv..."
    Start-Process -FilePath "uv" -ArgumentList "self update" -Wait -NoNewWindow

    $venv_cmd = "venv --config-file $uv_config --directory $base_dir --python $python_version --relocatable"
    try {
        Write-Log "�������⻷����..."
        Start-Process -FilePath "uv" -ArgumentList $venv_cmd -Wait -NoNewWindow
    } catch {
        Write-Log "�������⻷��ʧ��"
        pause
        exit
    }
    # ����$comfyui_installer_path\pip�ļ��е�.venv\Lib\site-packages
    #Write-Log "����$comfyui_installer_path\pip �� $base_dir\.venv\Lib\site-packages"
    #$pip_dir = Join-Path -Path $base_dir -ChildPath ".venv\Lib\site-packages\pip"
    #Copy-Item -Path "$comfyui_installer_path\pip" -Destination $pip_dir -Recurse -Force

    Set-Location $base_dir
    # �������⻷��
    Write-Log "�������⻷����..."
    $venv_activate_cmd = "$base_dir\.venv\Scripts\activate"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $venv_activate_cmd" -Wait -NoNewWindow
    # ���venv�ܾ�����
    if ($?) {
        Write-Log "�������⻷���ɹ�"
    } else {
        Write-Log "�������⻷��ʧ��"
        pause
        exit
    }
    # ��װpip
    Write-Log "��װpip..."
    $pip_install_cmd = "pip install pip --config-file $uv_config"
    try {
        Start-Process -FilePath "uv" -ArgumentList $pip_install_cmd -Wait -NoNewWindow
    }
    catch {
        Write-Log "��װpipʧ��"
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
        Write-Log "��װ $r_path"
        Start-Process -FilePath "uv" -ArgumentList $requirements_cmd -Wait -NoNewWindow
        $requirements_cmd = "pip install -r $r_path --upgrade --config-file $uv_config"
        Write-Log "���� $r_path"
        Start-Process -FilePath "uv" -ArgumentList $requirements_cmd -Wait -NoNewWindow
    } else {
        & $pip config list -v
        $requirements_cmd = "install -r $r_path"
        Write-Log "��װ $r_path"
        Start-Process -FilePath $pip -ArgumentList $requirements_cmd -Wait -NoNewWindow
        $requirements_cmd = "install -r $r_path --upgrade"
        Write-Log "���� $r_path"
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
    # ����.git����������ļ�
    $childs = Get-ChildItem -Path $dir -Force -Exclude ".git"
    if ($childs.Count -gt 0) {
        Write-Log "��¡�ɹ� $cmd_clone"
        
        #�л�Branch��ǿ�ƣ�
        if ($branch -ne "main" -and $branch -ne "master") {
            Write-Log "�л��� $branch ��֧"
            Set-Location $dir
            Start-Process -FilePath "git" -ArgumentList "checkout $branch --force" -Wait -NoNewWindow 
        }

        # requirements��װ
        $r_path = Join-Path -Path $dir -ChildPath "requirements.txt"
        if (Test-Path -Path $r_path) {
            Set-Location $base_dir
            pip_install $r_path
        }

        return $true
    } else {
        Write-Log "$name ��¡ʧ��"
        # ɾ��$dir
        Remove-Item -Path $dir -Recurse -Force
        exit
    }
}

# git clone
function git_clone {
    param (
        [array]$git_list
    )

    # ����pre_installed
    foreach ($item in $git_list) {
        $name = $item.name
        $path = $item.path
        $urls = $item.urls
        $branch = $item.branch
        $dir = Join-Path -Path $base_dir -ChildPath $path
        $dir = Join-Path -Path $dir -ChildPath $name
        $force = ""

        if (Test-Path -Path $dir) {
            Write-Log "$name �Ѵ���"
            # ���Ը���
            Write-Log "$name ������..."
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
                    throw "��¡�����Ч"
                }
            } catch {
                Write-Log "$name ����ʧ�� ������ǿ�ƿ�¡"
                $force = "--recurse-submodules"
            }
        }

        Write-Log "$name ��¡��..."
        # ���url.origin-LAN����
        if ($urls.origin_LAN) {
            Write-Log "ʹ�ñ��ط�������¡..."
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
            # ʹ�÷���������
            Write-Log "ʹ�÷����������¡..."
            $url = $urls.origin
            if ($proxy_git){
                # �����https�ģ��滻Ϊhttp
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
                # ֱ��
                Write-Log "ֱ����¡..."
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
            Write-Log "$name ��¡ʧ��"
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

#����run.bat
$run_bat = $config.run_bat
Write-Log "����$run_bat �� $base_dir"
Copy-Item -Path $run_bat -Destination $base_dir -Force
#����uv.toml
Write-Log "����$uv_config �� $base_dir\ComfyUI"
Copy-Item -Path $uv_config -Destination "$base_dir\ComfyUI\uv.toml" -Force
#����comfyui-manager��config.ini
$comfyui_manager_config = $config.comfyui_manager_config
Write-Log "����$comfyui_manager_config �� $base_dir\ComfyUI\user\default\ComfyUI-Manager"
if(-not (Test-Path -Path "$base_dir\ComfyUI\user\default\ComfyUI-Manager")) {
    New-Item -Path "$base_dir\ComfyUI\user\default\ComfyUI-Manager" -ItemType Directory -Force
}
Copy-Item -Path $comfyui_manager_config -Destination "$base_dir\ComfyUI\user\default\ComfyUI-Manager\config.ini" -Force
#����Ԥ��workflows
$sample_workflows = $config.sample_workflows
if($sample_workflows){
    $source_path = Join-Path -Path $sample_workflows -ChildPath "*"
    $target_path = Join-Path -Path $base_dir -ChildPath "ComfyUI\user\default\workflows"
    Write-Log "����$source_path �� $target_path"
    if(-not (Test-Path -Path "$base_dir\ComfyUI\user\default")) {
        New-Item -Path "$base_dir\ComfyUI\user\default" -ItemType Directory -Force
    }
    Copy-Item -Path $source_path -Destination $target_path -Force -Recurse
}

#������"set PATH=%PATH%",�滻Ϊ"set PATH=$python_embed_dir\Scripts;%PATH%"
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
