PS Z:\lab-segmentacion-firewall> docker exec client-a wget -q -O /dev/null -T 3 http://10.10.2.10
PS Z:\lab-segmentacion-firewall> docker exec client-a wget -q -O /dev/null -T 3 http://10.10.2.10:8080
wget: download timed out
PS Z:\lab-segmentacion-firewall> docker exec web-a ping -c 2 -W 2 10.10.1.10
PING 10.10.1.10 (10.10.1.10): 56 data bytes

--- 10.10.1.10 ping statistics ---
2 packets transmitted, 0 packets received, 100% packet loss
PS Z:\lab-segmentacion-firewall> docker exec attacker ping -c 2 -W 2 203.0.113.10
PING 203.0.113.10 (203.0.113.10) 56(84) bytes of data.

--- 203.0.113.10 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1005ms

PS Z:\lab-segmentacion-firewall> docker exec attacker nmap -Pn -p 22,80,443,500 203.0.113.10
Starting Nmap 7.95 ( https://nmap.org ) at 2026-11-03 04:22 UTC
Nmap scan report for fw-a.lab-segmentacion_wan (203.0.113.10)
Host is up (0.000051s latency).

PORT    STATE    SERVICE
22/tcp  filtered ssh
80/tcp  filtered http
443/tcp filtered https
500/tcp filtered isakmp
MAC Address: A2:6F:2A:86:6E:7C (Unknown)

Nmap done: 1 IP address (1 host up) scanned in 1.52 seconds
PS Z:\lab-segmentacion-firewall> docker exec fw-a nft list chain inet lab_filter input
table inet lab_filter {
        chain input {
                type filter hook input priority filter; policy drop;
                ct state established,related counter packets 0 bytes 0 accept
                ct state invalid counter packets 0 bytes 0 drop
                iifname "lo" accept
                ip saddr 10.10.1.0/24 icmp type echo-request counter packets 0 bytes 0 accept
                counter packets 10 bytes 520 comment "descartado: input"
        }
}
PS Z:\lab-segmentacion-firewall> docker exec fw-a nft list chain inet lab_filter forward
table inet lab_filter {
        chain forward {
                type filter hook forward priority filter; policy drop;
                ct state established,related counter packets 11 bytes 1795 accept
                ct state invalid counter packets 0 bytes 0 drop
                ip saddr 10.10.1.0/24 ip daddr 10.10.2.10 tcp dport { 80, 443 } counter packets 1 bytes 60 accept
                ip saddr 10.10.1.0/24 ip daddr 10.10.2.0/24 icmp type echo-request counter packets 0 bytes 0 accept
                counter packets 5 bytes 348 comment "descartado: forward"
        }
}
PS Z:\lab-segmentacion-firewall>

explicacion de resultados

La primera no debe imprimir nada (acceso permitido).
La segunda debe terminar en timed out: el puerto 8080 no está permitido.
La tercera y la cuarta deben fallar con 100% de pérdida.
El nmap debe mostrar los cuatro puertos como filtered (no closed, porque el firewall descarta en silencio).
El antepenultimo comando debe mostrar los contadores de input con paquetes descartados.
El ultimo comando debería mostrar paquetes en la regla LAN → web (80, 443)