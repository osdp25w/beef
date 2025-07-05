# 列出VPC資訊
aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,CidrBlock,Tags]" --output json


# ingress-nginx-controller
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace -f ingress-controller/ingress-nginx-controller.yaml

