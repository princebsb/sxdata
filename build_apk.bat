@echo off
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\Git\bin;%PATH%"
cd /d D:\flutter-app-carminati
echo Building APK...
D:\Downloads\flutter_windows_3.10.5-stable\flutter\bin\flutter.bat build apk --release
