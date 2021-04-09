#!/bin/bash
set -x


####
#  This script will configure a node as a HTCondor's worker node
#  using default setup provided by the Rubin AWS autobuilder package.
####
CWD=$1
cd $CWD


####
#   1) Configure instance as HTCondor worker node
####
cd $CWD
sudo cp ~/RubinAWS/autobuilder/configs/condor_worker_config /etc/condor/config.d/local
echo "SSH_TO_JOB_SSHD_CONFIG_TEMPLATE = /etc/condor/condor_ssh_to_job_sshd_config_template" >> /etc/condor_config
sudo rm /etc/condor/config.d/50ec2.config

#   1.1) Restart Condor to reload config values. Run annex configurator.
sudo systemctl restart condor
sudo systemctl start condor-annex-ec2
sudo systemctl enable condor-annex-ec2
