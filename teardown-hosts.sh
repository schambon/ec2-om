export AWS_PAGER=""

source config.sh

inst=$(aws ec2 describe-instances --filters "Name=tag:owner,Values=$OWNERTAG" "Name=tag:Name,Values=$NAMETAG-instances" "Name=instance-state-name,Values=running" | jq -r '.Reservations[].Instances[].InstanceId')
aws ec2 terminate-instances --instance-ids $inst
