@echo off

setlocal enableextensions
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo. >~.txt
echo Set Http = CreateObject("WinHttp.WinHttpRequest.5.1") >>~.txt
echo Set Stream = CreateObject("Adodb.Stream") >>~.txt
echo Http.SetTimeouts 30*1000, 30*1000, 30*1000, 120*1000  >>~.txt
netstat -an| findstr LISTENING | findstr ":8087" >NUL && (
    echo Http.SetProxy 2, "127.0.0.1:8087", "" >>~.txt
    echo Http.Option^(4^) = 256 >>~.txt
)
echo Http.Open "GET", WScript.Arguments.Item(0), False >>~.txt
echo Http.Send >>~.txt
echo Http.WaitForResponse 5 >>~.txt
echo If Not Http.Status = 200 then >>~.txt
echo     WScript.Quit 1 >>~.txt
echo End If >>~.txt
echo Stream.Type = 1 >>~.txt
echo Stream.Open >>~.txt
echo Stream.Write Http.ResponseBody >>~.txt
echo Stream.SaveToFile WScript.Arguments.Item(1), 2 >>~.txt
move /y ~.txt ~gdownload.vbs >NUL


set has_user_json=0
if exist "httpproxy.json" (
    for %%I in (*.user.json) do (
        set has_user_json=1
    )
    if "!has_user_json!" == "0" (
        echo Please backup your config as .user.json
        goto quit
    )
)

forfiles /? 1>NUL 2>NUL && (
    forfiles /P cache /M *.crt /D -90 /C "cmd /c del /f @path" 2>NUL
)

for %%I in (*.user.json) do (
    set USER_JSON_FILE=%%I
    set /p USER_JSON_LINE= <!USER_JSON_FILE!
    echo "!USER_JSON_LINE!" | findstr "AUTO_UPDATE_URL" 1>NUL && (
        set USER_JSON_URL=!USER_JSON_LINE:* =!
        echo Update !USER_JSON_FILE! with !USER_JSON_URL!
        cscript /nologo ~gdownload.vbs "!USER_JSON_URL!" "!USER_JSON_FILE!"
    )
)

reg query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" && (
    set filename_prefix=goproxy_windows_386
) || (
    set filename_prefix=goproxy_windows_amd64
)

if exist "goproxy.exe" (
    for /f "usebackq" %%I in (`goproxy.exe -version`) do (
        echo %%I | findstr /r "r[0-9][0-9][0-9][0-9][0-9]*" >NUL && (
            set localversion=%%I
        )
    )
)
if not "%localversion%" == "" (
    echo 0. Local GoProxy version %localversion%
)

set remoteversion=
(
    title 1. Checking GoProxy Version
    echo 1. Checking GoProxy Version
    cscript /nologo ~gdownload.vbs https://github.com/phuslu/goproxy-ci/commits/master ~goproxy_tag.txt
) && (
    for /f "usebackq tokens=2 delims=-." %%I in (`findstr "%filename_prefix%-r" ~goproxy_tag.txt`) do (
        set remoteversion=%%I
    )
) || (
    echo Cannot detect !filename_prefix! version
    goto quit
)
del /f ~goproxy_tag.txt
if "!remoteversion!" == "" (
    echo Cannot detect !filename_prefix! version
    goto quit
)

if "!localversion!" neq "r9999" (
    if "!localversion!" geq "!remoteversion!" (
        echo.
        echo Your Goproxy already update to latest.
        goto quit
    )
)

set filename=!filename_prefix!-!remoteversion!.7z

(
    title 2. Downloading %filename%
    echo 2. Downloading %filename%
    cscript /nologo ~gdownload.vbs https://github.com/phuslu/goproxy-ci/releases/download/!remoteversion!/%filename% "~%filename%"
    if not exist "~%filename%" (
        echo Cannot download %filename%
        goto quit
    )
) && (
    title 3. Extract GoProxy files
    echo 3. Extract GoProxy files
    move /y ~%filename% ~%filename%.exe
    del /f ~gdownload.vbs 2>NUL
    for %%I in ("goproxy.exe" "goproxy-gui.exe") do (
        if exist "%%~I" (
            move /y "%%~I" "~%%~nI.%localversion%.%%~xI.tmp"
        )
    )
    ~%filename%.exe -y || echo "Failed to update GoProxy, please retry."
)

:quit
    del /f ~* 1>NUL 2>NUL
    pause
