<#
.SYNOPSIS
    One-click connection to Flink Web UI via EC2 Runner/Bastion.
    
.DESCRIPTION
    This script automates the tedious process of connecting to a private Flink task:
    1. Sets correct security permissions for the SSH key (like 'chmod 400').
    2. Queries AWS to find the current dynamic IP of the Flink Fargate Task.
    3. Queries AWS to find the public IP of the Runner/Bastion instance.
    4. Establishes the SSH Tunnel.

.EXAMPLE
    .\scripts\connect_flink.ps1
#>

# --- Configuration ---
# Update this path if your key is located elsewhere
$PemPath = "$env:USERPROFILE\Downloads\ingestion_kafka_flink_RSA.pem"

# Infrastructure Details (Matches Terraform variables)
$Region = "us-east-1"
$ClusterName = "data-platform-dev-cluster"
$ServiceName = "data-platform-dev-producer-service"
# Filter to find the EC2 instance (MATCHES CASE SENSITIVE)
$RunnerTag = "*Runner*" 

# Ports
$LocalPort = 8081
$RemotePort = 8081

# -----------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "   Flink Dashboard Connector (PowerShell)" -ForegroundColor Cyan
Write-Host "==============================================`n"

# 1. Check Key File
if (-not (Test-Path $PemPath)) {
    Write-Error "❌ PEM key not found at: $PemPath"
    Write-Host "Please download the key or update `$PemPath in this script."
    exit 1
}

# 2. Set Key Permissions (Windows 'chmod 400')
Write-Host "🔒 [1/4] Securing PEM key permissions..." -NoNewline
try {
    # Remove inheritance and grant Read-only to current user
    icacls $PemPath /inheritance:r | Out-Null
    icacls $PemPath /grant:r "$($env:username):R" | Out-Null
    Write-Host " Done." -ForegroundColor Green
} catch {
    Write-Warning "Could not automatically set permissions. If SSH fails, check file ACLs."
}

# 3. Get Flink Task IP
Write-Host "🔍 [2/4] Fetching Flink Task IP from AWS..."
try {
    $TaskArn = aws ecs list-tasks --cluster $ClusterName --service-name $ServiceName --region $Region --query 'taskArns[0]' --output text
    
    if (-not $TaskArn -or $TaskArn -eq "None") {
        throw "No running tasks found in service $ServiceName"
    }
    
    $FlinkIp = aws ecs describe-tasks --cluster $ClusterName --tasks $TaskArn --region $Region --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' --output text
    Write-Host "    -> Found Flink Private IP: $FlinkIp" -ForegroundColor Green
} catch {
    Write-Error "Failed to fetch Flink IP. Ensure you have AWS CLI installed and configured."
    exit 1
}

# 4. Get Runner/Bastion IP
Write-Host "🔍 [3/4] Fetching Runner/Bastion IP..."
try {
    $RunnerIp = aws ec2 describe-instances --filters "Name=tag:Name,Values=$RunnerTag" --region $Region --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
    
    if (-not $RunnerIp -or $RunnerIp -eq "None") {
        throw "No EC2 instance found with tag Name=$RunnerTag"
    }
    Write-Host "    -> Found Runner Public IP: $RunnerIp" -ForegroundColor Green
} catch {
    Write-Error "Failed to fetch Runner IP."
    exit 1
}

# 5. Connect
Write-Host "`n🚀 [4/4] Establishing Connection..." -ForegroundColor Yellow
Write-Host "--------------------------------------------------------"
Write-Host "   Tunnel: localhost:$LocalPort <--> Runner <--> Flink($FlinkIp)"
Write-Host "   👉 Open in Browser: http://localhost:$LocalPort" -ForegroundColor Magenta
Write-Host "   (Press Ctrl+C to stop)"
Write-Host "--------------------------------------------------------`n"

# Run SSH
# -o StrictHostKeyChecking=no avoids prompt for new/changing IP addresses
ssh -i $PemPath -L "${LocalPort}:${FlinkIp}:${RemotePort}" "ec2-user@${RunnerIp}" -o "StrictHostKeyChecking=no"
