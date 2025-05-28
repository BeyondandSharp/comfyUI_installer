param (
    [string]$base_dir
)

# ���û��ָ��·����ʹ�õ�ǰ����Ŀ¼
if ([string]::IsNullOrEmpty($base_dir)) {
    $base_dir = Get-Location
    Write-Host "δָ������Ŀ¼��ʹ�õ�ǰĿ¼: $base_dir"
}
else {
    # ���ָ����·���Ƿ����
    if (Test-Path -Path $base_dir -PathType Container) {
        Write-Host "ʹ��ָ���Ĺ���Ŀ¼: $base_dir"
    }
    else {
        Write-Error "ָ����·�� '$base_dir' �����ڻ���һ��Ŀ¼"
        exit 1
    }
}

# ��ȡ��ǰ�ű�������
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
$configFullName = "$scriptName.json"
$configBasePath = Join-Path -Path $base_dir -ChildPath $configFullName
Write-Host "configBasePath: $configBasePath" -ForegroundColor Green

# ��ȡ��ǰ�ű���·��
$script_path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$configScriptPath = Join-Path -Path $script_path -ChildPath $configFullName
Write-Host "configScriptPath: $configScriptPath" -ForegroundColor Green

if (Test-Path -Path $configBasePath) {
    $configPath = $configBasePath
} elseif (Test-Path -Path $configScriptPath) {
    $configPath = $configScriptPath
} else {
    Write-Host "δ�ҵ������ļ�" -ForegroundColor Red
    exit 1
}
Write-Host "�����ļ�: $configPath" -ForegroundColor Green

$python = "python"
# ��ѯbase_dir����û��.venv��ember�ļ��У�����˳��ʹ�����е�python
if (Test-Path -Path "$base_dir\.venv" -PathType Container) {
    # ���Խ������⻷��
    Write-Host "���Լ������⻷��"
    try{
        & .venv\Scripts\Activate
    } catch {
        Write-Error "�޷��������⻷������������"
    }
    
} else {
    Write-Host "����Ƕ��ʽpython"
    $emberFolders = Get-ChildItem -Path $base_dir -Directory -Recurse | Where-Object { $_.Name -like "*ember*" }
    Write-Host "�ҵ����°���'ember'���ļ��У�"
    foreach ($folder in $emberFolders) {
        Write-Host "- $($folder.FullName)"
        
        # ���ļ����в���python.exe
        $pythonFiles = Get-ChildItem -Path $folder.FullName -Include "python.exe", "python" -File -Recurse -ErrorAction SilentlyContinue
        
        # ����ҵ�Python
        if ($pythonFiles.Count -gt 0) {
            $python = $pythonFiles[0].FullName
            Write-Host "  �ڴ��ļ������ҵ�Python: $python" -ForegroundColor Green
            break # �ҵ���һ����ֹͣ����
        }
    }

    if ($python -eq "python") {
        Write-Host "ʹ��ȫ��python" -ForegroundColor Red
    }
}

# ����python�Ƿ����
try {
    $python_version = & $python -V 2>&1
    $python_version = $python_version -replace "Python ", ""
    Write-Host "Python�汾: $python_version" -ForegroundColor Green
} catch {
    Write-Error "�޷��ҵ�Python��ִ���ļ�������·����װPython"
    exit 1
}

# ��ѯtorch�汾
try {
    $torch_version = & $python -c "import torch; print(torch.__version__)" 2>&1
    Write-Host "Torch�汾: $torch_version" -ForegroundColor Green
} catch {
    Write-Error "�޷��ҵ�Torchģ�飬���鰲װ"
    exit 1
}

# �жϵ�ǰϵͳ��windows����linux
$os = $env:OS
if ($os -eq "Windows_NT") {
    Write-Host "��ǰ����ϵͳ: Windows" -ForegroundColor Green
    $os = "win"
} else {
    Write-Host "��ǰ����ϵͳ: Linux" -ForegroundColor Green
    $os = "linux"
}

# �ж��Ƿ���64λ
if ([Environment]::Is64BitOperatingSystem) {
    Write-Host "��ǰ����ϵͳ: 64λ" -ForegroundColor Green
    $arch = "x86_64"
} else {
    Write-Host "��ǰ����ϵͳ: 32λ" -ForegroundColor Green
    $arch = "x86"
}

# ��ȡ�����ļ�
$config = Get-Content -Path $configPath | ConvertFrom-Json
$Nunchaku_whl_dir = $config.Nunchaku_whl_dir

