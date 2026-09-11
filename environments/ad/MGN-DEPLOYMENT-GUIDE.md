# MGN Replication Baseline - Implementation Guide

This guide walks through deploying the MGN replication baseline for your on-premises to AWS migration.

## Quick Start

### 1. Review Current Infrastructure

First, understand your existing setup:

```bash
cd environments/ad/
terraform output
```

Key outputs needed:
- VPC ID
- Private subnet IDs
- AD domain controller details

### 2. Create terraform.tfvars

Create `environments/ad/terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "us-east-1"

# MGN Configuration
environment_name = "ad"

# Subnet Configuration
mgn_staging_az = "us-east-1a"
mgn_staging_subnet_cidr = "10.0.100.0/24"

# Network Configuration
# IMPORTANT: Update these with your actual on-prem and target VPC CIDRs
mgn_source_vpc_cidr_blocks = ["10.0.0.0/8"]        # On-prem network

# Cross-Account Configuration (update after other accounts are ready)
mgn_cross_account_role_arns = []
# Example when configured:
# mgn_cross_account_role_arns = [
#   "arn:aws:iam::123456789012:role/mgn-replication-role",
#   "arn:aws:iam::987654321098:role/mgn-replication-role"
# ]

# Encryption
enable_mgn_ebs_encryption = true
mgn_kms_key_arn = null  # Uses AWS managed key if not specified

# Direct Connect (configure after VIF is ready)
enable_mgn_direct_connect_path = false
# mgn_direct_connect_vif_id = "vif-12345678"

# Tags
common_tags = {
  Project     = "AWS-VM-Migration"
  CostCenter  = "Cloud-Ops"
  Owner       = "DevOps-Team"
}
```

### 3. Plan and Deploy

```bash
# Validate Terraform files
terraform validate

# Plan deployment
terraform plan -out=mgn.tfplan

# Review the plan carefully, then apply
terraform apply mgn.tfplan
```

### 4. Retrieve Deployment Details

```bash
# Get staging subnet
STAGING_SUBNET=$(terraform output -raw mgn_staging_subnet_id)
echo "Staging Subnet: $STAGING_SUBNET"

# Get security group IDs
STAGING_SG=$(terraform output -raw mgn_staging_security_group_id)
AGENT_SG=$(terraform output -raw mgn_agent_security_group_id)
echo "Staging SG: $STAGING_SG"
echo "Agent SG: $AGENT_SG"

# Get IAM role info
SERVICE_ROLE=$(terraform output -raw mgn_service_role_arn)
AGENT_PROFILE=$(terraform output -raw mgn_agent_instance_profile_name)
echo "Service Role: $SERVICE_ROLE"
echo "Agent Instance Profile: $AGENT_PROFILE"

# Get replication settings
SETTINGS=$(terraform output -raw mgn_replication_settings_parameter_name)
echo "Replication Settings Parameter: $SETTINGS"

# Retrieve settings
aws ssm get-parameter --name "$SETTINGS" --query 'Parameter.Value' --output text | jq .
```

## Step 1: Initialize MGN in AWS Console

