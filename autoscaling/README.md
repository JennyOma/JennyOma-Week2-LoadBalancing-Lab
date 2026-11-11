# JennyOma — AWS Auto Scaling and Self-Healing Lab

## Project Overview

This lab extends my AWS load-balancing project by introducing Amazon EC2 Auto Scaling using Terraform.

The objective was to demonstrate how AWS can automatically replace a failed EC2 instance while maintaining application capacity across two Availability Zones.

## Architecture

- **Region:** Stockholm (`eu-north-1`)
- **Networking:** Existing default VPC
- **Compute:** Amazon EC2 with Amazon Linux 2023
- **Launch Template:** Defines instance configuration and Nginx startup automation
- **Auto Scaling Group:** Minimum 2, desired 2, maximum 4
- **Application Load Balancer:** Distributes HTTP requests
- **Health checks:** HTTP port 80, path `/`
- **Scaling policy:** Target tracking at 50% average CPU utilisation
- **Infrastructure as Code:** Terraform

## Testing and Results

I successfully:

1. Deployed the infrastructure using Terraform.
2. Verified that the Auto Scaling Group reached its desired capacity of two instances.
3. Confirmed that both EC2 instances were InService and Healthy.
4. Deliberately terminated one instance.
5. Observed Auto Scaling launch a replacement instance.
6. Confirmed that the group returned to two healthy instances.
7. Destroyed the infrastructure using Terraform.

**Result:** The Auto Scaling Group demonstrated automatic instance replacement and capacity recovery.

**Limitation:** CPU-triggered scale-out from two to three or four instances was configured but not tested.

## Key Learning Outcomes

- Launch Templates versus manually defined EC2 instances
- Minimum, desired and maximum Auto Scaling capacity
- Automatic instance replacement
- Load-balancer health checks
- Target tracking scaling policies
- Cost-conscious infrastructure cleanup

## Deployment

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

## Cleanup

```bash
terraform destroy
```

## Future Improvements

- Test scaling under increased CPU utilisation
- Add CloudWatch monitoring and alarms
- Use private application subnets and HTTPS for a production-oriented design
