#!/bin/sh
set -e

# 1) Sin ruta por defecto: el laboratorio no sale a internet
while ip route del default 2>/dev/null; do :; done

# 2) Reglas del firewall. Si fallan, el contenedor se detiene (fail-closed):
#    es mejor que no arranque a que funcione sin filtrado.
nft -f /etc/nftables/lab.nft || { echo "ERROR: no se pudieron cargar las reglas nftables"; exit 1; }

# 3) Anti-spoofing opcional (bloque 4). Se activa con ANTISPOOF=1 en .env
if [ "${ANTISPOOF:-0}" = "1" ]; then
  # Nombre de la interfaz que tiene una IP dada
  iface_of() { ip -o -4 addr show | awk -v ip="$1" '$4 ~ "^" ip "/" { sub(/@.*/, "", $2); print $2; exit }'; }
  WAN_IF=$(iface_of "$FW_WAN_IP")
  LAN_IF=$(iface_of "$FW_LAN_IP")
  DMZ_IF=$(iface_of "$FW_DMZ_IP")
  echo "Anti-spoofing ACTIVO: WAN=$WAN_IF LAN=$LAN_IF DMZ=$DMZ_IF"
  if [ -z "$WAN_IF" ] || [ -z "$LAN_IF" ] || [ -z "$DMZ_IF" ]; then
    echo "ERROR: no se pudieron detectar las interfaces"; exit 1
  fi
  sed -e "s/__WAN_IF__/$WAN_IF/g" -e "s/__LAN_IF__/$LAN_IF/g" -e "s/__DMZ_IF__/$DMZ_IF/g" \
      /etc/nftables/antispoof.nft > /tmp/antispoof.nft
  nft -f /tmp/antispoof.nft || { echo "ERROR: no se pudieron cargar las reglas anti-spoofing"; exit 1; }
else
  echo "Anti-spoofing DESACTIVADO (ANTISPOOF=0)"
fi

# 4) Clave compartida desde la variable de entorno (nunca se guarda en el repositorio)
umask 077
printf '@fw-a @fw-b : PSK "%s"\n' "$IPSEC_PSK" > /etc/ipsec.secrets

# 5) strongSwan en primer plano
exec ipsec start --nofork
