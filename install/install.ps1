param (
    [string]$base_dir,
    [string]$bat_name,
    [string]$comfyui_installer_path
) 

# ��ȡ�ҵ��ĵ�Ŀ¼·��
$my_documents = [Environment]::GetFolderPath("MyDocuments")
$log_path = "$my_documents\comfyui_installer.log"

# ��������Write-Log�����������־
function Write-Log {
    param (
        [string]$message
    )
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $log_message = "$time $message"
    Write-Output $log_message
    Add-Content -Path $log_path -Value $log_message
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
$files = Get-ChildItem -Path $base_dir -Exclude $bat_name
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

$use_local_python = $config.use_local_python
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
    #��װpython embed
    $python_version = $config.python_version
    Write-Log "python_version: $python_version"
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
            #��װpip
            Write-Log "��װpip..."
            & $comfyui_installer_path\pip_install.ps1 -python_path $python_embed_dir -proxy $config.http_proxy
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
            if (Test-Path -Path $python_embed_dir\Scripts\pip3.exe) {
                Write-Log "pip��װ�ɹ�"
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
    Start-Process -FilePath $vc_redist_installer -ArgumentList "/install /quiet /norestart" -Wait
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
    Start-Process -FilePath $git_installer.FullName -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-" -Wait
    #����Ƿ�װ�ɹ�
    $git_path = Get-Command -Name "C:\Program Files\Git\cmd\git" -ErrorAction SilentlyContinue
    if ($git_path) {
        Write-Log "Git��װ�ɹ�,����������һ�νű�"
        exit
    } else {
        Write-Log "Git��װʧ��"
        pause
        exit
    }
}

$proxy_git = $config.proxy_git
Write-Log "proxy_git: $proxy_git"
# ��¡ComfyUI
$comfyUI_lan_url = $config.comfyUI_lan_url
Write-Log "comfyUI_lan_url: $comfyUI_lan_url"
$comfyUI_url = $config.comfyUI_url
Write-Log "comfyUI_url: $comfyUI_url"
#���Կ�¡ComfyUI
$comfyUI_dir = Join-Path -Path $base_dir -ChildPath "ComfyUI"
if (Test-Path -Path $comfyUI_dir) {
    Write-Log "ComfyUI�Ѵ���"
} else {
    Write-Log "ComfyUI��¡��..."
    Start-Process -FilePath "git" -ArgumentList "clone $comfyUI_lan_url $comfyUI_dir" -Wait
    if (Test-Path -Path $comfyUI_dir) {
        Write-Log "ComfyUI��¡�ɹ�"
    } else {
        Write-Log "ComfyUI��¡ʧ��"
        Write-Log "����ֱ�Ӵӻ�������¡..."
        Start-Process -FilePath "git" -ArgumentList "clone -c http.proxy=$proxy_git $comfyUI_url $comfyUI_dir" -Wait
        if (Test-Path -Path $comfyUI_dir) {
            Write-Log "ComfyUI��¡�ɹ�"
        } else {
            Write-Log "ComfyUI��¡ʧ��"
            pause
            exit
        }
    }
}

# ��¡ComfyUI-Manager
$comfyUI_manager_lan_url = $config.comfyUI_manager_lan_url
Write-Log "comfyUI_manager_lan_url: $comfyUI_manager_lan_url"
$comfyUI_manager_url = $config.comfyUI_manager_url
Write-Log "comfyUI_manager_url: $comfyUI_manager_url"
#���Կ�¡ComfyUI-Manager
$comfyUI_manager_dir = Join-Path -Path $comfyUI_dir -ChildPath "custom_nodes\ComfyUI-Manager"
if (Test-Path -Path $comfyUI_manager_dir) {
    Write-Log "ComfyUI-Manager�Ѵ���"
    # ���Ը���
    Set-Location -Path $comfyUI_manager_dir
    Write-Log "ComfyUI-Manager������..."
    Start-Process -FilePath "git" -ArgumentList "pull" -Wait
} else {
    Write-Log "ComfyUI-Manager��¡��..."
    Start-Process -FilePath "git" -ArgumentList "clone $comfyUI_manager_lan_url $comfyUI_manager_dir" -Wait
    if (Test-Path -Path $comfyUI_manager_dir) {
        Write-Log "ComfyUI-Manager��¡�ɹ�"
    } else {
        Write-Log "ComfyUI-Manager��¡ʧ��"
        Write-Log "����ֱ�Ӵӻ�������¡..."
        Start-Process -FilePath "git" -ArgumentList "clone -c http.proxy=$proxy_git $comfyUI_manager_url $comfyUI_manager_dir" -Wait
        if (Test-Path -Path $comfyUI_manager_dir) {
            Write-Log "ComfyUI-Manager��¡�ɹ�"
        } else {
            Write-Log "ComfyUI-Manager��¡ʧ��"
            pause
            exit
        }
    }
}
#�л���Branch_UID��ǿ�ƣ�
$branch_uid = $config.branch_uid
Write-Log "branch_uid: $branch_uid"
Set-Location -Path $comfyUI_manager_dir
Write-Log "�л���$branch_uid ��֧"
Start-Process -FilePath "git" -ArgumentList "checkout $branch_uid --force" -Wait

#����pipԴ
$pip_config = $config.pip_config
Write-Log "pip_ini: $pip_config"
#����pip.ini��%appdata%\pip\pip.ini
$pip_dir = Join-Path -Path $env:APPDATA -ChildPath "pip"
if (Test-Path -Path $pip_dir) {
    Write-Log "pipĿ¼�Ѵ���"
} else {
    Write-Log "pipĿ¼������..."
    New-Item -Path $pip_dir -ItemType Directory
    Write-Log "pipĿ¼�����ɹ�"
}
#��������ļ��Ƿ��Ѵ���
if (Test-Path -Path $pip_dir\$pip_config) {
    Write-Log "$pip_config �Ѵ���"
} else {
    Write-Log "����$comfyui_installer_path\$pip_config �� $pip_dir\$pip_config"
    Copy-Item -Path $comfyui_installer_path\$pip_config -Destination $pip_dir\$pip_config -Force
}

#��װpytorch
$pytorch_url = $config.pytorch_url
Write-Log "pytorch_url: $pytorch_url"
#��ʹ��python_embed��װpytorch
$torch_cmd = "install torch torchvision torchaudio --index-url $pytorch_url"
Write-Log "��װPyTorch..."
Write-Log "torch_cmd: $python_embed_dir\Scripts\pip3.exe $torch_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $torch_cmd" -Wait
#����pytorch
$torch_cmd = "install torch torchvision torchaudio --upgrade --index-url $pytorch_url"
Write-Log "����PyTorch..."
Write-Log "torch_cmd: $python_embed_dir\Scripts\pip3.exe $torch_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $torch_cmd" -Wait
#��װxformers
$torch_cmd = "install xformers --index-url $pytorch_url"
Write-Log "��װxformers..."
Write-Log "xformers_cmd: $python_embed_dir\Scripts\pip3.exe $xformers_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $xformers_cmd" -Wait
#����xformers
$torch_cmd = "install xformers --upgrade --index-url $pytorch_url"
Write-Log "����xformers..."
Write-Log "xformers_cmd: $python_embed_dir\Scripts\pip3.exe $xformers_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $xformers_cmd" -Wait

# ��װComfyUI����
Set-Location -Path $comfyUI_dir
$requirements_cmd = "install -r requirements.txt"
Write-Log "��װComfyUI����..."
Write-Log "requirements_cmd: $python_embed_dir\Scripts\pip3.exe $requirements_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $requirements_cmd" -Wait
#����ComfyUI����
$requirements_cmd = "install -r requirements.txt --upgrade"
Write-Log "����ComfyUI����..."
Write-Log "requirements_cmd: $python_embed_dir\Scripts\pip3.exe $requirements_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $requirements_cmd" -Wait

# ��װaria2p
$aria2p_cmd = "install aria2p"
Write-Log "��װaria2p..."
Write-Log "aria2p_cmd: $python_embed_dir\Scripts\pip3.exe $aria2p_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $aria2p_cmd" -Wait
#����aria2p
$aria2p_cmd = "install aria2p --upgrade"
Write-Log "����aria2p..."
Write-Log "aria2p_cmd: $python_embed_dir\Scripts\pip3.exe $aria2p_cmd"
Start-Process -FilePath "cmd" -ArgumentList "/c $python_embed_dir\Scripts\pip3.exe $aria2p_cmd" -Wait

#��comfyui_installer_path����run.bat�ļ���$base_dir
Write-Log "����$comfyui_installer_path\run.bat �� $base_dir"
Copy-Item -Path $comfyui_installer_path\run.bat -Destination $base_dir -Force
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
