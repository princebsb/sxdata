@echo off
chcp 65001 > nul
echo ====================================
echo   VISUALIZADOR DE LOGS - SXData
echo ====================================
echo.
echo Conectando ao dispositivo Android...
echo Pressione Ctrl+C para parar
echo.
echo ====================================
echo.

adb logcat -c
adb logcat *:I | findstr /C:"MODO" /C:"VERIFIC" /C:"Comparando" /C:"MATCH" /C:"DUPLICA" /C:"Formulario" /C:"editingFormId" /C:"currentForm" /C:"formToSave" /C:"ESTADO" /C:"EDIÇÃO" /C:"SUBMISSÃO" /C:"CRÍTICO" /C:"ERRO"
