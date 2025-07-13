# =============== aws ===============
# 列出VPC資訊
aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,CidrBlock,Tags]" --output json







# =============== ingress-nginx-controller ===============
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace -f ingress-controller/ingress-nginx-controller.yaml




# =============== HTTPS ===============
# 部署 證書請求服務
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

# 查看 證書請求服務
kubectl get pods -n cert-manager

# 部署 cert-manager
kubectl apply -f clusterissuer.yaml

# 查看 cert-manager
kubectl get clusterissuer




# =============== drone server ===============

# update staging settings
helm upgrade --install drone-svc . -f values/staging.yaml -f secrets/staging.yaml --namespace drone --create-namespace

# force recreate pods
kubectl rollout restart deployment drone-svc -n drone

# check release history
helm history drone-svc -n drone


# =============== koala ===============

# mount aws ca
# create ns first
kubectl create namespace koala
# create secret
kubectl create secret generic rabbitmq-ca-cert --from-file=ca.pem=secrets/AmazonRootCA1.pem -n koala

# deploy koala
helm upgrade --install koala . -f values/staging.yaml -f secrets/staging.yaml --namespace koala --create-namespace

# force recreate pods
kubectl rollout restart deployment koala -n koala

# check release history
helm history koala -n koala