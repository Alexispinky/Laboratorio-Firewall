# Evidencias del bloque 4: anti-spoofing y validación

Salidas reales del laboratorio. Los nombres de interfaz cambian cuando Docker recrea las redes, así que en cada prueba se indica cuál era la WAN.

## Prueba A: origen interno falsificado desde la WAN

El atacante (en la WAN) se hace pasar por `client-a` (`10.10.1.10`) y escribe a la DMZ (`10.10.2.10`).

**Sin anti-spoofing** (`ANTISPOOF=0`; en `fw-a` la WAN era `eth1` y la DMZ `eth2`):

```
eth1  In  IP 10.10.1.10 > 10.10.2.10: ICMP echo request, id 1, seq 1, length 64
eth2  Out IP 10.10.1.10 > 10.10.2.10: ICMP echo request, id 1, seq 1, length 64
eth1  In  IP 10.10.1.10 > 10.10.2.10: ICMP echo request, id 1, seq 2, length 64
eth2  Out IP 10.10.1.10 > 10.10.2.10: ICMP echo request, id 1, seq 2, length 64
```

Resultado: **el firewall reenvió los paquetes falsificados** (entran por la WAN y salen hacia la DMZ), porque coinciden con la regla que permite a la LAN llegar a la DMZ.

**Con anti-spoofing** (`ANTISPOOF=1`; en `fw-a` la WAN era `eth2`):

```
eth2  In  IP 10.10.1.10 > 10.10.2.10: ICMP echo request, id 4, seq 1, length 64
eth2  In  IP 10.10.1.10 > 10.10.2.10: ICMP echo request, id 4, seq 2, length 64

iifname "eth2" ip saddr { 10.10.1.0-10.10.2.255 } counter packets 2 bytes 168 drop
   comment "spoofing: origen interno desde la WAN"
```

Resultado: los paquetes entran y **no salen**. El contador marca 2 paquetes y 168 bytes, los 2 pings de 84 bytes.

Nota: nft muestra `priority mangle` para la prioridad -150 y une las dos redes /24 contiguas en un solo rango; es equivalente a lo escrito.

## Prueba B: origen falsificado de la otra sede, sin cifrar

El atacante envía `10.20.1.10 > 10.10.1.10` en claro (corrida con `ANTISPOOF=0`; en `fw-a` la WAN era `eth1`).

```
eth1  In  IP 10.20.1.10 > 10.10.1.10: ICMP echo request, id 3, seq 1, length 64
eth1  In  IP 10.20.1.10 > 10.10.1.10: ICMP echo request, id 3, seq 2, length 64

XfrmInTmplMismatch              2      (antes: 0)
```

Resultado: entran y no salen. El kernel los descartó porque coinciden con la política IPsec del túnel y llegaron sin cifrar. Esta protección existe mientras el túnel está activo; con el túnel caído no está verificada.

Una prueba previa con `ping` hacia `10.10.1.10` resultó inválida: esa dirección estaba asignada al propio atacante y el ping nunca salió de él (`ttl=64`, contadores sin cambios). Se corrigió quitando esa dirección antes de la prueba.

## Prueba C: el puerto IKE frente a un atacante en la WAN

```
> docker exec attacker nmap -sU -Pn -p 500,4500 203.0.113.10
500/udp  open|filtered isakmp
4500/udp open|filtered nat-t-ike

Contador "descartado: input":   0 paquetes  ->  10 paquetes, 1180 bytes
Reglas que aceptan IKE y ESP del par:  0 paquetes antes y después
```

Resultado: los sondeos del atacante se descartaron en la regla final. Nmap no puede distinguir abierto de filtrado en UDP con un descarte silencioso, por eso la evidencia está en los contadores.

Las reglas de aceptación de IKE y ESP marcan 0 porque `fw-a` inició el túnel y las respuestas del par entran como conexiones establecidas (primera regla, 3 paquetes y 1324 bytes). Es una explicación sin verificar; esas reglas se ejercitan cuando el par inicia o renegocia.

## Regresión: el anti-spoofing no rompe el túnel (`ANTISPOOF=1`)

```
> docker exec client-a ping -c 3 10.20.1.10
64 bytes from 10.20.1.10: seq=0 ttl=62 time=1.207 ms
3 packets transmitted, 3 packets received, 0% packet loss

> docker exec client-a wget -S -O /dev/null -T 3 http://10.20.2.10
  HTTP/1.1 200 OK

> docker exec fw-b nft list table inet lab_antispoof     # fw-b: WAN eth0, DMZ eth1, LAN eth2
iifname "eth0" ip saddr { 10.20.1.0-10.20.2.255 } counter packets 0 bytes 0 drop
iifname "eth2" ip saddr != 10.20.1.0/24 counter packets 0 bytes 0 drop
iifname "eth1" ip saddr != 10.20.2.0/24 counter packets 0 bytes 0 drop
```

Resultado: el tráfico legítimo entre sedes sigue funcionando y los tres contadores de descarte de `fw-b` están en 0, es decir, el anti-spoofing no descartó tráfico válido.