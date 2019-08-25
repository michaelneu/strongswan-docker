# strongswan-docker

This project aims to provide you with an easily deployable IKEv2 VPN from Docker. It's done by following [this Digital Ocean tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-18-04-2).

## WARNING

This isn't a production grade VPN system, use it at your own discretion. I mostly created this trying to containerise strongSwan and having a quickly deployable VPN container.

## Usage

After building this container (e.g. tagging it as `vpn`), run it as follows:

```bash
$ mkdir -p certs
$ docker run \
  --rm \
  -it \
  --cap-add=NET_ADMIN \
  -p 500:500/udp \
  -p 4500:4500/udp \
  -e CA_NAME="Your CA Name" \
  -e CA_CERT_DAYS=3650 \
  -e SERVER_ADDRESS_OR_DOMAIN=vpn.your-domain.com \
  -e SECRET_USERNAME=vpn \
  -e SECRET_PASSWORD="this should be a good password" \
  -v `pwd`/certs/cacerts:/etc/ipsec.d/cacerts \
  -v `pwd`/certs/certs:/etc/ipsec.d/certs \
  -v `pwd`/certs/private:/etc/ipsec.d/private \
  vpn
```

These variables are required to be passed to the container in order to setup strongSwan:

- `CA_NAME` is the name in your CA certificate
- `CA_CERT_DAYS` is the validity duration of the CA certificate
- `SERVER_ADDRESS_OR_DOMAIN` is either the IPv4 or the domain of your server
- `SECRET_USERNAME` is the username for your VPN
- `SECRET_PASSWORD` is the password for the above user

You may also use this container in a docker-compose setup:

```yaml
version: "3"
services:
  vpn:
    image: vpn
    cap_add:
      - NET_ADMIN
    ports:
      - 500:500/udp
      - 4500:4500/udp
    environment:
      - CA_NAME="Your CA Name"
      - CA_CERT_DAYS=3650
      - SERVER_ADDRESS_OR_DOMAIN=vpn.your-domain.com
      - SECRET_USERNAME=vpn
      - SECRET_PASSWORD="this should be a good password"
    volumes:
      - ./certs/cacerts:/etc/ipsec.d/cacerts
      - ./certs/certs:/etc/ipsec.d/certs
      - ./certs/private:/etc/ipsec.d/private
```

Additionally, you should allow traffic for port 500 and 4500 through your machine's firewall:

```bash
$ ufw allow 500,4500/udp
```

## License

This project is licensed under the [MIT license](LICENSE).
