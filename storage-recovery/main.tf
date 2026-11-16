terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# Existing default VPC
data "aws_vpc" "default" {
  default = true
}

# Source Availability Zone
data "aws_subnet" "source" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "eu-north-1a"

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security group without inbound access
resource "aws_security_group" "storage" {
  name        = "JennyOma-Storage-Recovery-SG"
  description = "Isolated storage recovery lab"
  vpc_id      = data.aws_vpc.default.id
}

# Additional EBS data volume
resource "aws_ebs_volume" "source" {
  availability_zone = data.aws_subnet.source.availability_zone
  size              = 1
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "JennyOma-Source-EBS"
  }
}

# Source EC2 instance
resource "aws_instance" "source" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.source.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.storage.id]

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee -a /var/log/storage-lab.log /dev/console) 2>&1

    device=""
    for i in $(seq 1 120); do
      device=$(lsblk -dn -o NAME,SERIAL,TYPE | awk -v id="${replace(aws_ebs_volume.source.id, "-", "")}" '$2 == id && $3 == "disk" {print "/dev/" $1; exit}')
      if [ -b "$device" ]; then
        break
      fi
      sleep 5
    done

    test -b "$device"

    if blkid "$device" >/dev/null 2>&1; then
      echo "Existing filesystem detected. Stopping."
      exit 1
    fi

    mkfs.ext4 "$device"
    mkdir -p /mnt/recovery
    mount "$device" /mnt/recovery

    echo "JennyOma EBS Recovery Test - Fictional Data" > /mnt/recovery/test.txt

    sync
    cat /mnt/recovery/test.txt
    umount /mnt/recovery

    echo "STORAGE TEST COMPLETE"
  EOF

  tags = {
    Name = "JennyOma-Storage-Source-EC2"
  }
}

# Attach additional EBS volume
resource "aws_volume_attachment" "source" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.source.id
  instance_id = aws_instance.source.id
}

output "source_instance_id" {
  value = aws_instance.source.id
}

output "source_volume_id" {
  value = aws_ebs_volume.source.id
}
# Snapshot of the source EBS data volume
resource "aws_ebs_snapshot" "backup" {
  volume_id   = aws_ebs_volume.source.id
  description = "JennyOma EBS recovery test snapshot"

  tags = {
    Name = "JennyOma-Storage-Snapshot"
  }
}

output "snapshot_id" {
  value = aws_ebs_snapshot.backup.id
}
# Recovery Availability Zone
data "aws_subnet" "recovery" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "eu-north-1b"

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Restore EBS volume from snapshot
resource "aws_ebs_volume" "restored" {
  availability_zone = data.aws_subnet.recovery.availability_zone
  snapshot_id       = aws_ebs_snapshot.backup.id
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "JennyOma-Restored-EBS"
  }
}

# Recovery EC2 instance
resource "aws_instance" "recovery" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.recovery.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.storage.id]

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee -a /var/log/recovery-lab.log /dev/console) 2>&1

    device=""
    for i in $(seq 1 120); do
      device=$(lsblk -dn -o NAME,SERIAL,TYPE | awk -v id="${replace(aws_ebs_volume.restored.id, "-", "")}" '$2 == id && $3 == "disk" {print "/dev/" $1; exit}')
      if [ -b "$device" ]; then
        break
      fi
      sleep 5
    done

    test -b "$device"

    mkdir -p /mnt/recovery
    mount -o ro,noload "$device" /mnt/recovery

    cat /mnt/recovery/test.txt

    grep -Fxq "JennyOma EBS Recovery Test - Fictional Data" /mnt/recovery/test.txt

    umount /mnt/recovery

    echo "CROSS-AZ DATA RECOVERY SUCCESSFUL"
  EOF

  tags = {
    Name = "JennyOma-Recovery-EC2"
  }
}

# Attach restored volume
resource "aws_volume_attachment" "recovery" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.restored.id
  instance_id = aws_instance.recovery.id
}

output "recovery_instance_id" {
  value = aws_instance.recovery.id
}

output "restored_volume_id" {
  value = aws_ebs_volume.restored.id
}
# Create a custom AMI from the source EC2 instance
resource "aws_ami_from_instance" "storage" {
  name               = "JennyOma-Week2-Custom-AMI"
  source_instance_id = aws_instance.source.id

  depends_on = [aws_volume_attachment.source]

  tags = {
    Name    = "JennyOma-Week2-Custom-AMI"
    Project = "Storage-Recovery-Lab"
  }
}

output "custom_ami_id" {
  value = aws_ami_from_instance.storage.id
}