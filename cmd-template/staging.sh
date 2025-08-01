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
# kubectl create secret generic rabbitmq-ca-cert --from-file=ca.pem=secrets/AmazonRootCA1.pem -n koala

# deploy koala
helm upgrade --install koala . -f values/staging.yaml -f secrets/staging.yaml --namespace koala --create-namespace

# force recreate pods
kubectl rollout restart deployment koala -n koala

# check release history
helm history koala -n koala




# =============== rabbitmq ===============

# update staging settings
helm upgrade --install rabbitmq . -f values/staging.yaml -f secrets/staging.yaml --namespace koala --create-namespace

# force recreate pods
kubectl rollout restart deployment rabbitmq -n koala

# check release history
helm history rabbitmq -n koala






# =============== drone runner ===============

# update staging settings
helm upgrade --install drone-runner . -f values/staging.yaml -f secrets/staging.yaml --namespace drone --create-namespace

# force recreate pods (each repo has its own deployment)
kubectl rollout restart deployment drone-runner-koala -n drone

# check release history
helm history drone-runner-koala -n drone

# note: 記得去github上綁drone的webhook
# https://drone.osdp25w.xyz/hook 




# =============== 權限設置 ===============

# 建立一個超級帳號(因為ns在kube-system)
kubectl -n kube-system create serviceaccount drone-ci

# 授權所有ns的所有操作權
kubectl create clusterrolebinding drone-ci-cluster-admin-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:drone-ci

# 獲取帳號的臨時token，後續無法查看
kubectl create token drone-ci -n kube-system

# 查看帳號的CA
kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
  | base64 -d

# 查看cluster host
kubectl config view -o jsonpath='{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}'

# 為超級帳號建立永久token
kubectl apply -f authorize-drone-ci.yaml

# 查看永久token
kubectl get secret drone-ci-token -n kube-system -o jsonpath="{.data.token}" | base64 --decode


# 檢查一個帳號在所有namespace下的權限
# 假設 ServiceAccount 在 koala namespace

# SA="system:serviceaccount:[USER在的NAMESPACE]:[USERNAME]"
SA="system:serviceaccount:kube-system:drone-ci"
NS="koala"

echo "===== 檢查 drone-ci 在 namespace 'koala' 下對 ConfigMap 的權限 ====="
for verb in get list watch create update patch delete; do
  printf "%-6s configmaps? ▶ " "$verb"
  kubectl auth can-i $verb configmaps --namespace=$NS --as=$SA
done

echo
echo "===== 檢查 drone-ci 在 namespace 'koala' 下對 Deployment 的權限 ====="
for verb in get list watch create update patch delete; do
  printf "%-6s deployments? ▶ " "$verb"
  kubectl auth can-i $verb deployments --namespace=$NS --as=$SA
done

echo
echo "===== 檢查 drone-ci 在 namespace 'koala' 下對 Pods 的權限 ====="
for verb in get list watch create update patch delete; do
  printf "%-6s pods? ▶ " "$verb"
  kubectl auth can-i $verb pods --namespace=$NS --as=$SA
done