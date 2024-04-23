Automatically install Ops Manager on ec2
========================================

This creates 4 VMs in EC2:
- one for OM (t3a.xlarge)
- three for demo instances (t2.small)

it uses the OM API to initialize a basic system (app db, initial user and org) and deploys and starts the MongoDB Agent on the demo instances. From there on you can demo how to create MongoDB replica sets, etc.

Basic backup (FS store, oplog colocated with appdb - never do that at home, kids!) is provisioned, too.

Prerequisites
-------------

* AWS CLI
  * Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html
  * Configure AWS CLI: type `aws configure` and follow the instructions
  * Valid AWS access key / secret access key / session token in env vars, ~/.aws/credentials, or simply using `aws sso login`
  * Ops Manager will be installed in your default region
* jq (install from the terminal: brew install jq)
* In EC2:
  * Valid key pair for the region
  * Store the .pem file in the folder of your choice, make sure that read rights are configured by running the following command in the terminal: chmod 400 /folder/key_file_name.pem
  * Security group that allows all outbound communication and inbound for ports 8080 and 27017


HOWTO
-----

Create a file called config.sh containing:

```
KEYNAME=(your key name as exists in EC2)
KEYPATH=(local path to your pem-encoded private key)
SECGROUP=(your security group identifier)
IMAGE=(Amazon Linux 2023 AMI; in eu-west-3 I use this one: ami-01bf5e7ea6da0b6e1)
NAMETAG=(prefix for the Name tag on the instances)
OWNERTAG=(value of the Owner tag on the instances)
PURPOSETAG=(value of the Purpose tag on the instances)
EXPIREON=(value of the Expire-On tag on the instances)
```

Optionally you can add a NUM_HOSTS variable with the number of MongoDB hosts you want to spin up (default 3)

If you don't specify PURPOSETAG, it defaults to "other"

then `./launch-om.sh` should do the trick.

One OM is deployed, your default browser will open with the login page, you will see the credentials in the terminal: admin@localhost.com / abc_ABC1

Destroy everything with `./teardown-om.sh`
