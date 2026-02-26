#!/usr/bin/env bash
# hypr-layout.sh
# Uso: TERMINAL="alacritty" TERMINAL_ARGS="-e" ./hypr-layout.sh
# Padrões: TERMINAL=kitty, TERMINAL_ARGS=-e
#
# O script tenta:
# 1) abrir terminal com htop e deixá-lo tiled (não flutuante)
# 2) abrir terminal com tock abaixo do htop (10% / 90%)
# 3) abrir terminal com stormy numa divisão horizontal (40% stormy / 60% htop)
# 4) abrir terminal com youtube-tui dividindo verticalmente o stormy (stormy 80% / youtube 20%)
#
# Requisitos: hyprctl, jq, um terminal com -e (padrão kitty/alacritty/foot/wezterm têm variações)
set -euo pipefail

TERMINAL="${TERMINAL:-kitty}"
TERMINAL_ARGS="${TERMINAL_ARGS:--e}" # ajuste se teu terminal usa outro sinal para "executar comando"
HYPRCTL="${HYPRCTL:-hyprctl}"
JQ="${JQ:-jq}"

SLEEP_STEP=0.12
WAIT_MAX=12 # segundos máximo pra esperar janelas aparecerem

echod() { echo -e "\e[1;36m>>\e[0m $*"; }

# pega lista de addresses atuais
get_addresses() {
  $HYPRCTL clients -j 2>/dev/null | $JQ -r '.[].address' 2>/dev/null || :
}

# tenta obter address pelo pid (caso o processo ainda exista)
get_address_by_pid() {
  local pid="$1"
  $HYPRCTL clients -j 2>/dev/null | $JQ -r --argjson pid "$pid" '.[] | select(.pid==$pid) | .address' 2>/dev/null || :
}

# espera por uma nova janela: tenta primeiro por pid, senão detecta novo address
wait_for_new_address() {
  local before_addresses="$1"
  local pid="$2"
  local t=0

  while ((t < WAIT_MAX * 10)); do
    # 1) tenta por PID (mais confiável se o processo não fork)
    if [ -n "$pid" ] && addr="$($HYPRCTL clients -j 2>/dev/null | $JQ -r --argjson pid "$pid" '.[] | select(.pid==$pid) | .address' 2>/dev/null)"; then
      [ -n "$addr" ] && {
        echo "$addr"
        return 0
      }
    fi

    # 2) tenta achar um address novo comparado ao "before"
    mapfile -t new_addrs < <(get_addresses)
    for a in "${new_addrs[@]}"; do
      if ! grep -qxF "$a" <<<"$before_addresses"; then
        echo "$a"
        return 0
      fi
    done

    sleep "$SLEEP_STEP"
    t=$((t + 1))
  done

  return 1
}

# retorna true/false se janela está em floating
is_floating() {
  local addr="$1"
  $HYPRCTL clients -j 2>/dev/null | $JQ -r --arg addr "$addr" '.[] | select(.address==$addr) | .floating' 2>/dev/null || echo "false"
}

# helper pra focar endereço
focus_addr() {
  local a="$1"
  $HYPRCTL dispatch focuswindow "address:$a" >/dev/null 2>&1 || true
  sleep 0.06
}

# helper pra togglefloating se estiver flutuando
ensure_tiled() {
  local a="$1"
  local fl
  fl="$(is_floating "$a")"
  if [ "$fl" = "true" ]; then
    echod "janela $a está flutuando → toggling floating (vai virar tiled)"
    $HYPRCTL dispatch togglefloating "address:$a" >/dev/null 2>&1 || true
    sleep 0.06
  fi
}

# spawn terminal command (retorna PID do processo que rodou o terminal)
spawn_term() {
  local cmd="$*"
  # Invocamos o terminal com & e disown; o PID retornado será do wrapper, usamos heurística depois.
  # Se teu terminal cria um processo pai que morre rápido, o pid pode não corresponder ao cliente Wayland — fallback é detectar novo address.
  if [[ "$TERMINAL" = "kitty" ]]; then
    # kitty costuma não sair imediato, -e funciona
    $TERMINAL $TERMINAL_ARGS $cmd &
    disown
    echo $!
  else
    # genérico
    $TERMINAL $TERMINAL_ARGS $cmd &
    disown
    echo $!
  fi
}

# ---------- fluxos das janelas ----------

echod "Iniciando montagem do layout (Hyprland). Padrão: TERMINAL=$TERMINAL $TERMINAL_ARGS"
echod "Verifica se hyprctl/jq existem..."
if ! command -v $HYPRCTL >/dev/null 2>&1; then
  echo "Erro: hyprctl não encontrado no PATH."
  exit 1
fi
if ! command -v $JQ >/dev/null 2>&1; then
  echo "Erro: jq não encontrado no PATH. Instala 'jq' (ex: sudo pacman -S jq)."
  exit 1
fi

