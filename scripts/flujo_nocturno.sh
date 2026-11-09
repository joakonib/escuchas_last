#!/usr/bin/env bash
# Flujo B de FLUJO_DE_TRABAJO.txt: corrida completa con revisión antes de publicar.
# Descarga (opcionalmente desde cero), chequea las letras, se pausa para el análisis
# de los datos y los textos, renderiza, publica (commit, pull, push) y, si se pide,
# apaga el PC. Todo queda con hora en data/noche.log.
#
# Uso: bash scripts/flujo_nocturno.sh [--mes AAAA-MM] [--desde-cero] [--reentrenar] [--apagar]
#   --mes         mes del reporte mensual (por defecto, el mes anterior)
#   --desde-cero  vuelve a bajar todo el historial de Last.fm y lo verifica contra un respaldo
#   --reentrenar  vuelve a entrenar los modelos de temas y playlists (hay que reescribir sus textos)
#   --apagar      apaga el PC al terminar (solo con la confirmación expresa de Joaquín en ese momento)
#
# Reintentos: 4 para lo que falla por la red (descargas, pull, push) y 2 para los
# renders (un error de código no se arregla reintentando). Si un render falla, no se
# publica nada: se deja registrado y el flujo termina sin subir HTML viejo.

cd /c/git_joako/escuchas_last || exit 1
R="/c/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
Q="/c/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"
S=data/respaldo   # respaldos y archivos de control (data/ no se sube)
LOG=data/noche.log

MES=$(date -d "$(date +%Y-%m-01) -1 day" +%Y-%m)
DESDE_CERO=0; APAGAR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mes) MES=$2; shift ;;
    --desde-cero) DESDE_CERO=1 ;;
    --apagar) APAGAR=1 ;;
    --reentrenar) export REENTRENAR_MODELOS=1 ;;
  esac
  shift
done

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

# Uso: reintentar <intentos> "Descripción" comando argumentos...
reintentar() {
  local max=$1 desc=$2; shift 2
  for i in $(seq 1 "$max"); do
    log "$desc: intento $i de $max"
    if "$@" >> "$LOG" 2>&1; then log "$desc: OK"; return 0; fi
    log "$desc: falló"
    [ "$i" -lt "$max" ] && sleep 60
  done
  log "$desc: FALLÓ $max veces"
  return 1
}

apagar() {
  if [ "$APAGAR" = 1 ]; then
    log "Apagando el PC en 2 minutos (cancelar: shutdown /a)"
    powershell -NoProfile -Command "shutdown /s /t 120 /c 'Flujo de escuchas_last terminado'"
  fi
}

mkdir -p "$S"

# Candado compartido con actualizar.bat: dos flujos a la vez dañan los archivos.
# mkdir es atómico; un candado de más de 12 horas es de una corrida que se cortó.
find data/flujo.lock -maxdepth 0 -mmin +720 -exec rmdir {} \; 2>/dev/null
if ! mkdir data/flujo.lock 2>/dev/null; then
  log "Hay otro flujo en curso (data/flujo.lock): no se ejecuta"
  exit 1
fi
trap 'rmdir data/flujo.lock 2>/dev/null' EXIT

log "==== Inicio flujo completo (mes $MES, desde cero: $DESDE_CERO) ===="

# 0. Respaldo de las escuchas, siempre, antes de tocar nada
if [ -f data/escuchas.parquet ]; then
  cp data/escuchas.parquet "$S/escuchas_respaldo.parquet"
  log "Respaldo de escuchas hecho"
elif [ "$DESDE_CERO" = 1 ]; then
  log "No hay escuchas que respaldar: la descarga desde cero se hace sin verificación"
fi

# 1. Descargas
verificar_escuchas() {
  "$R" scripts/01.verificar_escuchas.R "$S/escuchas_respaldo.parquet"
}
if [ "$DESDE_CERO" = 1 ] && [ -f "$S/escuchas_respaldo.parquet" ]; then
  rm -f data/escuchas.parquet
  if reintentar 4 "Escuchas desde cero" "$R" scripts/00.descargar_escuchas.R && verificar_escuchas >> "$LOG" 2>&1; then
    log "Escuchas: descarga desde cero verificada contra el respaldo"
  else
    log "Descarga desde cero incompleta: restauro el respaldo y completo de forma incremental"
    cp "$S/escuchas_respaldo.parquet" data/escuchas.parquet
    reintentar 4 "Escuchas (incremental)" "$R" scripts/00.descargar_escuchas.R
  fi
else
  reintentar 4 "Escuchas (incremental)" "$R" scripts/00.descargar_escuchas.R
  if [ -f "$S/escuchas_respaldo.parquet" ] && ! verificar_escuchas >> "$LOG" 2>&1; then
    log "Escuchas: menos que el respaldo, se restaura"
    cp "$S/escuchas_respaldo.parquet" data/escuchas.parquet
  fi
fi
reintentar 4 "Etiquetas" "$R" scripts/02.descargar_tags.R
reintentar 4 "Letras" "$R" scripts/03.descargar_letras.R
reintentar 4 "Clima" "$R" scripts/04.descargar_clima.R

# 2. Chequeo de letras
"$R" scripts/05.chequear_letras.R >> "$LOG" 2>&1
log "Chequeo de letras registrado arriba"
"$R" scripts/06.chequear_estilo.R >> "$LOG" 2>&1
log "Chequeo de estilo de los textos registrado arriba (ver ESTILO.md)"

# 3. Pausa para el análisis de los datos y la actualización de los textos.
# Quien revisa crea data/respaldo/analisis_ok al terminar; si no aparece en 60 min, se sigue igual.
rm -f "$S/analisis_ok"; touch "$S/esperando_analisis"
log "Pausa: esperando el análisis de los datos antes del render (máx. 60 min)"
for i in $(seq 1 120); do [ -f "$S/analisis_ok" ] && break; sleep 30; done
if [ -f "$S/analisis_ok" ]; then log "Análisis terminado; sigo con el render"; else log "Sin análisis en 60 min; sigo igual con el render"; fi
rm -f "$S/esperando_analisis"

# 4. Reportes: si alguno falla, no se publica
ok=1
reintentar 2 "Render reporte general" "$Q" render 07.analisis_escuchas.qmd || ok=0
reintentar 2 "Render reporte mensual ($MES)" "$R" scripts/08.generar_reporte_mensual.R "$MES" || ok=0
reintentar 2 "Render metodología" "$Q" render 09.metodologia.qmd || ok=0
if [ "$ok" = 0 ]; then
  log "==== Un render falló: NO se publica. Revisar el log. ===="
  apagar
  exit 1
fi
cp analisis_escuchas.html reporte_mensual.html metodologia.html docs/ && log "Reportes copiados a docs/"

# 5. Limpieza (paso 4.0 del flujo) y publicación
rm -rf .Rhistory ./*_files ./*.knit.md ./*.rmarkdown; log "Limpieza de temporales hecha"
git add -u >> "$LOG" 2>&1
git add docs assets R scripts FLUJO_DE_TRABAJO.txt >> "$LOG" 2>&1
git commit -q -m "change: actualización completa de los reportes ($(date +%d-%m-%Y))" >> "$LOG" 2>&1
log "Commit: $(git log --oneline -1)"
reintentar 4 "Pull" git pull --rebase
reintentar 4 "Push" git push

log "==== Fin del flujo ===="
apagar
