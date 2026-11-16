# JennyOma — AWS Storage and Disaster Recovery Lab

## Project Overview

This project demonstrates encrypted block storage, point-in-time backups, cross-Availability Zone data recovery and custom Amazon Machine Image creation using AWS and Terraform.

The objective was to validate that application data could be successfully recovered in another Availability Zone using an EBS snapshot.

## Architecture

- AWS Region: Stockholm (eu-north-1)
- Source Availability Zone: eu-north-1a
- Recovery Availability Zone: eu-north-1b
- Compute: Amazon EC2 — t3.micro
- Operating system: Amazon Linux 2023
- Storage: Encrypted Amazon EBS gp3 volumes
- Backup: Amazon EBS snapshots
- Machine image: Custom AMI
- Infrastructure as Code: Terraform

## Recovery Workflow

1. Deploy a source EC2 instance.
2. Create and attach an encrypted EBS data volume.
3. Initialise the filesystem and write fictional test data using EC2 user data.
4. Create a point-in-time EBS snapshot.
5. Restore the snapshot into a new EBS volume in another Availability Zone.
6. Attach the restored volume to a recovery EC2 instance.
7. Mount the restored filesystem in read-only mode.
8. Verify the recovered file contents.
9. Create a custom AMI from the source instance.

## Testing and Results

The recovery instance successfully retrieved the original test data and produced the following confirmation:

`CROSS-AZ DATA RECOVERY SUCCESSFUL`

This demonstrated successful cross-Availability Zone data restoration using an EBS snapshot.

A custom AMI was also created, with two associated EBS snapshots.

### Testing limitations

- An actual Availability Zone outage was not simulated.
- Recovery was initiated manually through Terraform rather than through automated disaster recovery orchestration.
- The custom AMI was created but was not used to launch another instance.

## Security Controls

- Encrypted root and additional EBS volumes.
- No public IP addresses.
- No inbound security group permissions.
- IMDSv2 required for EC2 instance metadata access.
- Fictional test data only.
- Read-only mounting of recovered storage during verification.

## Key Learning Outcomes

- Understanding the Availability Zone restrictions of EBS volumes.
- Creating and restoring regional EBS snapshots.
- Distinguishing compute recovery from data recovery.
- Understanding custom AMIs and their associated snapshots.
- Validating recovered data rather than assuming backup success.
- Managing infrastructure securely through Terraform.
- Independently verifying resource cleanup.

## Deployment

The lab was deployed incrementally using:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

The source data was verified before snapshot creation, and the restored data was verified before AMI creation.

## Cleanup and Cost Management

All nine Terraform-managed resources were successfully destroyed.

Independent AWS CLI checks confirmed no remaining EBS volumes, owned snapshots or custom AMIs in the Stockholm Region.

The Terraform state was also verified as empty.

## Future Improvements

- Automate backup scheduling using AWS Backup.
- Measure Recovery Time Objective (RTO).
- Evaluate Recovery Point Objective (RPO).
- Test launching an EC2 instance from the custom AMI.
- Implement automated disaster recovery procedures.

## Certification Alignment

AWS Certified Solutions Architect Associate (SAA-C03):

- Designing resilient architectures
- Designing secure architectures
- Designing high-performing architectures
- Designing cost-optimised architectures