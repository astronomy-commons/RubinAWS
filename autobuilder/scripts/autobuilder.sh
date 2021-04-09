#!/bin/bash
set -x

BUILD_TYPE=$1
export AWS_REGION=$2

build_type="None"
case $BUILD_TYPE in
    "Worker")
        build_type="worker"
        ;;
    "WORKER")
        build_type="worker"
        ;;
    "worker")
        build_type="worker"
        ;;
    "Head")
        build_type="head"
        ;;
    "HEAD")
        build_type="head"
        ;;
    "head")
        build_type="head"
        ;;
esac

CWD=$(pwd)

# 1) Install all required packages.
. /tmp/scripts/baseInstaller.sh $CWD

# 2) Run desired HTCondor configurator
if [ "$build_type" = "worker" ]; then
    . /tmp/scripts/workerConfigurator.sh $CWD
else
    . /tmp/scripts/headConfigurator.sh $CWD
fi

# 3) Add the S3 HTCondor plugin.
. /tmp/scripts/s3PluginInstaller.sh $CWD

#  4) Restart Condor to reload config values.
sudo systemctl restart condor
sudo systemctl start condor-annex-ec2
sudo systemctl enable condor-annex-ec2


# 5) Cleanup
cd $CWD
mkdir -p .install
mv RPM-GPG-KEY-HTCondor pegasus-5.0.0-1.el8.x86_64.rpm -t .install/
mv -n autobuilder -t .install/

