curl -sfL https://get.rke2.io | sudo sh - && \
sudo mkdir -p /etc/rancher/rke2 && \
sudo mkdir -p /var/lib/rancher/rke2/server/manifests

echo "Enable the Cilium CNI Plugin."

sudo tee -a /etc/rancher/rke2/config.yaml > /dev/null << EOF
cni: cilium
disable-kube-proxy: true
EOF

sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: "localhost"
    k8sServicePort: "6443"
    hubble:
      enabled: true
EOF


echo "Migrate Ingress NGINX to Traefik."

sudo tee -a /etc/rancher/rke2/config.yaml > /dev/null << EOF
ingress-controller:
  - traefik
EOF

sudo tee /var/lib/rancher/rke2/server/manifests/rke2-traefik-config.yaml > /dev/null << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesIngressNginx:
        enabled: true
        ingressClass: "rke2-ingress-nginx-migration"
        controllerClass: "rke2.cattle.io/ingress-nginx-migration"
EOF

echo "Start the cluster."
sudo systemctl enable rke2-server.service && \
sudo systemctl start rke2-server.service

echo "Post-installation"

echo 'PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.profile && \
source ~/.profile && \
mkdir ~/.kube && \
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config && \
sudo chown $USER:$USER ~/.kube/config

# หากมี master เครื่องเดียว
# kubectl scale deployment cilium-operator -n kube-system --replicas=1