1. Go to [AWS MGN Console](https://console.aws.amazon.com/mgn/)
2. Click **Get started** (if first time)
3. Choose your region
4. MGN will be initialized automatically

## Step 2: Create Replication Configuration Template

1. In MGN Console, go to **Settings** > **Replication Configuration Template**
2. Click **Create replication configuration template**
3. Fill in the following from your Terraform outputs:

```
Replication servers subnet: [staging_subnet_id from Terraform]
Replication servers security group IDs: [mgn_staging_security_group_id]
Default large staging disk type: gp3
EBS encryption: DEFAULT (enabled)
Replication server instance type: t3.small
Data plane routing: PRIVATE_IP
```

Or use the template from SSM:

```bash
# Get template from SSM Parameter Store
SETTINGS_PARAM=$(terraform output -raw mgn_replication_settings_parameter_name)
aws ssm get-parameter --name "$SETTINGS_PARAM" --query 'Parameter.Value' --output text
```

## Step 3: Set Up Replication Agents

### For Windows Source Servers

1. Download the MGN agent installer:
   ```bash
   # From AWS Console: Tools > Download replication agent installer
   # Or via AWS CLI:
   aws mgn get-replication-configuration
   ```

2. Install agent on source server:
   ```powershell
   # As Administrator
   .\aws-mgn-installer.exe
   # Follow the wizard
   ```

3. Verify agent is running:
   ```powershell
   Get-Service -Name 'AWS Application Migration Service Agent'
   ```

### For Linux Source Servers

```bash
# Download installer
wget https://aws-application-migration-service.region.amazonaws.com/latest/linux/aws-mgn-installer-linux.sh

# Install
sudo chmod +x aws-mgn-installer-linux.sh
sudo ./aws-mgn-installer-linux.sh

# Verify
systemctl status aws-mgn-agent
```

## Step 4: Register Source Servers

After agents are installed, servers should appear in the MGN Console:

1. Go to **Servers** in MGN Console
2. Verify all source servers are listed
3. Check the **Replication Status** for each server
4. Monitor in CloudWatch logs:
   ```bash
   aws logs tail /aws/mgn/ad/agents --follow
   ```

## Step 5: Monitor Replication

### CloudWatch Dashboard

Create a dashboard to monitor replication:

```bash
# View replication metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/MGN \
  --metric-name "ReplicationProgress" \
  --dimensions Name=SourceServerId,Value=srv-12345678 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average
```

### Verify Direct Connect Path (if configured)

```bash
# Check route table entries
aws ec2 describe-route-tables --route-table-ids $(terraform output -raw route_table_id)

# Verify traffic via Direct Connect
mtr -c 10 -r mgn-endpoint.us-east-1.amazonaws.com
```

## Step 6: Set Up Cross-Account Replication (Optional)

If replicating from another AWS account:

### In MGN Account (This Account)

1. Get the cross-account role ARN:
   ```bash
   terraform output mgn_cross_account_role_arn
   ```

2. Share this ARN with the source account team

### In Source Account

1. Create a role that can assume the cross-account role:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "sts:AssumeRole",
         "Resource": "[cross-account-role-arn-from-MGN-account]",
         "Condition": {
           "StringEquals": {
             "sts:ExternalId": "mgn-ad-[MGN-account-id]"
           }
         }
       }
     ]
   }
   ```

2. Update MGN configuration in source account to use this role

## Acceptance Criteria Validation

### ✅ Replication settings template exists

```bash
# Verify template in SSM
SETTINGS_PARAM=$(terraform output -raw mgn_replication_settings_parameter_name)
aws ssm get-parameter --name "$SETTINGS_PARAM"
```

### ✅ Staging area subnet provisioned

```bash
# Verify subnet
SUBNET_ID=$(terraform output -raw mgn_staging_subnet_id)
aws ec2 describe-subnets --subnet-ids $SUBNET_ID
```

### ✅ IAM roles follow least privilege

```bash
# Review service role policy
aws iam get-role-policy \
  --role-name $(terraform output -raw mgn_service_role_name) \
  --policy-name ad-mgn-service-policy
```

### ✅ Replication traffic over Direct Connect

```bash
# If Direct Connect configured, verify route
RT_ID=$(terraform output -raw route_table_id)
aws ec2 describe-route-tables --route-table-ids $RT_ID
```

### ✅ EBS encryption enabled

```bash
# Verify default encryption
aws ec2 get-ebs-encryption-by-default
```

## Troubleshooting

### Agents Not Appearing in Console

1. Check agent installation:
   ```powershell
   # Windows
   Get-Service | grep -i mgn
   
   # View logs
   Get-EventLog -LogName "AWS MGN Agent" -Newest 20
   ```

2. Verify security group allows outbound HTTPS:
   ```bash
   AGENT_SG=$(terraform output -raw mgn_agent_security_group_id)
   aws ec2 describe-security-groups --group-ids $AGENT_SG
   ```

3. Test connectivity:
   ```bash
   # Should succeed
   curl -v https://mgn.us-east-1.amazonaws.com/
   ```

### Replication Stuck or Slow

1. Check CloudWatch logs:
   ```bash
   aws logs tail /aws/mgn/ad/replication --follow
   ```

2. Verify network connectivity:
   ```bash
   # Check Direct Connect if configured
   traceroute mgn-endpoint.amazonaws.com
   
   # Check packet loss
   ping -c 100 10.0.100.1  # Staging subnet gateway
   ```

3. Check EBS encryption:
   ```bash
   # Verify KMS permissions
   aws iam get-role-policy --role-name $(terraform output -raw mgn_service_role_name) --policy-name ad-mgn-service-policy
   ```

### Cross-Account Role Issues

```bash
# Verify role trust policy
aws iam get-role --role-name ad-mgn-cross-account-role

# Check if other account can assume
aws sts assume-role \
  --role-arn "arn:aws:iam::ACCOUNT:role/ad-mgn-cross-account-role" \
  --role-session-name test \
  --external-id "mgn-ad-ACCOUNT"
```

## Next Steps

1. **Install MGN agent** on first batch of source servers
2. **Monitor replication** for 24-48 hours to ensure stability
3. **Test failover** with non-critical server
4. **Document** replication runbook
5. **Plan** cutover timeline with business stakeholders
6. **Set up** monitoring and alerting for production

## Support Resources

- [AWS MGN Documentation](https://docs.aws.amazon.com/mgn/)
- [AWS MGN Troubleshooting Guide](https://docs.aws.amazon.com/mgn/latest/ug/troubleshooting.html)
- [AWS Support Portal](https://console.aws.amazon.com/support)

## Checklist

- [ ] Terraform files deployed successfully
- [ ] MGN initialized in AWS Console
- [ ] Replication configuration template created
- [ ] First batch of agents installed
- [ ] Servers appear in MGN Console
- [ ] Replication showing progress
- [ ] CloudWatch logs monitoring in place
- [ ] Direct Connect path verified (if applicable)
- [ ] Cross-account connectors configured (if applicable)
- [ ] EBS encryption validated
- [ ] Security groups reviewed
- [ ] Runbook documented
