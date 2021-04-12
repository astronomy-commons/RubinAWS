#!/bin/bash
set -x

####
#  This script will install HTCondor, HTCondor Annex, Pegasus and Rubin Software Stack.
####
CWD=$1
cd $CWD


####
#   1) Get the autobuilder and then install the packages required to perform
#      Stack, Condor and Pegasus installations.
####
#   1.1) EPEL and Powertools are needed because of Pegasus dependencies, even
#        though it makes the installation much longer.
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf config-manager --set-enabled powertools

sudo yum update -y
sudo yum install -y curl patch wget git diffutils java unzip

sudo yum install -y iptables-services
sudo systemctl start iptables
sudo systemctl enable iptables
sudo systemctl start ip6tables
sudo systemctl enable ip6tables

mkdir -p .awscli
cd .awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm awscliv2.zip
cd $CWD

git clone https://github.com/astronomy-commons/RubinAWS.git


####
#   2) Install HTCondor for CentOS 8
####
wget https://research.cs.wisc.edu/htcondor/yum/RPM-GPG-KEY-HTCondor
sudo rpm --import RPM-GPG-KEY-HTCondor

sudo curl --output /etc/yum.repos.d/htcondor-stable-rhel8.repo \
     https://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-stable-rhel8.repo

sudo yum install -y condor

#   2.1) Fix Condor's SELinux conflicts and start it to create default configs.
sudo chmod 755 /var/log
sudo systemctl enable condor
sudo systemctl start condor

#   2.2 ) condor-annex-ec2 service is only supposed to be run on machines *which
#         condor_annex adds to the pool*. We need the package on head and worker nodes.
#         It detect instance parameters at instance start so we don't have to use
#         long-lived head nodes. It won't hang at boot on our head nodes because
#         boot script is replaced with a custom one (see headConfigurator.sh).
#         We can't start the service here because it will perform an instance
#         shut-down when improperly configured and we still need to go through
#         a lot of install process.
sudo yum install -y condor-annex-ec2


####
#   3) Install Pegasus.
#      This must occur after Condor installation since Condor is a dependency
####
wget -q https://download.pegasus.isi.edu/wms/download/rhel/8/x86_64/pegasus-5.0.0-1.el8.x86_64.rpm
sudo yum localinstall -y pegasus-5.0.0-1.el8.x86_64.rpm


####
#   4) Install the stack with newinstall.sh method
####
mkdir -p lsst_stack
cd lsst_stack

curl -OL https://raw.githubusercontent.com/lsst/lsst/master/scripts/newinstall.sh

# This is a fix for the stack having removed CentOS 8 support
export LSST_SPLENV_REF=0.4.1
bash ~/lsst_stack/newinstall.sh -bct

source ~/lsst_stack/loadLSST.bash
eups distrib install -t w_latest lsst_distrib
