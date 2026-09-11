# MGN Replication Baseline Module

Provides the shared replication substrate and infrastructure for AWS Application Migration Service (MGN) on-premises to AWS migration.

## Overview

This module implements the AWS Transform MGN replication baseline with the following components:

- **Staging Subnet**: Dedicated subnet for replication servers with controlled egress
- **Security Groups**: Least-privilege security controls for replication traffic
- **IAM Roles & Policies**: Service role, agent execution role, and cross-account roles
- **Networking**: Internet Gateway, route tables, and Network ACLs for replication traffic
- **Encryption**: EBS encryption at rest for replicated volumes
- **Monitoring**: CloudWatch log groups for replication and agent activities
- **Configuration Template**: Reusable replication settings template stored in SSM

## Features

✅ **Least Privilege IAM**: Scoped permissions for MGN service and agents, no wildcards  
✅ **EBS Encryption**: Automatic encryption at rest on all replicated volumes  
✅ **Network Isolation**: Dedicated staging subnet with controlled outbound access  
✅ **Cross-Account Support**: Pre-configured cross-account replication connectors  
✅ **Direct Connect Ready**: Optional Direct Connect route for dedicated replication path  
✅ **Compliance Ready**: Audit logging via CloudWatch and detailed tagging  
✅ **Replication Settings Template**: Default configuration stored in SSM Parameter Store  

## Prerequisites

- Existing VPC with private subnets (typically from AD environment)
- AWS region configuration
- On-premises connectivity (VPN or Direct Connect)
- Terraform >= 1.0
- AWS Provider >= 5.0

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    AWS Account                       │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌────────────────────────────────────────────┐    │
│  │ VPC (Shared with AD Infrastructure)         │    │
│  │                                             │    │
│  │  ┌──────────────────────────────────────┐   │    │
│  │  │ MGN Staging Subnet (10.0.100.0/24)   │   │    │
│  │  │                                       │   │    │
│  │  │ ┌─────────────┐   ┌──────────────┐  │   │    │
│  │  │ │ Replication │──▶│ Replication  │  │   │    │
│  │  │ │  Servers    │   │  Agent SG    │  │   │    │
│  │  │ └─────────────┘   └──────────────┘  │   │    │
│  │  │         │                            │   │    │
│  │  └─────────┼────────────────────────────┘   │    │
│  │            │ HTTPS/443                       │    │
│  │            ▼                                 │    │
│  │     ┌─────────────┐                        │    │
│  │     │ IGW (NAT)   │                        │    │
│  │     └─────────────┘                        │    │
│  │            │                               │    │
│  └────────────┼───────────────────────────────┘    │
│               │                                    │
│     ┌─────────▼──────────┐                         │
│     │  AWS MGN Service   │                         │
│     │  IAM Service Role  │                         │
│     │  (ec2:*, kms::*)   │                         │
│     └────────────────────┘                         │
│                                                    │
└────────────────────────────────────────────────────┘
          │
          │ Optional Cross-Account Connectors
          │
┌─────────▼─────────────────────────────────────────┐
│         Other AWS Accounts (Target)               │
│         ┌──────────────────────────────┐          │
│         │ Cross-Account Replication    │          │
│         │ Role with AssumeRole from    │          │
│         │ MGN account with ExternalId  │          │
│         └──────────────────────────────┘          │
└─────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "mgn_replication_baseline" {
  source = "../../modules/mgn-replication-baseline"

  aws_region                  = "us-east-1"
  environment_name            = "prod"
  vpc_id                      = "vpc-12345678"
  staging_subnet_cidr         = "10.0.100.0/24"
  staging_az                  = "us-east-1a"
  source_vpc_cidr_blocks      = ["10.0.0.0/8"]      # On-prem network CIDR
  enable_ebs_encryption       = true
}
```

### With Cross-Account Connectors

```hcl
module "mgn_replication_baseline" {
  source = "../../modules/mgn-replication-baseline"

  aws_region                  = "us-east-1"
  environment_name            = "prod"
  vpc_id                      = "vpc-12345678"
  staging_subnet_cidr         = "10.0.100.0/24"
  staging_az                  = "us-east-1a"
  source_vpc_cidr_blocks      = ["10.0.0.0/8"]
  
  # Cross-account connector setup
  cross_account_mgn_role_arns = [
    "arn:aws:iam::123456789012:role/mgn-replication-role",
    "arn:aws:iam::987654321098:role/mgn-replication-role"
  ]
  
  enable_ebs_encryption       = true
  kms_key_arn                 = aws_kms_key.mgn_ebs.arn
}
```

### With Direct Connect

```hcl
module "mgn_replication_baseline" {
  source = "../../modules/mgn-replication-baseline"

