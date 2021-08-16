
source config.sh

OM_VERSION=https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-5.0.1.97.20210805T0614Z-1.x86_64.rpm

export AWS_PAGER=""
# start instance to run Ops Manager
# t3a.medium has 4GB RAM - should be enough for a demo config
echo "Spinning up AWS instance for Ops Manager"
aws ec2 run-instances --image-id $IMAGE --count 1 --instance-type t3a.xlarge --key-name $KEYNAME \
  --security-group-ids $SECGROUP --block-device-mappings '[{"DeviceName": "/dev/xvda", "Ebs": {"DeleteOnTermination": true, "VolumeSize": 100, "VolumeType": "gp3"}}]' \
  --tag-specification "ResourceType=instance,Tags=[{Key=Name, Value=\"$NAMETAG-om\"},{Key=owner, Value=\"$OWNERTAG\"}, {Key=expire-on,Value=\"2021-12-31\"}]" > /dev/null

echo "Done"
# wait a couple seconds that the instance is up
sleep 10

export PUBDNS=$(aws ec2 describe-instances --filters "Name=tag:owner,Values=$OWNERTAG" "Name=tag:Name,Values=$NAMETAG-om" "Name=instance-state-name,Values=running" | jq -r '.Reservations[0].Instances[0].PublicDnsName')

echo "Public DNS is $PUBDNS; waiting for ssh"

sleep 1
nc -z $PUBDNS 22
until test $? -eq 0
do
  sleep 1
  printf "."
  nc -z $PUBDNS 22
done

# install mongo, shell, and OM rpms
ssh -i $KEYPATH -oStrictHostKeyChecking=no ec2-user@$PUBDNS <<EOF
sudo yum install -y $OM_VERSION
sudo yum install -y https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/RPMS/mongodb-org-server-4.4.6-1.amzn2.x86_64.rpm
sudo yum install -y https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/RPMS/mongodb-org-shell-4.4.6-1.amzn2.x86_64.rpm
sudo systemctl start mongod
sudo tee -a /opt/mongodb/mms/conf/conf-mms.properties <<-CONF_FILE
mms.ignoreInitialUiSetup=true
mms.centralUrl=http://$PUBDNS:8080
mms.https.ClientCertificateMode=none
mms.fromEmailAddr=admin@localhost.com
mms.replyToEmailAddr=admin@localhost.com
mms.adminEmailAddr=admin@localhost.com
mms.emailDaoClass=SIMPLE_MAILER
mms.mail.transport=smtp
mms.mail.hostname=localhost
mms.mail.port=25
mms.user.invitationOnly=true
CONF_FILE
sudo systemctl start mongodb-mms
EOF

if [ $? -eq 0 ]; then
  echo "Mongod and Ops Manager are installed, and starting. Host is $PUBDNS - We'll be creating the first user now when it's up"
else
  echo "Oops, something wrong happened"
  exit 1
fi

sleep 1
nc -z $PUBDNS 8080
until test $? -eq 0
do
  echo "Waiting"
  sleep 1
  nc -z $PUBDNS 8080
done

echo "Can connect to $PUBDNS:8080"

export MY_IP=$(curl ifconfig.me)
USERNAME=admin@localhost.com
PASSWORD=abc_ABC1
FIRST=Admin
LAST=Adminsson

echo "My IP is $MY_IP"

res=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"firstName\":\"$FIRST\",\"lastName\":\"$LAST\"}" \
 http://$PUBDNS:8080/api/public/v1.0/unauth/users\?whitelist\=$MY_IP)

PUBKEY=$(echo $res | jq -r '.programmaticApiKey.publicKey')
PRIVKEY=$(echo $res | jq -r '.programmaticApiKey.privateKey')

echo "API key is $PUBKEY:$PRIVKEY"


ORG_ID=$(curl --user "$PUBKEY:$PRIVKEY" --digest \
-s -X POST -H "Content-Type: application/json" \
--data "{\"name\":\"demo-org\"}" \
http://$PUBDNS:8080/api/public/v1.0/orgs | jq -r '.id')
echo "Org id: $ORG_ID"

# create project - for some reason it yields a 500, so we create and then list and get the new ID
res=$(curl --user "$PUBKEY:$PRIVKEY" --digest \
 -s -X POST -H "Content-Type: application/json" \
 --data "{\"name\":\"demo-project\",\"orgId\":\"$ORG_ID\"}" \
 http://$PUBDNS:8080/api/public/v1.0/groups)
AGENT_API_KEY=$(echo $res | jq -r '.agentApiKey')
PROJECT_ID=$(echo $res | jq -r '.id')

echo "Project is $PROJECT_ID, Agent API Key is $AGENT_API_KEY"

./launch-hosts.sh $PUBDNS $PROJECT_ID $AGENT_API_KEY



echo "-----"
echo "All servers started; go to http://$PUBDNS:8080 and log in with admin@localhost.com / abc_ABC1"
echo "Global owner API KEY: $PUBKEY:$PRIVKEY"
echo "Enjoy!"
open http://$PUBDNS:8080
