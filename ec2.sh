#! /bin/bash

# Setup Amazon EC2 Command-Line Tools
EC2_PRIVATE_KEY=`ls ~/.ec2/pk-*.pem`
EC2_CERT=`ls ~/.ec2/cert-*.pem`
EC2_REGION=eu-west-1
EC2_URL=https://ec2.eu-west-1.amazonaws.com
EC2_ACCESS_KEY=<ACCESS_KEY>
EC2_SECRET_KEY=<SECRET_KEY>

KEYPAIR=ec2_key

# Amazon imagine
AMI=ami-953b06e1

EC2_CLASS="t1.micro"

ELB_NAME=dashboard
RDS_NAME=dashboard


# Create keypair
if [ `ec2-describe-keypairs --region $EC2_REGION | grep $KEYPAIR | wc -l` != '1' ] 
then
	ec2-add-keypair $KEYPAIR --region $EC2_REGION  | grep -v KEYPAIR > $KEYPAIR
	chmod 600 $KEYPAIR
fi


# ---------------
# Bring up RDS DB
# ---------------

#Database creation time
DATABASE=`./rds.sh -n $RDS_NAME -c db.m1.small -e mysql -u dashboard -p d4shb04rd -s 5 -z $EC2_REGION`
DBHOSTNAME=`echo $DATABASE | grep DBHostname | cut -d = -f 2`
#DBPort=`echo $DATABASE | grep DBPORT | cut -d = -f 2`

# List OS types
# ami-31814f58 is the 32bit Amazon Ubuntu clone
# Could use the next line to pick an AMI but that's beyond the scope for now
# echo `ec2-describe-images -o amazon | grep -E -v -i 'paid|windows' | awk '{print $2, $3, $7}'`\n
INSTANCE_NUMBER=`ec2-run-instances $AMI -k $KEYPAIR -t $EC2_CLASS --region $EC2_REGION  | grep INSTANCE | awk '{print $2}'`

echo The instance number is $INSTANCE_NUMBER

read ADDRESS ZONE<<<`ec2-describe-instances --region $EC2_REGION  | grep $INSTANCE_NUMBER | awk '{print $4,$11}'`

#Sometimes, the address comes back incorrectly because it hasn't been provisioned yet
#Retry if that happens
times=0
while [ $ADDRESS == 'pending' ]
do
	times=$(( $times + 1 ))	
	echo Waiting for address
	ADDRESS=`ec2-describe-instances --region $EC2_REGION  | grep $INSTANCE_NUMBER | awk '{print $4}'`
	sleep 5
done

if [ $times == 10 ]
then
	echo Failed to get address. Please check.
	exit 1
fi


echo The address is $ADDRESS

# We gotta wait for the instance to be live before we push anything
times=0
while [ 10 -gt $times ] && ! ec2-describe-instance-status $INSTANCE_NUNMBER --region $EC2_REGION | grep INSTANCESTATUS | grep passed 1> /dev/null
do
  times=$(( $times + 1 ))
  echo Attempt $times at verifying $INSTANCE_NUMBER is running...
  sleep 15
done

if [ $times == 10 ]
then
	echo Failed to provision correctly - please check
	exit 1
fi

# SSH takes a while to come up. Let's wait for it
times=0
while [ 10 -gt $times ] && ! ssh -t -o StrictHostKeyChecking=no -i $KEYPAIR ec2-user@$ADDRESS 'w' 2> /dev/null
do
  times=$(( $times + 1 ))
  echo Waiting for SSH to come up - attempt $times
  sleep 15
done

if [ $times == 10 ]
then
	echo Failed to connect
	exit 1
fi

# Disable Host Key Checking cos it's annoying Don't use in prod of course
scp -o StrictHostKeyChecking=no -i $KEYPAIR installer.sh ec2-user@$ADDRESS:

# Copy over the tarball
scp -o StrictHostKeyChecking=no -i $KEYPAIR dashboard.tar.gz ec2-user@$ADDRESS:

# -t fakes a tty which gets past the requirestty setting in sshd.conf
ssh -t -o StrictHostKeyChecking=no -i $KEYPAIR ec2-user@$ADDRESS 'chmod +x installer.sh && ./installer.sh'

#Let's add the instance to the LB
# ./elb.sh -i $INSTANCE_NUMBER -z $ZONE -n $ELB_NAME

echo The Server address is $ADDRESS
