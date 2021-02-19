# This HCL Terraform configuration is a part of Rubin AWS autobuilder.
#
# The configuration script launches the basic infrastructure required
# to run Rubin processing on AWS. On first use Terraform must be initialized
#
#     terraform init
#
# To build the infrastructure, from the ``deploy`` directory, use
#
#     terraform apply
#
# This configuration script creates:
#     * a dedicated RubinAWS Virtual Private Cloud (VPC),
#
#       note: the default assigned CIDR block is 192.168.0.0/16
#
#     * two RubinAWS subnets
#
#       note: a private subnet assigns 192.168.1.0/24 IP addresses,
#       and a public subnet assigns 192.168.0.0/24 IP addresses.
#       Both public and private subnets are required for a valid
#       DB Subnet group association
#
#     * a RubinAWS Security Group
#
#       note: the group is assigned to the Head and Worker instance
#       nodes and they require an HTCondor port 9618 and an RDS port
#       5432. Changing these value must be reflected in HTCondor
#       and RDS configurations.
#
#     * a RubinAWS RDS Parameters Group
#
#       note: inappropriate max locks, connections and buffer size values
#       will have a significant negative impact on workflow execution.       
#
#     * a RubinAWS DB subnet group association
#
#       note: the association must span multiple availability zones,
#       meaning that the two RubinAWS subnets must also span at least
#       2 zones.
#
#     * launch an RubinAWS RDS PostgreSQL instance
#
#       note: RDS instance identifier must be unique across all DB
#       instances owned by your account in the set region.
#
#     * launch an HTCondor Head node
#
#       note: The node is launched from an pre-built AMI. These
#       are built from Packer templates in autobuilder (see
#       ../images and usage).
#
#
# This template requires AWS credentials are provided by setting
# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env. variables or
# by configuring profiles in `~/.aws/config` and setting AWS_PROFILE
# env. var.


################
# Variables
################



################
# Terraform block
################

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


provider "aws" {
  profile = "dirac"
  region = "us-west-2"
}


################
# Resources
################

resource "aws_vpc" "RubinAWS" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "RubinAWS dedicated VPC."
  }
}


resource "aws_subnet" "RubinAWSPrivate" {
  vpc_id            = aws_vpc.RubinAWS.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "RubinAWS Cluster Subnet."
  }
}

resource "aws_subnet" "RubinAWSPublic" {
  vpc_id            = aws_vpc.RubinAWS.id
  cidr_block        = "192.168.0.0/24"
  availability_zone = "us-west-2c"

  tags = {
    Name = "RubinAWS Cluster Subnet."
  }
}


resource "aws_security_group" "RubinAWS" {
  name        = "RubinAWS"
  description = "Rubin AWS security group used by Head and Worker nodes."
  vpc_id      = aws_vpc.RubinAWS.id

  ingress {
    description = "SSH Login Port."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTCondor Communication Port."
    from_port   = 9618
    to_port     = 9618
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.RubinAWS.cidr_block]
  }
  ingress {
    description = "RDS Communication Port."
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.RubinAWS.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RubinAWS Node Security Group"
  }
}


resource "aws_db_parameter_group" "RubinAWS" {
  name        = "butler-registry"
  description = "Default PSQL Parameters Group for Rubin AWS."
  family      = "postgres12"

  parameter {
    name  = "max_locks_per_transaction"
    value = 1024
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_buffers"
    value        = 2200
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_connections"
    value = 2500
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "RubinAWS DB Parameter Group"
  }
}


resource "aws_db_subnet_group" "RubinAWS" {
  name       = "registry_subnet"
  subnet_ids = [aws_subnet.RubinAWSPrivate.id,
                aws_subnet.RubinAWSPublic.id]

  tags = {
    Name = "Rubin AWS subnet group."
  }
}


resource "aws_db_instance" "RubinAWS" {
  identifier           = "rubin-aws"
  engine               = "postgres"
  engine_version       = "12.5"
  instance_class       = "db.m6g.large"
  allocated_storage    = 500
  storage_type         = "gp2"
  name                 = "butlerRegistry"
  username             = "foo"
  password             = "foobarbaz"
  skip_final_snapshot  = true
  parameter_group_name = aws_db_parameter_group.RubinAWS.name
  db_subnet_group_name = aws_db_subnet_group.RubinAWS.name

  vpc_security_group_ids = [
    aws_security_group.RubinAWS.id
  ]

  tags = {
    Name = "RubinAWS Butler Registry."
  }
}


resource "aws_instance" "headNode" {
  ami           = "ami-0553b5c521f424559"
  instance_type = "m5.2xlarge"
  subnet_id     = aws_subnet.RubinAWSPrivate.id

  vpc_security_group_ids = [
      aws_security_group.RubinAWS.id
  ]
}




