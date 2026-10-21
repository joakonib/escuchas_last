@echo off
chcp 65001 > nul
rem Ciclo completo: descarga escuchas, tags y letras desde las APIs, genera los
rem dos reportes y los publica en GitHub Pages (carpeta docs).
rem Lo ejecuta la tarea "Last.fm escuchas" del Programador de tareas de Windows el
rem dia 1 de cada mes (o al prender el computador, si ese dia estaba apagado).
rem Cada paso que puede fallar se reintenta hasta 4 veces (red) o 2 (renders), con 1 minuto entre intentos
rem (ver FLUJO_DE_TRABAJO.txt). El log queda en data\actualizacion.log

cd /d C:\git_joako\escuchas_last
set LOG=data\actualizacion.log
set RSCRIPT="C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
set QUARTO="C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"
if not defined ESPERA set ESPERA=60

echo ==== %date% %time% ==== >> %LOG%

rem 1. Datos (los scripts son incrementales: reintentar retoma donde quedo).
rem Fallan por la red, asi que se reintentan hasta 4 veces.
set MAXI=4
call :reintentar "Escuchas" %RSCRIPT% scripts\descargar_escuchas.R
call :reintentar "Etiquetas" %RSCRIPT% scripts\descargar_tags.R
call :reintentar "Letras" %RSCRIPT% scripts\descargar_letras.R

rem 2. Reportes: un error de codigo no se arregla reintentando, por eso 2 intentos.
rem Si alguno falla, no se publica (para no subir HTML viejo como si fuera nuevo).
set MAXI=2
set FALLO=
call :reintentar "Reporte general" %QUARTO% render analisis_escuchas.qmd
if errorlevel 1 set FALLO=1
call :reintentar "Reporte mensual" %RSCRIPT% scripts\generar_reporte_mensual.R
if errorlevel 1 set FALLO=1
call :reintentar "Metodologia" %QUARTO% render metodologia.qmd
if errorlevel 1 set FALLO=1
if defined FALLO (
  echo [%time%] Un render fallo: NO se publica. Revisar el log. >> %LOG%
  echo Fin con errores: %date% %time% >> %LOG%
  exit /b 1
)

rem 3. Publicacion en GitHub Pages y subida de cambios
copy /Y analisis_escuchas.html docs\analisis_escuchas.html >> %LOG% 2>&1
copy /Y reporte_mensual.html docs\reporte_mensual.html >> %LOG% 2>&1
copy /Y metodologia.html docs\metodologia.html >> %LOG% 2>&1
git add docs >> %LOG% 2>&1
git commit -m "Actualizacion mensual de los reportes" >> %LOG% 2>&1
set MAXI=4
call :reintentar "Pull" git pull --rebase
call :reintentar "Push" git push
echo Fin: %date% %time% >> %LOG%
exit /b 0

rem Ejecuta un comando hasta MAXI veces y registra cada intento con la hora.
rem Uso: set MAXI=n y luego call :reintentar "Descripcion" comando argumentos...
:reintentar
set "DESC=%~1"
set "CMD="
:reintentar_armar
shift
if "%~1"=="" goto reintentar_correr
set CMD=%CMD% %1
goto reintentar_armar
:reintentar_correr
set /a INTENTO=1
:reintentar_intento
echo [%time%] %DESC%: intento %INTENTO% de %MAXI% >> %LOG%
%CMD% >> %LOG% 2>&1
if not errorlevel 1 (
  echo [%time%] %DESC%: OK >> %LOG%
  exit /b 0
)
echo [%time%] %DESC%: fallo >> %LOG%
if %INTENTO% GEQ %MAXI% (
  echo [%time%] %DESC%: FALLO %MAXI% veces >> %LOG%
  exit /b 1
)
set /a INTENTO+=1
rem Pausa con ping: funciona sin consola (timeout falla en la tarea programada)
set /a PINGS=%ESPERA%+1
"%SystemRoot%\System32\ping.exe" -n %PINGS% 127.0.0.1 > nul
goto reintentar_intento
