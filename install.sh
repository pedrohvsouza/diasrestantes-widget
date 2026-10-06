#!/usr/bin/env bash
# Instala (ou atualiza) o widget "Dias Restantes" no Plasma 6.
set -euo pipefail

ID="diasrestantes"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package"
DEST="$HOME/.local/share/plasma/plasmoids/$ID"

if [[ ! -f "$SRC/metadata.json" ]]; then
    echo "Fonte não encontrado em $SRC" >&2
    exit 1
fi

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$SRC" "$DEST"
echo "Instalado em $DEST"

if [[ "${1:-}" == "--restart" ]]; then
    echo "Reiniciando o plasmashell…"
    systemctl --user restart plasma-plasmashell.service
    echo "Pronto."
else
    echo
    echo "Para o Plasma reler o widget, rode:"
    echo "  systemctl --user restart plasma-plasmashell.service"
fi
