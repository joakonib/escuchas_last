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


rem Publica los reportes en GitHub Pages (carpeta docs) y sube los cambios
copy /Y analisis_escuchas.html docs\index.html >> %LOG% 2>&1
copy /Y analisis_escuchas.html docs\analisis_escuchas.html >> %LOG% 2>&1
copy /Y reporte_mensual.html docs\reporte_mensual.html >> %LOG% 2>&1
git add docs >> %LOG% 2>&1
git commit -m "Actualización mensual de los reportes" >> %LOG% 2>&1
git pull --rebase >> %LOG% 2>&1
git push >> %LOG% 2>&1
echo Publicado: %date% %time% >> %LOG%
