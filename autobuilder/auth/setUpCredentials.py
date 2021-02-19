"""This file is a part of autobuilder Packer build scripts.

This script is copied to the node during the build process and is invoked on login.

The script:
    *) checks whether credentials exist on the instance and if not asks for
       that they be provided
    *) performs a sanity check by verifying the most basic subset of required
       functionality is authorized for the given credentials
    *) if they are, places credentials in their all of the required locations
       so that HTCondor and Pegasus can find them.
"""

#!/usr/bin/env python3
import os
import pipes

import boto3
import botocore

splashMsg = \
"""
No AWS credentials were detected on this machine. The following script will
help you set up correct AWS credentials for Pegasus, HTCondor and AWS CLI.

Please input the AWS Access Key ID and AWS Secret Access Key when
prompted.
================================================================================
"""

def validate(accessKeyId, secretAccessKey):
    """
    Validates that given credentials are correct by simulating
    AWS Security Token Service policy"s access to Put, Get and
    Delete Object operations in a test bucket.

    Parameters
    ----------
    accessKeyId : AWS Access Key ID
    secretAccessKey : AWS Secret Access Key

    Returns
    -------
    validated : True when all validation tests pass, False otherwise.

    Notes
    -----
    Credentials are valid only if the set of minimal Bucket
    operations required for execution pass. These are:
        s3:PutObject
        s3:GetObject
        s3:DeleteObject
        s3:GetBucketLocation
        s3:ListBucket
    """
    iam = boto3.client("iam",
                       aws_access_key_id=accessKeyId,
                       aws_secret_access_key=secretAccessKey)
    sts = boto3.client("sts",
                       aws_access_key_id=accessKeyId,
                       aws_secret_access_key=secretAccessKey)

    # Get the arn represented by the currently configured credentials
    # this can still fail if credentials are not conforming to requirements
    # (char count, type, etc..)
    try:
        arn = sts.get_caller_identity()["Arn"]
    except botocore.exceptions.ClientError as e:
        print(f"Incorrect credentials: {e.response['Error']['Code']}")
        return False

    # Create an arn representing the objects in a bucket
    bucket_objects_arn = "arn:aws:s3:::%s/*" % "my-test-bucket"

    # Run the policy simulation for the basic s3 operations
    results = iam.simulate_principal_policy(
        PolicySourceArn=arn,
        ResourceArns=[bucket_objects_arn],
        ActionNames=["s3:PutObject", "s3:GetObject", "s3:DeleteObject",
                     "s3:GetBucketLocation", "s3:ListBucket"]
    )

    # credentials are valid only when all of the required actions
    # are allowed.
    valid = True
    for result in results["EvaluationResults"]:
        print("%s - %s" % (result["EvalActionName"], result["EvalDecision"]))
        valid = valid and (result["EvalDecision"].lower() == "allowed")

    return valid


def requestAndValidateCredentials():
    """
    Requests the credentials from the user and validates them.
    If unsuccessful it requests new credentials from the user.
    Stops when given credentials pass validation.

    Returns
    -------
    accessKeyId : `str`
        AWS Access Key ID
    secretAccessKey : `str`
        AWS Secret Access Key
    """
    validated = False
    while not validated:
        accessKeyId = input("Input AWS Access Key ID: ").strip()
        secretAccessKey = input("Input AWS Secret Access Key: ").strip()
        validated = validate(accessKeyId, secretAccessKey)
        print()

    return accessKeyId, secretAccessKey


def createCondorFiles(accessKeyId, secretAccessKey):
    """
    Creates publicKeyFile and privateKeyFile in ~/.condor.
    Sets 600 permissions on the files.

    Parameters
    ----------
    accessKeyId : `str`
        AWS Access Key ID
    secretAccessKey : `str`
        AWS Secret Access Key
    """
    rootDir = os.path.expanduser("~/.condor")
    pairs = ({"path": os.path.join(rootDir, "publicKeyFile"), "key": accessKeyId},
             {"path": os.path.join(rootDir, "privateKeyFile"), "key": secretAccessKey})

    for pair in pairs:
        with open(pair["path"], "w") as credFile:
            credFile.write(pair["key"])
            print("Created %s" % (pipes.quote(str((pair['path'])))))
        os.chmod(pair["path"], 0o600)


