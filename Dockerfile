FROM ubuntu:latest

RUN apt-get update \
    && apt-get install -y \
      strongswan \
      strongswan-pki \
      ufw \
      iproute2 \
    && rm -rf /var/lib/apt/lists/*

ADD entrypoint.sh .

EXPOSE 500/udp
EXPOSE 4500/udp

VOLUME [ "/etc/ipsec.d/certs", "/etc/ipsec.d/cacerts", "/etc/ipsec.d/private" ]
ENTRYPOINT [ "./entrypoint.sh" ]
