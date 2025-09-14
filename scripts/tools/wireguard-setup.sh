h2 "apt install wireguard"
sudo apt-get update
sudo apt-get install -y curl wireguard

h2 "Generate Wireguard Keys, Curl and decrypt metadata, and set variables"
wg genkey > private.key
wg pubkey < private.key > public.key

PRIVATE_KEY=$(cat private.key)