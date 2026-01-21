#!/bin/bash
# ======================================================
# Run this script INSIDE your EC2 instance.
# It finds the private IP of the Flink Fargate Task.
# ======================================================

REGION="us-east-1"
CLUSTER="data-platform-dev-cluster"
SERVICE="data-platform-dev-producer-service"

echo "🔍 Searching for running Flink task..."

# 1. Get Task ARN
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region $REGION --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" == "None" ] || [ -z "$TASK_ARN" ]; then
    echo "❌ Error: No running Flink tasks found."
    exit 1
fi

# 2. Get Private IP
IP=$(aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK_ARN --region $REGION --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' --output text)

echo "✅ Found Flink Private IP: $IP"
echo "----------------------------------------"
echo "Trying to connect (curl http://$IP:8081)..."

# 3. Test Connectivity
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" http://$IP:8081 --connect-timeout 2)

if [ "$HTTP_CODE" == "200" ]; then
    echo "🟢 Status: 200 OK - Flink Dashboard is UP!"
else
    echo "🔴 Status: $HTTP_CODE - Something might be wrong."
fi
