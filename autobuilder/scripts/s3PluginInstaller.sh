#!/bin/bash
set -x

CWD=$1
cd $CWD

####
#  This script will configure an S3 Transfer pluguin so that HTCondor
#  is able to use S3 buckets to communicate and stage jobs.
####
sudo cp ~/RubinAWS/autobuilder/configs/s3.sh /usr/libexec/condor/s3.sh
sudo chmod 755 /usr/libexec/condor/s3.sh
sudo cp ~/RubinAWS/autobuilder/configs/10_s3 /etc/condor/config.d/10-s3

####
#  Cleanup
####
mkdir -p .install
mv -nr RubinAWS -t .install/
