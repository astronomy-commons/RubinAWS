# This HCL Packer template is part of the Rubin AWS Autobuilder.
#
# This template defines the AMI build process for both the Rubin AWS
# Head and Worker nodes. Script must be invoked from autobuilder/images/
# directory as
#
#    packer build nodes.pkr.hcl
#
# or optionally a full path to the autobuilder script must be provided:
#
#    packer build images/nodes.pkr.hcl -var='source=/home/user/autobuilder/scripts/autobuilder.sh'
#
# This template requires AWS credentials are provided by setting
# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env. variables or
# by configuring profiles in `~/.aws/config` and setting AWS_PROFILE
# env. var.
#
# The build:
# * uses base_ami_name and
#
#    (note: autobuilder script only supports CentOS builds so far)
#
# * allocates 2 instance_type instances with EBS volumes with volume_size
#    capacity and
#
#    (note: This sets how small all the future nodes can be because it
#    is impossible to undersize an EBS volume of an AMI. A smaller EBS volume
#    has less IOPS capacity and, when undersized, will drastically increase
#    the required build time.)
#
# * invokes the autobuilder script with `head` argument on one node and
#    `worker` argument on the other.


################
# Variables
################

variable "aws_access_key" {
    type        = string
    description = "AWS Secret Access Key ID read from the env var AWS_ACCESS_KEY_ID"
    default = "${env("AWS_ACCESS_KEY_ID")}"
}

variable "aws_secret_key" {
    type        = string
    description = "AWS Secret Access Key, read from the env var AWS_SECRET_ACCESS_KEY"
    default = "${env("AWS_SECRET_ACCESS_KEY")}"
}

variable "aws_profile" {
    type    = string
    description = "AWS Profile, when profiles are configured. Read from env var AWS_PROFILE."
    default = "${env("AWS_PROFILE")}"
}

variable "aws_region" {
    type        = string
    description = "AWS Region in which to build the AMIs in."
    default     = "us-west-2"
}

variable "instance_type" {
    type    = string
    description = "Instance type to build on (underpowered instances can increase build time)."
    default = "m5.2xlarge"
}

variable "volume_size" {
    type    = number
    description = "Instance EBS volume size. Sets the minimal EBS drive size of your nodes. Undersized EBS drive will incraese build time."
    default = 100
}

variable "base_ami_name" {
    type    = string
    description = "Base build instance AMI. Currently supports only CentOS."
    default = "CentOS 8.3.2011 x86_64"
}


################
# Source definitions
################

source "amazon-ebs" "head" {
    profile = "$(var.aws_profile}"
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    instance_type = "${var.instance_type}"
    region = "${var.aws_region}"
    source_ami_filter {
        filters = {
            virtualization-type = "hvm"
            name = "${var.base_ami_name}"
            root-device-type = "ebs"
        }
        owners = [ "125523088429" ]
        most_recent = true
    }
    launch_block_device_mappings {
            device_name = "/dev/sda1"
            volume_size = "${var.volume_size}"
            volume_type = "gp2"
            delete_on_termination = true
    }
    ssh_username = "centos"
    ami_name = "packerTest-{{timestamp}}"
}


################
# Builder
################

build {
    source "amazon-ebs.head" {
      name = "worker"
    }

    sources = ["source.amazon-ebs.head", ]

    provisioner "file" {
        source = "../scripts"
        destination = "/tmp"
    }
    provisioner "shell" {
        inline = [
          "chmod u+x /tmp/scripts/autobuilder.sh",
          "/tmp/scripts/autobuilder.sh ${source.name}"
        ]
    }
}
