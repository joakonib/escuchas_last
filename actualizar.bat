@echo off
rem Actualiza las escuchas de Last.fm, los tags de artistas, el reporte general
rem y el reporte del mes anterior (carpeta reportes).
rem Lo ejecuta una tarea del Programador de tareas de Windows el día 1 de cada mes
rem (o al prender el computador, si ese día estaba apagado). El log queda en data\actualizacion.log

cd /d C:\git_joako\escuchas_last
set LOG=data\actualizacion.log
set RSCRIPT="C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
set QUARTO="C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"

echo ==== %date% %time% ==== >> %LOG%
%RSCRIPT% descargar_escuchas.R >> %LOG% 2>&1
%RSCRIPT% descargar_tags.R >> %LOG% 2>&1
%QUARTO% render analisis_escuchas.qmd >> %LOG% 2>&1
%RSCRIPT% generar_reporte_mensual.R >> %LOG% 2>&1
echo Fin: %date% %time% >> %LOG%
