# Cardeal Ltda: infraestrutura de rede

**Andressa Von Ahnt e Eduarda Fernandes**

*Trabalho de Redes de Computadores (UFPel)*

Uma rede de empresa simulada no VirtualBox, com gateway, DHCP, DNS, servidor Web, compartilhamento de arquivos (SMB) e e-mail interno.

## Topologia

| VM | Função | IP | Placas no VirtualBox |
|---|---|---|---|
| gw | Gateway + DHCP + DNS | 192.168.10.1 | 1: NAT (WAN) · 2: Rede Interna `cardeal-lan` (LAN) |
| srv | Apache + Samba | 192.168.10.10 (fixo) | Rede Interna `cardeal-lan` |
| mail | Postfix + Dovecot | 192.168.10.20 (fixo) | Rede Interna `cardeal-lan` |
| cliente | i3, Firefox, Thunderbird, Wireshark | DHCP (.100 a .200) | Rede Interna `cardeal-lan` |

Rede `192.168.10.0/24`, domínio `cardeal.local`. Todos os valores ficam em [`config.env`](config.env).

## Estrutura

```
.
├── config.env    valores compartilhados (IPs, domínio, placas)
├── modelo.sh     esqueleto para criar scripts novos
├── topologia/    desenho da rede
├── gateway/      roteamento + NAT           (roda no gw)
├── dhcp/         isc-dhcp-server            (roda no gw)
├── dns/          BIND9 + zona cardeal.local (roda no gw)
├── web/          Apache + página            (roda no srv)
├── samba/        compartilhamento SMB       (roda no srv)
├── email/        Postfix + Dovecot          (roda no mail)
├── cliente/      i3 + ferramentas           (roda no cliente)
├── wireshark/    capturas .pcapng
└── relatorio/    relatório + dificuldades.md
```

## Como usar

Em cada VM:

```bash
git clone <url-deste-repositorio>
cd <nome-do-repositorio>
sudo bash gateway/setup-gateway.sh   # exemplo
```

Ordem de execução numa instalação do zero:

1. `gw`: gateway → dhcp → dns
2. `srv`: web → samba
3. `mail`: email
4. `cliente`: cliente
