apt update && apt upgrade -y
apt install -y curl tree

#gcloud cli
cd ~
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh #blank when asked to add path > bashrc
source ~/.bashrc


sudo apt install git -y
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  git config --global user.email "josh.v.mcconnell@gmail.com"
  git config --global user.name "josh m"