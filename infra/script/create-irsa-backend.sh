#!/bin/bash
set -euo pipefail

### ===== 설정값 =====
CLUSTER_NAME="alive-cluster"
AWS_REGION="ap-northeast-2"

NAMESPACE="backend"
SERVICE_ACCOUNT_NAME="backend-irsa-sa"

ROLE_NAME="alive-backend-irsa-role"
POLICY_NAME="alive-backend-secrets-policy"
### ==================

echo "▶ IRSA 생성 시작"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. OIDC Issuer 조회
OIDC_ISSUER=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text)

OIDC_ISSUER_STRIPPED=$(echo $OIDC_ISSUER | sed 's#https://##')

echo "✔ OIDC Provider 확인 완료: $OIDC_ISSUER_STRIPPED"

# 2. IAM Policy 생성 (이미 있으면 재사용)
POLICY_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" \
  --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "▶ IAM Policy 생성"
  POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ],
          "Resource": "*"
        }
      ]
    }' \
    --query "Policy.Arn" \
    --output text)
else
  echo "✔ IAM Policy 이미 존재"
fi

# 3. Trust Policy 생성
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_ISSUER_STRIPPED"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_ISSUER_STRIPPED:sub": "system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT_NAME"
        }
      }
    }
  ]
}
EOF

# 4. IAM Role 생성 (이미 있으면 스킵)
ROLE_ARN=$(aws iam get-role \
  --role-name $ROLE_NAME \
  --query "Role.Arn" \
  --output text 2>/dev/null || true)

if [ -z "$ROLE_ARN" ]; then
  echo "▶ IAM Role 생성"
  ROLE_ARN=$(aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --query "Role.Arn" \
    --output text)
else
  echo "✔ IAM Role 이미 존재"
fi

# 5. Policy Attach
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN || true

# 6. Namespace 생성 (없으면)
kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE

# 7. ServiceAccount 생성
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
  annotations:
    eks.amazonaws.com/role-arn: $ROLE_ARN
EOF

echo "✅ IRSA 생성 완료"
echo "   - Namespace: $NAMESPACE"
echo "   - ServiceAccount: $SERVICE_ACCOUNT_NAME"
echo "   - IAM Role: $ROLE_NAME"
