@echo off
echo Instalando dependencias...
call D:\downloads11-11-2025\flutter_windows_3.38.3-stable\flutter\bin\flutter pub get
echo.
echo Limpando build anterior...
call D:\downloads11-11-2025\flutter_windows_3.38.3-stable\flutter\bin\flutter clean
echo.
echo Gerando APK de producao...
call D:\downloads11-11-2025\flutter_windows_3.38.3-stable\flutter\bin\flutter build apk --release
echo.
echo Build concluido!
echo APK gerado em: build\app\outputs\flutter-apk\app-release.apk
pause
