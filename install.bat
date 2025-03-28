@echo version 17
@echo off

::set HTTP_PROXY=http://192.168.0.100:7897
::set HTTPS_PROXY=http://192.168.0.100:7897
::set NO_PROXY=localhost,127.0.0.0/8,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12

set "comfyui_installer_path=\\192.168.0.100\mcs\Working_Group\Installation_package\ComfyUI"
::获取当前bat的文件名
set bat_name=%~n0
::获取comfyui_installer_path\run.bat第一行的版本号
for /f "tokens=3 delims= " %%i in ('type "%comfyui_installer_path%\%bat_name%.bat"') do set "version_net=%%i"&goto next
:next
echo version_net: %version_net%
::获取当前bat的版本号
for /f "tokens=3 delims= " %%i in ('type "%~dpnx0"') do set "version_local=%%i"&goto next2
:next2
echo version_local: %version_local%
::如果version_net大于version_local，那么就更新
setlocal enabledelayedexpansion
set /a version_net_num=%version_net%
set /a version_local_num=%version_local%
if !version_net_num! gtr !version_local_num! (
    echo 更新中...
    copy /y "%comfyui_installer_path%\%bat_name%.bat" "%~dpnx0"
    echo 更新完成
    call "%~dpnx0"
    exit
)
endlocal

echo 这个脚本会执行包括但不限于以下的操作
echo ===================================================
echo 安装程序
echo 朝你的C盘里面塞各种配置
echo 以及因为这个文本是在脚本编写之中写的
echo 所以可能还有其他情况
echo ===================================================
echo 使用前请确保你能访问192.168.0.100
echo 并按照窗口提示操作（最多让你重新开一下或者按按回车之类的）
echo 如果问你要账号密码，请使用访问192.168.0.100的账号密码
echo 请确保你已经阅读了这个文本
echo ===================================================
echo 如果你同意这个文本中的所有内容
echo 请按任意键继续
echo 如果你不同意，那我只能求求你同意吧
echo 否则请关闭窗口
echo ===================================================
pause

c:
cd %TEMP%
::获取当前bat所在目录
set base_dir=%~dp0
::判断是否是网络路径，是的话退出
if "%base_dir:~0,2%"=="\\" (
    echo 请将脚本放到本地磁盘的一个空目录中运行
    pause
    exit
)
set "PATH=%base_dir%python_embed\Scripts;%PATH%"
echo %comfyui_installer_path%\install.ps1 %base_dir% %bat_name%.bat %comfyui_installer_path%\install
powershell -ExecutionPolicy Bypass -File "%comfyui_installer_path%\install\install.ps1" --base_dir %base_dir% --bat_name %bat_name%.bat --comfyui_installer_path %comfyui_installer_path%\install
pause
