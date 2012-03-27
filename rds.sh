#! /bin/bash

# Setup Amazon EC2 Command-Line Tools
EC2_HOME=~/.ec2/rds
EC2_PRIVATE_KEY=`ls ~/.ec2/pk-*.pem`
EC2_CERT=`ls ~/.ec2/cert-*.pem`
AWS_CREDENTIAL_FILE=~/.ec2/rds/credential-file-path.template
EC2_REGION=eu-west-1
EC2_URL=https://ec2.eu-west-1.amazonaws.com

INSTANCE_TYPE=db.m1.small

if [ $# -eq 0 ] ; then
	echo -e "Usage: $0 -n -c -e -u -p -s -z"
	echo -e "-n is the name of the Database"
	echo -e "-c is the class of the DB (db.m1.small)"
	echo -e "-e is the DB Engine (mysql)"
	echo -e "-u is the DB User"
	echo -e "-p is the DB Password"
	echo -e "-s is the DB Size (5)"
	echo -e "-z is the Availability Zone (eu-west-1)"
	exit 1
fi

while [ $# -gt 1 ] ; do
	case $1 in
		-n) DBNAME=$2 ; shift 2 ;;
		-c) DBCLASS=$2 ; shift 2 ;;
		-e) DBENGINE=$2 ; shift 2 ;;
		-u) DBUSER=$2 ; shift 2 ;;
		-p) DBPASSWORD=$2 ; shift 2 ;;
		-s) DBSTORAGE=$2 ; shift 2 ;;
		-z) EC2_REGION=$2 ; shift 2 ;;
		*) shift 1 ;;
	esac
done

# Don't try to recreate the DB if it already exists!
if [ `rds-describe-db-instances $DBNAME --region $EC2_REGION | grep 'not found' | wc -l` -gt '1' ] ; then
	DBCREATE=`rds-create-db-instance $DBNAME --db-instance-class $DBCLASS --engine $DBENGINE --master-username $DBUSER --master-user-password $DBPASSWORD --allocated-storage $DBSTORAGE --region $EC2_REGION`
fi

# We gotta wait for the instance to be live before we push anything
# It takes a while...
times=0
while [ 20 -gt $times ] && ! rds-describe-db-instances $DBNAME --region $EC2_REGION| grep "DBINSTANCE" | grep "available" 1> /dev/null
do
  times=$(( $times + 1 ))
  echo Attempt $times at verifying $DBNAME is running...
  sleep 15
done

# Get URL and Port from the newly created DB
read DBHOSTNAME DBPORT <<<$(rds-describe-db-instances $DBNAME --region $EC2_REGION | grep DBINSTANCE | awk '{print $9,$10}')

echo DBHostname=$DBHOSTNAME 
#echo DBPORT=$DBPORT
