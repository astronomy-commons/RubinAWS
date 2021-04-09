#!/bin/bash
set -x


####
#  This script will configure a node as a HTCondor's head node
#  using default setup provided by the Rubin AWS autobuilder package.
####
CWD=$1
cd $CWD

if [ -z "$AWS_SECRET_ACCESS_KEY" ] && [ -z "$AWS_ACCESS_KEY_ID" ]; then
    RUN_ANNEX_SETUP=false
else
    RUN_ANNEX_SETUP=true
fi


####
#   1) Configure instance as HTCondor head node
####
sudo cp ~/RubinAWS/autobuilder/configs/condor_head_config /etc/condor/config.d/local
sudo cp ~/RubinAWS/autobuilder/configs/condor_annex_ec2 /usr/libexec/condor/condor-annex-ec2

#   1.1) Configure a Condor Pool Password.
#        Both Condor and Condor Annex need the condor pool password. But Condor needs it
#        to be securely owned by the root and Annex needs it securely owned by USER.
#        This must happen after head node configs have been detected by condor, since
#        that's where passwd file path is set.
mkdir -p ~/.condor

random_passwd=`tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1`
passwd_file_path=`condor_config_val SEC_PASSWORD_FILE`
sudo condor_store_cred add -f $passwd_file_path -p $random_passwd

sudo cp $passwd_file_path ~/.condor/

sudo chmod 600 $passwd_file_path ~/.condor/condor_pool_password
sudo chown root $passwd_file_path
sudo chown $USER ~/.condor/condor_pool_password

#   1.2) Set up an HTCondor S3 Transfer Plugin
sudo cp ~/RubinAWS/autobuilder/configs/s3.sh /usr/libexec/condor/s3.sh
sudo chmod 755 /usr/libexec/condor/s3.sh
sudo cp ~/RubinAWS/autobuilder/configs/10_s3 /etc/condor/config.d/10-s3

#   1.3) Configure Condor Annex Defaults. If credentials are non-empty strings
#        configure keys so that Condor Annex can succesfully run. Keys are cleanued
#        up later.
if [ $RUN_ANNEX_SETUP = true ]; then
    echo $AWS_SECRET_ACCESS_KEY > ~/.condor/privateKeyFile
    echo $AWS_ACCESS_KEY_ID > ~/.condor/publicKeyFile
    sudo chmod 600 ~/.condor/*KeyFile
fi

echo "SEC_PASSWORD_FILE=~/.condor/condor_pool_password" > ~/.condor/user_config
echo "ANNEX_DEFAULT_AWS_REGION=${AWS_REGION}" >> ~/.condor/user_config
sudo chown $USER ~/.condor/user_config

#   1.4) By now it should be safe to remove the default condor-annex-ec2 config.
sudo rm /etc/condor/config.d/50ec2.config

#   1.5) Restart Condor to reload config values. Run annex configurator.
sudo systemctl restart condor
sudo systemctl start condor-annex-ec2
sudo systemctl enable condor-annex-ec2

if [ $RUN_ANNEX_SETUP = true ]; then
    condor_annex -aws-region $AWS_REGION -setup
    condor_annex -check-setup
fi


####
#   2) Add stack setup and authenticator to bashrc.
####
echo "# The following commands were added by Rubin AWS autobuilder." >> ~/.bashrc
echo "source ~/lsst_stack/loadLSST.bash" >> ~/.bashrc
echo "setup lsst_distrib" >> ~/.bashrc
echo "source ~/.install/RubinAWS/autobuilder/auth/authenticate.sh" >> ~/.bashrc


####
#   3) Cleanup
####
cd $CWD
if [ $RUN_ANNEX_SETUP = true ]; then
    rm -f ~/.condor/*KeyFile
fi

