#!/usr/bin/env bash
set -eo pipefail

sudo sysctl net.ipv4.ip_forward=1
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -s 192.168.0.0/24 -j ACCEPT
sudo iptables -A POSTROUTING -t nat -j MASQUERADE -s 192.168.0.0/24
sudo iptables-save
