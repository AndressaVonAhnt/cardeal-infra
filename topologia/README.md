# topologia

Arquivos
- `topologia.png` 
- `topologia.drawio` (editável)


## Como ler

- **Retângulo tracejado:** tudo o que roda dentro do VirtualBox, no nosso computador. A internet fica de fora e só é alcançada pelo gw.
- **gw:** a única VM com duas placas de rede. A `enp0s3` (WAN) usa o NAT do VirtualBox para sair para a internet; a `enp0s8` (LAN) fica na rede interna com o IP 192.168.10.1.
- **Switch virtual:** a "Rede Interna" `cardeal-lan` do VirtualBox funciona como um switch. As VMs ligadas nele conversam diretamente entre si, sem passar pelo gw.
- **Cores:** laranja = infraestrutura (gw) · azul = servidores · verde = usuário.

## Endereçamento

| VM | Interface | IP | Serviços |
|---|---|---|---|
| gw | enp0s3 (WAN) | dado pelo NAT do VirtualBox | roteamento + NAT (iptables) |
| gw | enp0s8 (LAN) | 192.168.10.1/24 | DHCP (isc-dhcp-server), DNS (BIND9) |
| srv | enp0s3 | 192.168.10.10/24 (fixo) | Apache (HTTP, TCP 80), Samba (SMB, TCP 445) |
| mail | enp0s3 | 192.168.10.20/24 (fixo) | Postfix (SMTP, TCP 25), Dovecot (IMAP, TCP 143) |
| cliente | enp0s3 | DHCP, de .100 a .200 | i3, Firefox, Thunderbird, Wireshark |

Rede `192.168.10.0/24` · máscara 255.255.255.0 · gateway e DNS 192.168.10.1 · domínio `cardeal.local`.

## Por que esses endereços

- **192.168.0.0/16** é uma faixa privada (RFC 1918): não existe na internet, então pode ser usada internamente sem conflito. A saída para a internet é feita pelo NAT do gw.
- **192.168.10.x** evita conflito com as redes domésticas mais comuns (192.168.0.x e 192.168.1.x) e com a rede NAT do VirtualBox (10.0.2.x).
- **/24** separa 254 endereços para máquinas, mais que suficiente para a empresa.
- **Gateway no .1** é a convenção mais comum. **Servidores abaixo de .100**, com IP fixo, porque o DNS aponta nomes para eles. **Clientes de .100 a .200** pelo DHCP, sem sobrepor os IPs dos servidores.
