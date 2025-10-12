# EC2 Infrastructure with Terraform

This Terraform configuration creates a simple EC2 infrastructure on AWS with a new VPC, including:

- VPC with public subnet
- Internet Gateway
- Route tables and associations
- Security Group (SSH, HTTP, HTTPS, Flask port 5000)
- EC2 instance (Amazon Linux 2023)
- Elastic IP for persistent public IP

## Prerequisites

1. **Terraform**: Install Terraform (>= 1.0)
   ```bash
   brew install terraform  # macOS
   ```

2. **AWS CLI**: Configure AWS credentials
   ```bash
   aws configure
   ```

3. **SSH Key Pair**: Create an SSH key pair in AWS
   - Go to EC2 Console → Key Pairs → Create Key Pair
   - Save the `.pem` file securely
   - Note the key pair name for use in `terraform.tfvars`

## Project Structure

```
infra/
├── provider.tf          # Terraform and AWS provider configuration
├── vpc.tf              # VPC and networking resources
├── security_group.tf   # Security group rules
├── ec2.tf              # EC2 instance and EIP
├── variables.tf        # Variable definitions
├── outputs.tf          # Output definitions
├── terraform.tfvars    # Your variable values (create this)
└── README.md           # This file
```

## Setup Instructions

### Step 1: Create `terraform.tfvars`

Create a file named `terraform.tfvars` with your configuration:

```hcl
# Required
key_name = "your-key-pair-name"  # Name of your AWS key pair

# Optional (defaults are provided)
aws_region         = "us-east-1"
project_name       = "flask-app"
environment        = "dev"
instance_type      = "t2.micro"
vpc_cidr          = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
root_volume_size   = 20
allowed_ssh_cidr   = ["0.0.0.0/0"]  # Restrict this to your IP for security
```

### Step 2: Initialize Terraform

```bash
cd infra
terraform init
```

### Step 3: Plan the Infrastructure

```bash
terraform plan
```

Review the resources that will be created.

### Step 4: Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### Step 5: Get the Outputs

After successful deployment:

```bash
terraform output
```

You'll see:
- `ec2_public_ip`: Public IP address of your instance
- `ssh_command`: Command to SSH into the instance
- Other resource IDs

## Accessing the EC2 Instance

### SSH Access

```bash
ssh -i ~/.ssh/your-key-pair-name.pem ec2-user@<public-ip>
```

Or use the output command:
```bash
terraform output ssh_command
```

### What's Installed

The EC2 instance comes pre-configured with:
- Docker and Docker Compose
- Git
- Python 3 and pip

## Security Group Rules

The security group allows:
- **SSH (22)**: From IPs specified in `allowed_ssh_cidr`
- **HTTP (80)**: From anywhere
- **HTTPS (443)**: From anywhere
- **Flask (5000)**: From anywhere (for the Flask app)
- **All Outbound**: Allowed

## Deploying the Flask App

Once connected to the instance:

```bash
# Clone your repository or copy files
git clone <your-repo-url>

# Navigate to app directory
cd <repo-name>/app

# Build and run with Docker
docker build -t flask-calculator .
docker run -d -p 5000:5000 --name flask-app flask-calculator

# Or run directly with Python
pip install -r requirements.txt
python app.py
```

Access the app at: `http://<public-ip>:5000`

## Managing Infrastructure

### View Current State
```bash
terraform show
```

### Update Infrastructure
Modify `.tf` files or `terraform.tfvars`, then:
```bash
terraform plan
terraform apply
```

### Destroy Infrastructure
⚠️ This will delete all resources:
```bash
terraform destroy
```

## Cost Considerations

- **t2.micro**: ~$8-10/month (eligible for AWS Free Tier)
- **EIP**: Free when attached to running instance
- **EBS Volume**: ~$2/month for 20GB gp3
- **Data Transfer**: Varies based on usage

## Customization

### Change Instance Type
Edit `terraform.tfvars`:
```hcl
instance_type = "t3.small"
```

### Restrict SSH Access
Edit `terraform.tfvars` to allow only your IP:
```hcl
allowed_ssh_cidr = ["YOUR_IP/32"]
```

### Different Region
Edit `terraform.tfvars`:
```hcl
aws_region = "us-west-2"
```

## Troubleshooting

### SSH Connection Issues
1. Check security group allows your IP
2. Verify key permissions: `chmod 400 ~/.ssh/your-key.pem`
3. Ensure using correct username: `ec2-user` for Amazon Linux

### Instance Not Accessible
1. Check instance state: `terraform show | grep instance_state`
2. Verify EIP is attached: `terraform output ec2_public_ip`
3. Check AWS Console for any issues

### Terraform Errors
1. Verify AWS credentials: `aws sts get-caller-identity`
2. Check region availability of resources
3. Ensure key pair exists in the correct region

## Security Best Practices

1. **Restrict SSH Access**: Don't use `0.0.0.0/0` for SSH in production
2. **Use IAM Roles**: Attach IAM roles instead of embedding credentials
3. **Enable Encryption**: Root volume is encrypted by default
4. **Regular Updates**: Keep the AMI and packages updated
5. **Backup Strategy**: Use EBS snapshots for important data

## Terraform State

- State is stored locally in `terraform.tfstate`
- For team collaboration, consider using remote state (S3 + DynamoDB)
- Never commit `terraform.tfstate` to version control
- Add to `.gitignore`:
  ```
  *.tfstate
  *.tfstate.backup
  .terraform/
  terraform.tfvars
  ```

## Next Steps

1. Set up monitoring with CloudWatch
2. Configure automatic backups
3. Implement CI/CD pipeline
4. Add Auto Scaling Group for high availability
5. Set up Application Load Balancer
6. Configure custom domain with Route 53
7. Add SSL certificate with ACM

## Support

For Terraform issues, refer to:
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
