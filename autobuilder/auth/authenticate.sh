#!/usr/bin/env bash

# Script invokes credentials setup and exports them to the environment
python3 setUpCredentials.py

export AWS_ACCESS_KEY_ID=`cat ~/.condor/publicKeyFile`
export AWS_SECRET_ACCESS_KEY=`cat ~/.condor/privateKeyFile`