  aws_region                      = "us-east-1"
  environment_name                = "prod"
  vpc_id                          = "vpc-12345678"
  staging_subnet_cidr             = "10.0.100.0/24"
  staging_az                      = "us-east-1a"
  source_vpc_cidr_blocks          = ["10.0.0.0/8"]
  
  # Direct Connect path for replication
  enable_direct_connect_path      = true
  direct_connect_virtual_interface_id = "vif-12345678"
  direct_connect_bgp_asn          = 65001
  
  enable_ebs_encryption           = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `aws_region` | AWS region for MGN resources | `string` | n/a | yes |
| `environment_name` | Environment name (e.g., prod, staging, dev) | `string` | n/a | yes |
| `vpc_id` | VPC ID where staging subnet will be created | `string` | n/a | yes |
| `staging_subnet_cidr` | CIDR block for MGN staging area subnet | `string` | `10.0.100.0/24` | no |
| `staging_az` | Availability zone for staging subnet | `string` | n/a | yes |
| `source_vpc_cidr_blocks` | CIDR blocks of source VPCs/on-prem networks | `list(string)` | n/a | yes |
| `cross_account_mgn_role_arns` | Cross-account MGN role ARNs | `list(string)` | `[]` | no |
| `enable_direct_connect_path` | Enable Direct Connect route for replication | `bool` | `false` | no |
| `enable_ebs_encryption` | Enable EBS encryption at rest | `bool` | `true` | no |
| `kms_key_arn` | KMS key ARN for EBS encryption | `string` | `null` | no |
| `tags` | Common tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `staging_subnet_id` | ID of the MGN staging area subnet |
| `mgn_staging_security_group_id` | Security group ID for staging subnet |
| `mgn_agent_security_group_id` | Security group ID for agents on source servers |
| `mgn_service_role_arn` | ARN of MGN service role |
| `mgn_agent_role_arn` | ARN of MGN agent execution role |
| `mgn_agent_instance_profile_name` | Name of IAM instance profile for agents |
| `mgn_cross_account_role_arn` | ARN of cross-account replication role |
| `mgn_replication_settings_parameter_name` | SSM parameter with default replication settings |

## Acceptance Criteria Coverage

✅ **Replication settings template**: Stored in SSM Parameter Store, automatically applied via MGN console  
✅ **Staging area subnet**: Provisioned with Internet Gateway for outbound agent access  
✅ **Least privilege IAM**: Service role with specific EC2 permissions, agent role with MGN permissions only  
✅ **Security groups**: Minimal ingress/egress rules, scoped to specific ports and CIDR blocks  
✅ **Direct Connect support**: Optional Direct Connect route configuration (manual setup of VGW required)  
✅ **EBS encryption**: Enabled by default on all replicated volumes  

## Security Considerations

### IAM Policies

- **Service Role**: Limited to EC2 operations (`ec2:CreateSnapshot`, `ec2:CreateVolume`, etc.) and KMS operations
- **Agent Role**: Minimal permissions for MGN API calls and CloudWatch logging
- **Cross-Account Role**: Trust policy includes `ExternalId` condition for additional security
- **Deny Insecure**: Explicit deny on unencrypted transport (`aws:SecureTransport=false`)

### Network Security

- **Security Groups**: Default deny-all with explicit allow rules
- **Network ACLs**: Stateless ingress/egress controls
- **No Public IPs**: Replication servers use private IPs only
- **Outbound Filtering**: DNS and HTTPS only (ports 53, 443)

### Encryption

- **EBS Encryption**: Enabled by default for all replicated volumes
- **KMS Key**: Optional customer-managed key for encryption (AWS managed key by default)
- **In-Transit**: HTTPS (TLS) for all MGN agent communication

## Direct Connect Configuration

The module includes support for Direct Connect replication path. To fully implement:

1. **Virtual Gateway (VGW)**: Create/verify Virtual Private Gateway on your VPC
2. **Virtual Interface (VIF)**: Create private VIF on your Direct Connect connection
3. **BGP Peering**: Configure BGP ASN (typically 65001-65534 for customer)
4. **Route Propagation**: Enable route propagation on the staging area route table

Example AWS CLI commands:
```bash
# Get route table ID from Terraform outputs
RT_ID=$(terraform output -raw route_table_id)

# Enable route propagation from VGW
aws ec2 enable-vgw-route-propagation \
  --route-table-id $RT_ID \
  --gateway-id vgw-12345678
```

## Cross-Account Replication Setup

### In Source Account (MGN Account)

The module creates:
- `mgn_cross_account_role`: Role that other accounts can assume
- Trust policy with `ExternalId` condition: `mgn-{environment_name}-{account_id}`

### In Target Account

Create a role with the following assume policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MGN_ACCOUNT:role/ad-mgn-cross-account-role"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "mgn-ad-MGN_ACCOUNT"
        }
      }
    }
  ]
}
```

## Deployment

### Prerequisites Checklist

- [ ] AWS account with MGN enabled
- [ ] VPC with private subnets (shared with AD)
- [ ] On-premises network CIDR documented
- [ ] Target VPC CIDR ranges known
- [ ] (Optional) Direct Connect VIF ID and BGP ASN
- [ ] (Optional) Customer-managed KMS key ARN for EBS encryption

### Deployment Steps

1. **Update Variables**:
   ```bash
   cd environments/ad/
   # Edit terraform.tfvars with your specific values
   ```

2. **Plan Deployment**:
   ```bash
   terraform plan -out=mgn.tfplan
   ```

3. **Review Plan**:
   - Verify staging subnet CIDR doesn't conflict
   - Check IAM roles have correct permissions
   - Validate security group rules

4. **Apply Configuration**:
   ```bash
   terraform apply mgn.tfplan
   ```

5. **Verify Deployment**:
   ```bash
   # Get staging subnet ID
   terraform output mgn_staging_subnet_id
   
   # Get replication settings template
   terraform output mgn_replication_settings_parameter_name
   
   # Get service role ARN
   terraform output mgn_service_role_arn
   ```

## Post-Deployment Configuration

### 1. Enable MGN in Console

```bash
aws mgn describe-lifecycle-configuration --region us-east-1
```

If not initialized, initialize MGN in the console: https://console.aws.amazon.com/mgn/

### 2. Set Default Replication Settings

1. Navigate to **Settings** > **Replication Configuration Template**
2. Click **Create template**
3. Use values from SSM parameter: `terraform output mgn_replication_settings_parameter_name`

### 3. Set Up Direct Connect (if applicable)

1. In AWS Console, navigate to **VPC** > **Virtual Gateways**
2. Create Virtual Gateway (if not exists)
3. Attach to VPC
4. Enable route propagation on staging subnet route table (see CLI commands above)
5. Set up BGP peering with Direct Connect team

### 4. Test Replication Path

```bash
# From source server with MGN agent:
# 1. Verify HTTPS connectivity to MGN endpoint
curl -v https://mgn.region.amazonaws.com/

