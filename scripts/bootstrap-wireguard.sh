docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e PEERS=1 \
  -p 51820:51820/udp \
  -v /var/config:/config \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  lscr.io/linuxserver/wireguard:latest


# sudo apt update && sudo apt upgrade

# # Turn on IP forwarding for IPv4.
# # edit /etc/sysctl.conf file, uncomment this line:
# # net.ipv4.ip_forward=1
# # then apply the changes.
# # sudo sysctl -p

