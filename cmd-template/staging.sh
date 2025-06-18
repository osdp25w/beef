helm upgrade --install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager --namespace kube-system --create-namespace -f ingress-nginx-controller.yaml


# 列出VPC資訊
aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,CidrBlock,Tags]" --output table