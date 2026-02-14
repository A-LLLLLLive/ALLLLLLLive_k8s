#!/bin/bash
set -e

### ===== 설정값 =====
CLUSTER_NAME="alive-cluster"
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"

# 정책 다운로드
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json

# IAM 정책 생성
aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://iam_policy.json || echo "정책이 이미 존재할 수 있음, 계속 진행"

# # OIDC 연결
# eksctl utils associate-iam-oidc-provider \
#   --region $AWS_REGION \
#   --cluster $CLUSTER_NAME \
#   --approve

# # 기존 IAM ServiceAccount 삭제
# eksctl delete iamserviceaccount \
#   --cluster $CLUSTER_NAME \
#   --namespace $NAMESPACE \
#   --name $SERVICE_ACCOUNT_NAME \
#   --region $AWS_REGION

# IAM ServiceAccount 생성
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=$NAMESPACE \
    --name=$SERVICE_ACCOUNT_NAME \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
    --override-existing-serviceaccounts \
    --region $AWS_REGION \
    --approve

# Helm repo 추가 및 업데이트
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# VPC ID 조회
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text)

# ALB Controller 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n $NAMESPACE \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

echo "ALB Controller 설치 완료 ✅"
