# strongswan-docker

This project aims to provide you with an easily deployable IKEv2 VPN from Docker. It's done by following [this Digital Ocean tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-18-04-2).

## WARNING

This isn't a production grade VPN system, use it at your own discretion. I mostly created this trying to containerise strongSwan and to have a quickly deployable VPN container.

## Usage

After pulling this container, run it as follows:

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
  michaelneu/strongswan
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
    image: michaelneu/strongswan
    cap_add:
      - NET_ADMIN
    ports:
      - 500:500/udp
      - 4500:4500/udp
    environment:
      - CA_NAME=Your CA Name
      - CA_CERT_DAYS=3650
      - SERVER_ADDRESS_OR_DOMAIN=vpn.your-domain.com
      - SECRET_USERNAME=vpn
      - SECRET_PASSWORD=this should be a good password
    volumes:
      - ./certs/cacerts:/etc/ipsec.d/cacerts
      - ./certs/certs:/etc/ipsec.d/certs
      - ./certs/private:/etc/ipsec.d/private
```

Additionally, you should allow traffic for port 500 and 4500 through your machine's firewall:

```bash
$ ufw allow 500,4500/udp
```

## Connecting to the VPN

To connect to the VPN, you need to install the CA certificate that the server will output. Store it in either `ca-cert.pem` (macOS) or `ca-cert.der` (Windows) and install it to your certificate store. On Windows, make sure to install it to the "Trusted Root Certificate Authorities" store, whereas on macOS you need to trust the cert for IPSec.

### Connecting from macOS

Head to the network settings and add a VPN network, choose IKEv2 and enter your credentials (i.e. the remote ID and server address you configured and your user/password under Authentication).

### Connecting from Windows

Apparently, Windows uses a weak [Diffie-Hellman group](https://serverfault.com/a/965275). Using `regedit.exe`, you can create a new key `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Rasman\Parameters\NegotiateDH2048_AES256` with DWORD 1.

Once the stronger DH group is enabled, add a new VPN via the network settings (not control panel). Use Windows Built-In and IKEv2 and enter your credentials. To get your traffic routed through the VPN, you need to head over to the network adapter settings in the control panel and disable IPv6 in the Networking tab, and tick the "Use default gateway on remote network" checkbox under IPv4 properties/Advanced.

## License

This project is licensed under the [MIT license](LICENSE).
