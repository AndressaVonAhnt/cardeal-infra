# gateway

**VM:** gw · **Responsável:** Pessoa A

Transforma o gw em roteador: liga o repasse de pacotes entre as placas (`ip_forward`) e faz NAT para a LAN sair pela WAN.

- `setup-gateway.sh`: rede (netplan), ip_forward e regras do iptables

Testar: do cliente, `ping 8.8.8.8`.
