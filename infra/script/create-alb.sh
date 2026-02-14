#!/bin/bash
set -euo pipefail

### ===== 설정값 =====
CLUSTER_NAME="alive-cluster"
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"
IAM_POLICY_FILE="iam_policy.json"

echo "=== 1. IAM 정책 다운로드 ==="
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json

echo "=== 2. 기존 IAM 정책 삭제 (있으면) ==="
if aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text | grep -q 'arn:'; then
    echo "기존 정책 삭제 중..."
    POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
    aws iam delete-policy --policy-arn $POLICY_ARN
fi

echo "=== 3. IAM 정책 생성 ==="
aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://$IAM_POLICY_FILE

echo "=== 4. OIDC 연동 ==="
eksctl utils associate-iam-oidc-provider \
  --region $AWS_REGION \
  --cluster $CLUSTER_NAME \
  --approve

echo "=== 5. 기존 IAM ServiceAccount 삭제 (있으면) ==="
eksctl delete iamserviceaccount \
    --cluster $CLUSTER_NAME \
    --namespace $NAMESPACE \
    --name $SERVICE_ACCOUNT_NAME \
    --region $AWS_REGION \
    || echo "삭제할 ServiceAccount가 없거나 이미 삭제됨"

echo "=== 6. IAM ServiceAccount 생성 ==="
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=$NAMESPACE \
    --name=$SERVICE_ACCOUNT_NAME \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
    --override-existing-serviceaccounts \
    --region $AWS_REGION \
    --approve

echo "=== 7. Helm repo 추가 ==="
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "=== 8. VPC ID 조회 ==="
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID: $VPC_ID"

echo "=== 9. ALB Controller 설치 ==="
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n $NAMESPACE \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

echo "=== 설치 완료 ==="
