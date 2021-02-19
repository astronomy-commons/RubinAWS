# Rubin on AWS

## Introduction

[LSST](https://www.lsst.org/) Vera C. Rubin Science Pipelines are a collection
of cutting edge astronomical image processing algorithms and tools designed to
process astronomical image data on petabyte scales. [Rubin Science Pipelines](https://www.lsst.io/about/)
were designed to run on Rubin Data Management infrastructure.

To give more Astronomers access to cutting edge, scalable, astronomical data
reduction in an affordable way we implemented support for [Amazon Web Services](https://aws.amazon.com/)
and [Google Cloud Computing Services](https://cloud.google.com/compute). To learn
more about the project see

* this introductory [Dirac web article](https://dirac.astro.washington.edu/lsst-in-the-cloud/)
* [A Gateway to Astronomical Image Processing: Vera C. RubinObservatory LSST Science Pipelines on AWS](https://arxiv.org/abs/2011.06044)
* this Data Management Technical Note [DMTN-137](https://dmtn-137.lsst.io/) for AWS
* or this [DMTN-157](https://dmtn-157.lsst.io/) for GCE

This repository is a collection of [Packer])(https://www.packer.io/) and [Terraform](https://www.terraform.io/)
scripts needed to stand up a basic Rubin Science Pipelines infrastructure on AWS
suitable for development and demonstration purposes.

The infrastructure consists of pre-build AMIs for Head and Worker HTCondor nodes,
RDS PostgreSQL database instance and supporting authentication infrastructure.

AMIs can be build using the provided Packer templates in `autobuilder/images`
while Terraform scripts under `autobuilder/deployment` will create the required
networking and security groups and launch an RDS database and a Head node instance.

## Description

 * Refer to comments on top of files to find more details and instructions
   on usage.
   
 * Packer scripts base operating system is CentOS 8.3. No other OSs are
   currently supported.
   
 * Scripts that install all required prerequisite software (Rubin Software stack,
   Pegasus and HTCondor) can be found under `autobuilder/scripts`.
   
 * The Condor configuration scripts for Head and Worker nodes can be found in
   `autobuilder/configs` directory.
   
 * The Terraform deployment scripts can be found in `autobuilder/deploy`
   directory.
   
 * Terraform scripts will configure a VPC with a private and public subnets and
   launch an EC2 instance (requires an AMI image) and an RDS instance in them.
   
 * There are no demos for processing data with the Science Pipelines, this is
   a work in progress.
 
## Prerequisites

* You will need Packer, Terraform and an AWS account with enough permissions
  to create the needed resources. Assuming you're using `yum` as your package
  manager, run:

  ```
  yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  yum -y install packer
  ```
  to install Packer.
 
  Certain operating systems already have a different tool, also invoked with `packer`
  installed. In this case linking the installed packer binary to an alias could be
  required. See Packer [installation documentation](https://learn.hashicorp.com/tutorials/packer/getting-started-install#troubleshooting) for details.

  To do more than just build the AMIs you will require Terraform. Assuming
  `hashicorp` repository was already added, run:

  ```
  yum -y install terraform
  ```
  to install Terraform.
 
  An AWS account for which you know your `AWS ACCESS KEY ID` and `AWS SECRET ACCESS KEY`
  authentication credentials. See [AWS documentation](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys) for details.
  Installing [AWS CLI tool](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html) by running:
 
  ```
  curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
  unzip awscli-bundle.zip
  sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/asw
  ```
  is recommended.
 
  The AWS security credentials can then be permanently configured on your machine
  by running:
 
  ```
  aws configure
  ```
  as described in the [AWS CLI documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
 
  The Packer and Terraform scripts support authentication via the AWS secrets file
  (usually in the `~/.aws/` directory). Provided scripts also support [AWS Named Profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
  and their use is also recommended.
 
  These credentials will not be shared nor uploaded to the instances.

## Creating the AMIs

First, make sure you have all the prerequisites installed (see above). Navigate
to the `autobuilder/images` directory and run:

```
packer build nodes.pkr.hcl
```

Wait for the script to finish. Build executes in parallel and should take
approximately 30minutes. Build logs will be printed in separate colors. Contents
of the executed scripts could be printed in red color. Do not panic, this is not
an error.

At the end of the build the output of the scripts will look like:

```
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.head: AMIs were created:
us-west-2: ami-0d1d7fc27ae09c037

--> amazon-ebs.worker: AMIs were created:
us-west-2: ami-0d1d7fc27ae09c037
```

Note the head and node AMI IDs. They will be a required input to Terraform
scripts. Optionally, manually launch a Head node from the head node AMI and SSH in.

## Creating the basic infrastructure

Make sure you have all the prerequisites installed (see above). Ensure you have
the required AMI IDs. Navigate to the `autobuilder/deploy` directory and run:

```

# Initialize terraform
terraform init

# Build the infrastructure
terraform apply -var="head_ami=ami-12345abcd"
```

Terraform scripts will create all the basic infrastructure needed to run Rubin
LSST Science Pipelines in the cloud.

## Destroying the cluster

To destroy an existing cluster, run:

```
terraform destroy
```

