# JennyOma — AWS Load Balancing Lab

## Project Overview

This project demonstrates how to deploy a resilient web application infrastructure on Amazon Web Services (AWS) using Terraform.

The lab uses an Application Load Balancer (ALB) to distribute website requests between two Amazon Elastic Compute Cloud (EC2) instances across two Availability Zones.

It forms part of my preparation for the AWS Certified Solutions Architect – Associate (SAA-C03) certification.

## Architecture

- **AWS Region:** Stockholm (`eu-north-1`)
- **Networking:** Default Virtual Private Cloud (VPC)
- **Compute:** Two Amazon EC2 instances running Amazon Linux 2023
- **Web server:** Nginx, installed automatically using EC2 user data
- **Load balancing:** Application Load Balancer
- **Health checks:** HTTP port 80, path `/`, expected response 200
- **Infrastructure as Code:** Terraform

### Architecture Diagram

```text
                   Internet Users
                          |
                 Application Load
                    Balancer
                          |
                     Target Group
                      /        \
                     /          \
               EC2 Server 1   EC2 Server 2
                  Zone A         Zone B
                  Nginx          Nginx
```

## Security

- The load balancer accepts HTTP requests on port 80.
- EC2 instances accept inbound HTTP traffic only from the load balancer's security group.
- The lab uses public default subnets to avoid the cost of a NAT Gateway.
- For a production system, private application subnets and HTTPS would be preferable.

## Deployment

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

## Testing and Results

The following tests were completed:

1. Deployed two EC2 instances and an Application Load Balancer using Terraform.
2. Confirmed the website was accessible through the ALB URL.
3. Verified that both EC2 targets showed **Healthy**.
4. Manually deregistered one EC2 target.
5. Verified that the website remained accessible using the remaining registered target.

This demonstrated the ALB's ability to continue serving requests after one target is removed.

**Limitation:** This was a manual target deregistration test, not an automatic server-failure detection or Auto Scaling recovery test.

## Key Learning Outcomes

- Building repeatable AWS infrastructure with Terraform
- Configuring ALB target groups and health checks
- Applying security group rules
- Deploying web servers across multiple Availability Zones
- Understanding infrastructure configuration drift
- Testing load-balancer behaviour during target removal

## Cleanup

Temporary infrastructure can be removed with:

```bash
terraform destroy
```

## Future Improvements

- Add Amazon EC2 Auto Scaling
- Test automatic instance replacement
- Add Amazon CloudWatch monitoring
- Use private application subnets and HTTPS