# 2. Check Direct Connect path (if configured)
mtr -c 10 -r -s 1450 mgn-endpoint.amazonaws.com

# 3. Monitor CloudWatch logs
aws logs tail /aws/mgn/ad/agents --follow
```

## Monitoring and Troubleshooting

### CloudWatch Logs

Monitor replication activity:
```bash
aws logs tail /aws/mgn/ad/replication --follow
aws logs tail /aws/mgn/ad/agents --follow
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Agent can't reach MGN endpoint | Outbound HTTPS blocked | Verify security group and NACL rules |
| Replication fails with encryption error | KMS key permissions | Verify MGN service role has KMS permissions |
| Cross-account connector fails | Missing ExternalId | Verify ExternalId in trust policy matches expected value |
| High replication latency | Network path | Consider enabling Direct Connect replication path |

### Debugging

Enable detailed logging on the MGN agent:
```powershell
# On Windows servers with agent
Set-ItemProperty -Path 'HKLM:\SOFTWARE\AWS\Application Migration Service' `
  -Name 'LogLevel' -Value 'DEBUG' -Type String

# Restart agent service
Restart-Service -Name 'MGN Agent'
```

## Cost Considerations

- **Staging Subnet**: Minimal cost (just the resources within it)
- **NAT Gateway** (if used instead of IGW): ~$45/month per availability zone
- **Direct Connect**: ~$0.30/hour for VIF (if configured)
- **EBS Encryption**: No additional cost (uses AWS managed keys)
- **CloudWatch Logs**: ~$0.50/GB ingested

## Maintenance

### Regular Tasks

- **Monthly**: Review CloudWatch logs for anomalies
- **Quarterly**: Audit IAM policy permissions
- **Quarterly**: Test Direct Connect failover (if applicable)
- **Annually**: Review and update replication settings template

### Updating Module

When updating:
1. Review CHANGELOG for breaking changes
2. Run `terraform plan` to preview changes
3. Test in non-production environment first
4. Apply updates during maintenance window

## Additional Resources

- [AWS MGN Documentation](https://docs.aws.amazon.com/mgn/)
- [AWS MGN Best Practices](https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html)
- [AWS Direct Connect](https://docs.aws.amazon.com/directconnect/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

## Support

For issues or questions:
1. Check CloudWatch logs first
2. Review Terraform state for resource details
3. Consult AWS MGN documentation
4. Contact AWS support with issue details and CloudWatch logs