# 1) abrir terminal com htop
echod "1) Abrindo terminal com htop..."
before="$(get_addresses)"
pid_htop=$(spawn_term htop)
echod " pid: $pid_htop — esperando a janela aparecer..."
addr_htop="$(wait_for_new_address "$before" "$pid_htop")" || {
  echo "timeout esperando htop"
  exit 1
}
echod "htop address = $addr_htop"
# garante tiled
ensure_tiled "$addr_htop"
focus_addr "$addr_htop"
sleep 0.12
echod "Redimensionando htop (area principal) para 100% x 90% (altura 90%)"
$HYPRCTL dispatch resizeactive exact 100% 90% >/dev/null 2>&1 || echod "resizeactive exact falhou (versão do Hyprland pode variar)."

# 2) abrir terminal com tock (embaixo), 10% do espaço
echod "2) Abrindo terminal com 'tock' (embaixo, 10%)..."
before="$(get_addresses)"
pid_tock=$(spawn_term tock)
echod " pid: $pid_tock — esperando tock..."
addr_tock="$(wait_for_new_address "$before" "$pid_tock")" || {
  echo "timeout esperando tock"
  exit 1
}
echod "tock address = $addr_tock"
# garante tiled
ensure_tiled "$addr_tock"
# movemos tock para baixo (tenta criar split vertical top/bottom)
focus_addr "$addr_tock"
sleep 0.06
# movewindow d tenta posicionar a janela abaixo do foco atual
$HYPRCTL dispatch movewindow d >/dev/null 2>&1 || true
sleep 0.08
echod "Redimensionando tock para 100% x 10% (altura 10%)"
$HYPRCTL dispatch resizeactive exact 100% 10% >/dev/null 2>&1 || echod "resizeactive exact p/ tock falhou."

# 3) abrir terminal com stormy e dividir horizontalmente (40% stormy / 60% htop)
echod "3) Abrindo terminal com 'stormy' (split horizontal 40%/60%)..."
# garante que o 'top area' (htop) está focado pra que o stormy abra ao lado
focus_addr "$addr_htop"
sleep 0.08
before="$(get_addresses)"
pid_stormy=$(spawn_term stormy)
echod " pid: $pid_stormy — esperando stormy..."
addr_stormy="$(wait_for_new_address "$before" "$pid_stormy")" || {
  echo "timeout esperando stormy"
  exit 1
}
echod "stormy address = $addr_stormy"
ensure_tiled "$addr_stormy"
# tenta colocar stormy ao lado (left/right), e ajustar tamanhos
# foco stormy e tenta dar 40% width
focus_addr "$addr_stormy"
sleep 0.08
echod "Redimensionando stormy para 40% x 100% (largura 40% do container topo)"
$HYPRCTL dispatch resizeactive exact 40% 100% >/dev/null 2>&1 || echod "resizeactive exact p/ stormy falhou."
# agora ajusta htop para 60% do topo
focus_addr "$addr_htop"
sleep 0.08
echod "Ajustando htop para 60% x 100% (restante do topo)"
$HYPRCTL dispatch resizeactive exact 60% 100% >/dev/null 2>&1 || echod "resizeactive exact p/ htop falhou."

# 4) abrir terminal e dividir verticalmente dentro do stormy (stormy 80% / youtube-tui 20%)
echod "4) Abrindo terminal com 'youtube-tui' dividindo o stormy verticalmente (stormy 80% / youtube 20%)..."
# foca stormy (para abrir o split dentro do container dele)
focus_addr "$addr_stormy"
sleep 0.08
before="$(get_addresses)"
pid_yt=$(spawn_term youtube-tui)
echod " pid: $pid_yt — esperando youtube-tui..."
addr_yt="$(wait_for_new_address "$before" "$pid_yt")" || {
  echo "timeout esperando youtube-tui"
  exit 1
}
echod "youtube-tui address = $addr_yt"
ensure_tiled "$addr_yt"
# tenta mover youtube-tui pra baixo do stormy (split vertical / stacked), e ajustar tamanhos
focus_addr "$addr_yt"
sleep 0.06
$HYPRCTL dispatch movewindow d >/dev/null 2>&1 || true
sleep 0.08
echod "Ajustando stormy para 80% e youtube para 20% (alturas dentro do container)"
# dependendo do comportamento do compositor esse resize pode agir no container certo; tenta na ordem:
focus_addr "$addr_stormy"
sleep 0.06
$HYPRCTL dispatch resizeactive exact 100% 80% >/dev/null 2>&1 || echod "resizeactive exact p/ stormy (80%) falhou."
focus_addr "$addr_yt"
sleep 0.06
$HYPRCTL dispatch resizeactive exact 100% 20% >/dev/null 2>&1 || echod "resizeactive exact p/ youtube (20%) falhou."

echod "Layout criado (tentativa). Se algo não ficou no lugar, pode ser por diferenças de versão/configuração do Hyprland."
echod "Janelas criadas:"
$HYPRCTL clients -j 2>/dev/null | $JQ -r '.[] | "\(.initialClass) \(.title) \(.address) floating:\(.floating) workspace:\(.workspace.id)"'
