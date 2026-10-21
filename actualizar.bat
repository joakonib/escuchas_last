@echo off
chcp 65001 > nul
rem Ciclo completo: descarga escuchas, tags y letras desde las APIs, genera los
rem dos reportes y los publica en GitHub Pages (carpeta docs).
rem Lo ejecuta la tarea "Last.fm escuchas" del Programador de tareas de Windows el
rem día 1 de cada mes (o al prender el computador, si ese día estaba apagado).
rem El log queda en data\actualizacion.log

cd /d C:\git_joako\escuchas_last
set LOG=data\actualizacion.log
set RSCRIPT="C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
set QUARTO="C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"

echo ==== %date% %time% ==== >> %LOG%

rem 1. Datos
%RSCRIPT% scripts\descargar_escuchas.R >> %LOG% 2>&1
%RSCRIPT% scripts\descargar_tags.R >> %LOG% 2>&1
%RSCRIPT% scripts\descargar_letras.R >> %LOG% 2>&1

rem 2. Reportes
%QUARTO% render analisis_escuchas.qmd >> %LOG% 2>&1
%RSCRIPT% scripts\generar_reporte_mensual.R >> %LOG% 2>&1
%QUARTO% render metodologia.qmd >> %LOG% 2>&1

rem 3. Publicación en GitHub Pages y subida de cambios
copy /Y analisis_escuchas.html docs\analisis_escuchas.html >> %LOG% 2>&1
copy /Y reporte_mensual.html docs\reporte_mensual.html >> %LOG% 2>&1
copy /Y metodologia.html docs\metodologia.html >> %LOG% 2>&1
git add docs >> %LOG% 2>&1
git commit -m "Actualización mensual de los reportes" >> %LOG% 2>&1
git pull --rebase >> %LOG% 2>&1
git push >> %LOG% 2>&1
echo Fin: %date% %time% >> %LOG%
