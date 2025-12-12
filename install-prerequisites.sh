#!/bin/bash

# --- Шаг 1: Настройка модулей ядра и параметров сети ---
echo "[ШАГ 1] Настройка модулей ядра и сети..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
echo "--- Готово ---"
echo

# --- Шаг 2: Установка Containerd ---
echo "[ШАГ 2] Установка Containerd..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y containerd.io
echo "--- Готово ---"
echo

# --- Шаг 3: Конфигурация Containerd ---
echo "[ШАГ 3] Конфигурация Containerd..."
sudo mkdir -p /etc/containerd
# Создаем конфигурационный файл с параметрами, совместимыми с Kubernetes
sudo tee /etc/containerd/config.toml > /dev/null <<EOF
version = 2
[grpc]
  address = "/run/containerd/containerd.sock"
  uid = 0
  gid = 0
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true
EOF
# Перезапускаем containerd, чтобы применить изменения
sudo systemctl restart containerd
echo "--- Готово ---"
echo

# --- Шаг 4: Установка компонентов Kubernetes и cri-tools ---
echo "[ШАГ 4] Установка kubeadm, kubelet, kubectl и cri-tools..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl cri-tools
sudo apt-mark hold kubelet kubeadm kubectl
echo "--- Готово ---"
echo

# --- Шаг 5: Конфигурация crictl ---
echo "[ШАГ 5] Конфигурация crictl..."
# Создаем конфигурационный файл для crictl, чтобы он знал, как общаться с containerd
sudo tee /etc/crictl.yaml > /dev/null <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
echo "--- Готово ---"
echo

echo "Все необходимые компоненты и утилиты успешно установлены и настроены!"