# ��ȡ�汾
$Nunchaku_version = $config.version

if ($Nunchaku_version -eq "latest" -or $Nunchaku_version -eq "dev") {
    # ��Nunchaku_whl_dir�������ļ��е����ƴ�������
    $Nunchaku_whl_dirs = Get-ChildItem -Path $Nunchaku_whl_dir -Directory | Select-Object -ExpandProperty Name
    # ɾ������Ϊprerelease��Ԫ��
    $Nunchaku_whl_dirs = $Nunchaku_whl_dirs_latest | Where-Object { $_ -ne "prerelease" }

    # ת��Ϊ�ֵ䣬��Ϊ�ļ������ƣ�ֵΪrelease������
    $Nunchaku_whl_release_type = @{}
    foreach ($dir in $Nunchaku_whl_dirs) {
        $Nunchaku_whl_release_type[$dir] = ""
    }
    
    if ($Nunchaku_version -eq "dev"){
        $Nunchaku_whl_dir_dev = Join-Path -Path $Nunchaku_whl_dir -ChildPath "prerelease"
        # ��Nunchaku_whl_dir/prerelease�������ļ��е����ƴ�������
        $Nunchaku_whl_dirs_dev = Get-ChildItem -Path $Nunchaku_whl_dir_dev -Directory | Select-Object -ExpandProperty Name

        foreach ($dir in $Nunchaku_whl_dirs_dev) {
            $Nunchaku_whl_release_type[$dir] = "prerelease"
        }

        # ��Nunchaku_whl_dirs_dev�е�Ԫ����ӵ�Nunchaku_whl_dirs��
        $Nunchaku_whl_dirs += $Nunchaku_whl_dirs_dev
    }

    # �������Ƶ�������
    $Nunchaku_whl_dirs = $Nunchaku_whl_dirs | Sort-Object -Descending
    Write-Host "Nunchaku whl directories: $Nunchaku_whl_dirs" -ForegroundColor Green
} else {
    $Nunchaku_gitid = $Nunchaku_version
    # ��Nunchaku_whl_dir�в�������ΪNunchaku_gitid���ļ��У��������ļ���
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

# �����ļ���
$Nunchaku_whl_pattern = "nunchaku-*+torch{5}.{6}-cp{3}{4}-cp{3}{4}-{1}_{2}.whl" -f $Nunchaku_version, $os, $arch, $python_major, $python_minor, $torch_major, $torch_minor
Write-Host "Nunchaku whl pattern: $Nunchaku_whl_pattern" -ForegroundColor Green

$Nunchaku_whl_path = $null

if ($Nunchaku_version -eq "latest" -or $Nunchaku_version -eq "dev") {
    # ��������Nunchaku_whl_dirs
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
    # ��$Nunchaku_whl_dir�в��ҷ���Nunchaku_whl_pattern���ļ�
    $Nunchaku_whl_obj = Get-ChildItem -Path $Nunchaku_whl_dir -Filter $Nunchaku_whl_pattern -File | Select-Object -First 1
    $Nunchaku_whl_path = $Nunchaku_whl_obj.FullName
}

Write-Host "Nunchaku whl path: $Nunchaku_whl_path" -ForegroundColor Green
if ($null -eq $Nunchaku_whl_path) {
    Write-Error "δ�ҵ�����ģʽ��whl�ļ������������ļ���Ŀ¼"
    exit 1
}

# ��ѯ�Ƿ���uv
try {
    & $python -m uv --version 2>&1
    $install_cmd = "-m uv pip install --no-cache-dir $Nunchaku_whl_path"
} catch {
    Write-Error "�޷��ҵ�uvģ�飬��ѯpip"
    try {
        & $python -m pip --version 2>&1
        $install_cmd = "-m pip install --no-cache-dir $Nunchaku_whl_path"
    } catch {
        Write-Error "�޷��ҵ�pipģ�飬���鰲װ"
        exit 1
    }
}

# ��װNunchaku whl�ļ�
try {
    Write-Host "��װNunchaku whl�ļ�: $Nunchaku_whl_path" -ForegroundColor Green
    Write-Host "install_cmd:$install_cmd"
    Start-Process -FilePath $python -ArgumentList $install_cmd -Wait -NoNewWindow
} catch {
    Write-Error "��װʧ�ܣ����������Ϣ"
    exit 1
}
