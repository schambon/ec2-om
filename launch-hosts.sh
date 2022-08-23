AGENT_VERSION=12.0.10.7591

export AWS_PAGER=""
# $1 is supposed to have the OM host's public PublicDnsName
PUBDNS=$1
PROJECT_ID=$2
AGENT_API_KEY=$3

NUM_HOSTS=3
PURPOSETAG=other

source config.sh


echo "Starting instances and downloading agent from $PUBDNS; Project is $PROJECT_ID and agent key is $AGENT_API_KEY"

# start 3 hosts and install the agent
aws ec2 run-instances --image-id $IMAGE --count $NUM_HOSTS --instance-type t2.small --key-name $KEYNAME \
  --security-group-ids $SECGROUP --block-device-mappings '[{"DeviceName": "/dev/xvda", "Ebs": {"DeleteOnTermination": true, "VolumeSize": 100, "VolumeType": "gp3"}}]' \
  --tag-specification "ResourceType=instance,Tags=[{Key=Name, Value=\"$NAMETAG-instances\"},{Key=owner, Value=\"$OWNERTAG\"}, {Key=expire-on,Value=\"2022-12-31\"}, {Key=purpose,Value=\"$PURPOSETAG\"}]" > /dev/null

sleep 1
count=$(aws ec2 describe-instances --filters "Name=tag:owner,Values=$OWNERTAG" "Name=tag:Name,Values=$NAMETAG-instances" "Name=instance-state-name,Values=running" | jq -r '.Reservations[0].Instances | length')
until test $count -eq $NUM_HOSTS
do
  echo "Waiting until we have 3 instances"
  sleep 1
  count=$(aws ec2 describe-instances --filters "Name=tag:owner,Values=$OWNERTAG" "Name=tag:Name,Values=$NAMETAG-instances" "Name=instance-state-name,Values=running" | jq -r '.Reservations[0].Instances | length')
done

echo "Waiting 10s for public dns names to come up (just to be sure)"
sleep 10

for inst in $(aws ec2 describe-instances --filters "Name=tag:owner,Values=$OWNERTAG" "Name=tag:Name,Values=$NAMETAG-instances" "Name=instance-state-name,Values=running" | jq -r '.Reservations[].Instances[].PublicDnsName');
do
echo "Working on $inst"
nc -z $inst 22
until test $? -eq 0
do
  sleep 1
  echo "Waiting"
  nc -z $inst 22
done
echo "Can ssh"
ssh -i $KEYPATH -oStrictHostKeyChecking=no ec2-user@$inst <<-EOC
sudo hostname $inst
sudo yum install -y http://$PUBDNS:8080/download/agent/automation/mongodb-mms-automation-agent-manager-$AGENT_VERSION-1.x86_64.rhel7.rpm
sudo yum install -y cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl net-snmp openldap openssl xz-libs
sudo cat /etc/mongodb-mms/automation-agent.config | grep -v mmsGroupId | grep -v mmsApiKey | grep -v mmsBaseUrl | sudo tee /etc/mongodb-mms/automation-agent.config
sudo tee -a /etc/mongodb-mms/automation-agent.config <<-CONF_FILE
mmsGroupId=$PROJECT_ID
mmsApiKey=$AGENT_API_KEY
mmsBaseUrl=http://$PUBDNS:8080
CONF_FILE
sudo systemctl enable mongodb-mms-automation-agent
sudo systemctl start mongodb-mms-automation-agent
sudo mkdir -p /data
sudo chown mongod: /data
EOC
done

# #curl -OL http://$PUBDNS:8080/download/agent/automation/mongodb-mms-automation-agent-manager-10.2.19.5989-1.x86_64.rhel7.rpm
