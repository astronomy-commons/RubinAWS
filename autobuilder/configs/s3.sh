#!/bin/sh

# This file is a part of the HTCondor instalaltion.
#
# This script defines a plugin that HTCondor can use
# to access data on S3 buckets.
# Requires: AWS CLI

if [ "$1" = "-classad" ]
then
    echo 'PluginVersion = "0.1"'
    echo 'PluginType = "FileTransfer"'
    echo 'SupportedMethods = "s3"'
    exit 0
fi

source=$1
dest=$2

exec aws s3 cp ${source} ${dest}
