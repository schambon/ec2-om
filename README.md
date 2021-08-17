Automatically install Ops Manager on ec2
========================================

This creates 4 VMs in EC2:
- one for OM (t3a.xlarge)
- three for demo instances (t2.small)

it uses the OM API to initialize a basic system (app db, initial user and org) and deploys and starts the MongoDB Agent on the demo instances. From there on you can demo how to create MongoDB replica sets, etc.

*NEW*: basic backup (FS store, oplog colocated with appdb - never do that at home, kids!) is provisioned, too.

Prerequisites
-------------

* AWS CLI
  * valid AWS access key / secret access key / session token (either in env vars or in ~/.aws/credentials)
  * Ops Manager will be installed in your default region
* jq
* In EC2:
  * valid keypair for the region
  * security group that allows all outbound communication and inbound for ports 8080 and 27017


HOWTO
-----

Create a file called config.sh containing:

```
KEYNAME=(your key name as exists in EC2)
KEYPATH=(local path to your pem-encoded private key)
SECGROUP=(your security group identifier)
IMAGE=(Amazon Linux 2 AMI; for eu-west-3 I use this one: ami-093fa4c538885becf)
NAMETAG=(prefix for the Name tag on the instances)
OWNERTAG=(value of the Owner tag on the instances)
```

then `./launch-om.sh` should do the trick.

Destroy everything with `./teardown-om.sh`
