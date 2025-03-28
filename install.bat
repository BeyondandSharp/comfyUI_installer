@echo version 17
@echo off

::set HTTP_PROXY=http://192.168.0.100:7897
::set HTTPS_PROXY=http://192.168.0.100:7897
::set NO_PROXY=localhost,127.0.0.0/8,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12

set "comfyui_installer_path=\\192.168.0.100\mcs\Working_Group\Installation_package\ComfyUI"
::��ȡ��ǰbat���ļ���
set bat_name=%~n0
::��ȡcomfyui_installer_path\run.bat��һ�еİ汾��
for /f "tokens=3 delims= " %%i in ('type "%comfyui_installer_path%\%bat_name%.bat"') do set "version_net=%%i"&goto next
:next
echo version_net: %version_net%
::��ȡ��ǰbat�İ汾��
for /f "tokens=3 delims= " %%i in ('type "%~dpnx0"') do set "version_local=%%i"&goto next2
:next2
echo version_local: %version_local%
::���version_net����version_local����ô�͸���
setlocal enabledelayedexpansion
set /a version_net_num=%version_net%
set /a version_local_num=%version_local%
if !version_net_num! gtr !version_local_num! (
    echo ������...
    copy /y "%comfyui_installer_path%\%bat_name%.bat" "%~dpnx0"
    echo �������
    call "%~dpnx0"
    exit
)
endlocal

echo ����ű���ִ�а��������������µĲ���
echo ===================================================
echo ��װ����
echo �����C����������������
echo �Լ���Ϊ����ı����ڽű���д֮��д��
echo ���Կ��ܻ����������
echo ===================================================
echo ʹ��ǰ��ȷ�����ܷ���192.168.0.100
echo �����մ�����ʾ����������������¿�һ�»��߰����س�֮��ģ�
echo �������Ҫ�˺����룬��ʹ�÷���192.168.0.100���˺�����
echo ��ȷ�����Ѿ��Ķ�������ı�
echo ===================================================
echo �����ͬ������ı��е���������
echo �밴���������
echo ����㲻ͬ�⣬����ֻ��������ͬ���
echo ������رմ���
echo ===================================================
pause

c:
cd %TEMP%
::��ȡ��ǰbat����Ŀ¼
set base_dir=%~dp0
::�ж��Ƿ�������·�����ǵĻ��˳�
if "%base_dir:~0,2%"=="\\" (
    echo �뽫�ű��ŵ����ش��̵�һ����Ŀ¼������
    pause
    exit
)
set "PATH=%base_dir%python_embed\Scripts;%PATH%"
echo %comfyui_installer_path%\install.ps1 %base_dir% %bat_name%.bat %comfyui_installer_path%\install
powershell -ExecutionPolicy Bypass -File "%comfyui_installer_path%\install\install.ps1" --base_dir %base_dir% --bat_name %bat_name%.bat --comfyui_installer_path %comfyui_installer_path%\install
pause
