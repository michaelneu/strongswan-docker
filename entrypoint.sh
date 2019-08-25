#!/bin/bash

if [[ -f "/etc/ipsec.d/key.pem" ]]; then
  echo "generating keys and certificates"

  echo "-> ca key"
  ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/ca-key.pem

  echo "-> ca certificate (CN=$CA_NAME), valid for $CA_CERT_DAYS"
  ipsec pki --self --ca --lifetime $CA_CERT_DAYS --in /etc/ipsec.d/private/ca-key.pem \
    --type rsa --dn "CN=$CA_NAME" --outform pem > /etc/ipsec.d/cacerts/ca-cert.pem

  echo "-> server key"
  ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/server-key.pem

  echo "-> server certificate (CN=$SERVER_ADDRESS_OR_DOMAIN)"
  ipsec pki --pub --in /etc/ipsec.d/private/server-key.pem --type rsa \
    | ipsec pki --issue --lifetime 1825 \
        --cacert /etc/ipsec.d/cacerts/ca-cert.pem \
        --cakey /etc/ipsec.d/private/ca-key.pem \
        --dn "CN=$SERVER_ADDRESS_OR_DOMAIN" --san "$SERVER_ADDRESS_OR_DOMAIN" \
        --flag serverAuth --flag ikeIntermediate --outform pem \
    >  /etc/ipsec.d/certs/server-cert.pem
fi

echo "generating strongswan config"

# short version of https://www.linuxjournal.com/content/validating-ip-address-bash-script
# it's safe to assume that anything that looks remotely like an ip is an ip in this context
if [[ $SERVER_ADDRESS_OR_DOMAIN =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "-> ip address provided"
else
  echo "-> prefixing domain with @ symbol"
  SERVER_ADDRESS_OR_DOMAIN="@$SERVER_ADDRESS_OR_DOMAIN"
fi

cat << EOF > /etc/ipsec.conf
conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=$SERVER_ADDRESS_OR_DOMAIN
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=1.1.1.1,1.0.0.1
    rightsendcert=never
    eap_identity=%identity
EOF

echo "generating secrets file for user $SECRET_USERNAME"
cat << EOF > /etc/ipsec.secrets
: RSA "server-key.pem"

$SECRET_USERNAME : EAP "$SECRET_PASSWORD"
EOF

echo "configuring firewall"
ufw allow 500,4500/udp

interface=$(ip route | grep default | awk '{ print $5 }')
echo "-> detected interface $interface"

echo "-> addding nat configuration"
cat << EOF > /etc/ufw/before.rules
*nat
-A POSTROUTING -s 10.10.10.0/24 -o $interface -m policy --pol ipsec --dir out -j ACCEPT
-A POSTROUTING -s 10.10.10.0/24 -o $interface -j MASQUERADE
COMMIT

*mangle
-A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o $interface -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
COMMIT

$(cat /etc/ufw/before.rules | sed "s/^COMMIT$//")

-A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT
-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT

COMMIT
EOF

echo "-> enabling ip packet forwarding"
cat << EOF >> /etc/ufw/sysctl.conf
net/ipv4/ip_forward=1
net/ipv4/conf/all/accept_redirects=0
net/ipv4/conf/all/send_redirects=0
net/ipv4/ip_no_pmtu_disc=1
EOF

echo "-> restarting firewall"
ufw disable
ufw enable

echo "starting strongswan"
systemctl start strongswan

echo "setup done, install this ca certificate on your device:"
cat /etc/ipsec.d/cacerts/ca-cert.pem

# prevent the container from exiting after the script finishes
# see https://stackoverflow.com/a/41655546/2058898
while true; do
  sleep 2073600
done
