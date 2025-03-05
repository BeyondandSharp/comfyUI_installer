@echo off
set HTTP_PROXY=http://192.168.0.100:7897
set HTTPS_PROXY=http://192.168.0.100:7897
set NO_PROXY=localhost,127.0.0.0/8,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12
set COMFYUI_MANAGER_ARIA2_SERVER=http://192.168.0.100:6800
set COMFYUI_MANAGER_ARIA2_SECRET=
set COMFYUI_MANAGER_DIR_REMOTE=E:\MCS\ComfyUI
set COMFYUI_MANAGER_DIR_NET=\\192.168.0.100\mcs\ComfyUI
set GITCACHE_HTTP_PROXY=192.168.0.100:5000
set TOKEN_PATH=\\192.168.0.100\mcs\ComfyUI\token.json
set "PATH=%PATH%"
set CUSTOMNODEDB=\\192.168.0.100\mcs\ComfyUI\custom-list

set "script_path=%~dp0"

::Cleaning up extra lines in the <custom_nodes\.git\config> for some reason causes comfyui manager to load incorrectly
python_embed\python.exe "\\192.168.0.100\mcs\Working_Group\Installation_package\ComfyUI\install\git_clean.py" %script_path%ComfyUI\custom_nodes
python_embed\python.exe ComfyUI\main.py --listen 0.0.0.0 --port 8188 --auto-launch
pause 