sudo apt install curl tree git -y

apt update && apt upgrade -y
apt install -y curl tree wireguard git

#gcloud cli
cd ~
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh #blank when asked to add path > bashrc
source ~/.bashrc

gcloud config set project $PROJECT_ID
gcloud auth login

sudo apt install git -y
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

git config --global user.email "josh.v.mcconnell@gmail.com"
git config --global user.name "josh m"


sudo apt install wireguard git dh-autoreconf libglib2.0-dev intltool build-essential libgtk-3-dev libnma-dev libsecret-1-dev network-manager-dev resolvconf

cd ~
git clone https://github.com/max-moser/network-manager-wireguard
cd network-manager-wireguard
./autogen.sh --without-libnm-glib

./configure --without-libnm-glib --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib/x86_64-linux-gnu --libexecdir=/usr/lib/NetworkManager --localstatedir=/var

make   
sudo make install


sudo apt install wireguard -y
