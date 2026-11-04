#!/bin/sh
set -e

# 1) Sin ruta por defecto: el laboratorio no sale a internet
while ip route del default 2>/dev/null; do :; done

# 2) Reglas del firewall. Si fallan, el contenedor se detiene (fail-closed):
#    es mejor que no arranque a que funcione sin filtrado.
nft -f /etc/nftables/lab.nft || { echo "ERROR: no se pudieron cargar las reglas nftables"; exit 1; }

# 3) Clave compartida desde la variable de entorno (nunca se guarda en el repositorio)
umask 077
printf '@fw-a @fw-b : PSK "%s"\n' "$IPSEC_PSK" > /etc/ipsec.secrets

# 4) strongSwan en primer plano
exec ipsec start --nofork