def exportCredToEnv(accessKeyId, secretAccessKey):
    """
    Sets environmental variables AWS_ACCESS_KEY_ID and
    AWS_SECRET_ACCESS_KEY.

    Parameters
    ----------
    accessKeyId : `str`
        AWS Access Key ID
    secretAccessKey : `str`
        AWS Secret Access Key
    """
    #print("export AWS_ACCESS_KEY_ID=%s" % (pipes.quote(str(accessKeyId))))
    print("Exported AWS_ACCESS_KEY_ID to environment variable.")
    #print("export AWS_SECRET_ACCESS_KEY=%s" % (pipes.quote(str(secretAccessKey))))
    print("Exported AWS_SECRET_ACCESS_KEY to environment variable.")


def checkCredentialsFile(filepath):
    """
    Given a filepath check if the file exists and if it's empty. If it exists
    and is not empty returns True and its contents. Return False and None
    otherwise.

    Parameters
    ----------
    filepath : `str`
        Path to file to check

    Returns
    -------
    exists : `bool`
        True if the file exists and is not empty. False otherwise.
    cred : `str` or `None`
        Contents of the file if nonempty. None otherwise.
    """
    filepath = os.path.expanduser(filepath) if "~" in filepath else filepath
    exists = False
    cred = None
    try:
        with open(filepath, "r") as credFile:
            content = credFile.read()
            # if it's an empty file
            if content:
                exists = True
                cred = content
    except FileNotFoundError:
        pass
    return exists, cred


def checkEnvVar(envVar):
    """
    Checks if the environmental variable exists and returns True and its value
    if it does.

    Parameters
    ----------
    envVar : `str`
        Name of the environmental variable.
    cred : `str` or `None`
        Value of envVar if it exists, None otherwise.
    """
    exists = False
    cred = None
    try:
        cred = os.environ[envVar]
    except KeyError:
        pass
    return exists, cred


def checkCredentials():
    """
    Checks environmental variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
    and contents of the HTCondor Annex credential key files in ``~/.condor`` in
    an attempt to construct a valid set of AWS credentials.

    Returns
    -------
    cred : `dict`
        A dictionary containing ``exist``, a bool, ``accessKeyId`` and
        ``secretKey``.

    Notes
    -----
    Value of ``exist`` will only be true if both access key id and secret key
    values were found in either the environment or the files. Otherwise False,
    as a valid set of credentials could not be found.
    """
    cred = {"exist": False, "accessKeyId": None, "secretKey": None}

    access1, accessKey1 = checkCredentialsFile("~/.condor/publicKeyFile")
    secret1, secretKey1 = checkCredentialsFile("~/.condor/privateKeyFile")
    access2, accessKey2 = checkEnvVar("AWS_ACCESS_KEY_ID")
    secret2, secretKey2 = checkEnvVar("AWS_SECRET_ACCESS_KEY")

    accessExists = access1 or access2
    secretExists = secret1 or secret2
    cred["exist"] = accessExists and secretExists

    if cred["exist"]:
        cred["accessKeyId"] = accessKey1 if access1 else accessKey2
        cred["secretKey"] = secretKey1 if access1 else secretKey2

    return cred


if __name__ == "__main__":
    cred = checkCredentials()

    if cred["exist"]:
        accessKeyId = cred["accessKeyId"].split("=")[-1].strip()
        secretAccessKey = cred["secretKey"].split("=")[-1].strip()
        createCondorFiles(accessKeyId, secretAccessKey)
        exportCredToEnv(accessKeyId, secretAccessKey)
    else:
        print(splashMsg)
        accessKeyId, secretAccessKey = requestAndValidateCredentials()
        print()
        createCondorFiles(accessKeyId, secretAccessKey)
        exportCredToEnv(accessKeyId, secretAccessKey)

    print()
    print("Set up done!")

