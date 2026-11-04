Evidencias del bloque 3: túnel IPsec entre sedes

Salidas reales del laboratorio. Los nombres de interfaz (ethX) cambian cuando Docker recrea las redes; en cada captura las direcciones IP identifican cada extremo.

1. El túnel está establecido (ipsec statusall en fw-a)
site-to-site:   child:  10.10.1.0/24 10.10.2.0/24 === 10.20.1.0/24 10.20.2.0/24 TUNNEL
site-to-site[1]: ESTABLISHED 16 minutes ago, 203.0.113.10[fw-a]...203.0.113.20[fw-b]
site-to-site[1]: IKE proposal: AES_CBC_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
site-to-site{1}:  INSTALLED, TUNNEL, reqid 1, ESP SPIs: c8d4f966_i c9a40e47_o
site-to-site{1}:  AES_GCM_16_256, 0 bytes_i, 0 bytes_o, rekeying in 31 minutes

Qué demuestra: IKEv2 con PSK, IKE con AES-256 y SHA-256 sobre MODP-2048, y ESP con AES-GCM de 256 bits. Los 0 bytes corresponden a un momento en que aún no había pasado tráfico entre sedes.

2. Conectividad entre sedes (LAN A a LAN B)
> docker exec client-a ping -c 3 10.20.1.10
64 bytes from 10.20.1.10: seq=0 ttl=62 time=0.257 ms
64 bytes from 10.20.1.10: seq=1 ttl=62 time=0.220 ms
64 bytes from 10.20.1.10: seq=2 ttl=62 time=0.202 ms
3 packets transmitted, 3 packets received, 0% packet loss

Qué demuestra: ttl=62 (salió con 64) indica que el paquete atravesó dos routers, fw-a y fw-b.

3. En la WAN solo viaja tráfico cifrado (captura en fw-a durante un ping entre sedes)
> docker exec fw-a tcpdump -l -ni any -c 4 esp
eth2  Out IP 203.0.113.10 > 203.0.113.20: ESP(spi=0xcedf52ad,seq=0xb), length 120
eth2  In  IP 203.0.113.20 > 203.0.113.10: ESP(spi=0xcdacd4c3,seq=0x9), length 120
eth2  Out IP 203.0.113.10 > 203.0.113.20: ESP(spi=0xcedf52ad,seq=0xc), length 120
eth2  In  IP 203.0.113.20 > 203.0.113.10: ESP(spi=0xcdacd4c3,seq=0xa), length 120

Qué demuestra: entre las dos direcciones de la WAN aparece ESP con un SPI distinto por sentido y números de secuencia crecientes. Cada paquete mide 120 bytes: 84 del ping original más la sobrecarga de ESP con AES-GCM.

4. Las reglas siguen limitando lo que cruza el túnel
> docker exec client-b ping -c 2 -W 2 10.10.2.10     # LAN B a DMZ A por ICMP
2 packets transmitted, 0 packets received, 100% packet loss

> docker exec web-a ping -c 2 -W 2 10.20.1.10        # DMZ A a LAN B
2 packets transmitted, 0 packets received, 100% packet loss

Qué demuestra: aunque exista el túnel, solo pasa lo que permiten las reglas (ping LAN a LAN y HTTP/HTTPS al servidor web de la DMZ remota).

Pendiente de añadir
Contadores de nft list chain inet lab_filter input tras el establecimiento del túnel, y ipsec statusall con bytes_i y bytes_o distintos de cero.