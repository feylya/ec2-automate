#! /bin/bash

# Setup Amazon EC2 Command-Line Tools
EC2_HOME=~/.ec2
PATH=$PATH:$EC2_HOME/bin
COMPANY=swrve
EC2_PRIVATE_KEY=`ls ~/.ec2/pk-*.pem`
EC2_CERT=`ls ~/.ec2/cert-*.pem`
ELB_NAME=loadbalancer1

if [ $# -lt 3 ] ; then
	echo -e "Usage: $0 -n -z"
	echo -e "-i is a comma seperated list of Instances to Load Balance"
	echo -e "-n is the Load Balancer name"
	echo -e "-z is the Availability Zone"
	exit 1
fi

while [ $# -gt 1 ] ; do
	case $1 in
		-i) INSTANCES=$2 ; shift 2 ;;
		-n) ELB_NAME=$2 ; shift 2 ;;
		-z) EC2_REGION=$2 ; shift 2 ;;
		*) shift 1 ;;
	esac
done

ZONE="${EC2_REGION%?}"

# Create new load balancer
if [ `elb-describe-lbs --region $ZONE | grep $ELB_NAME | wc -l` -lt '1' ] ; then
	ELB_DNS_NAME=`elb-create-lb $ELB_NAME --listener "protocol=HTTP, lb-port=80, instance-port=80" --availability-zones ${ZONE}a,${ZONE}b,${ZONE}c,  --region $ZONE`
fi

ELB_DNS_NAME=`elb-describe-lbs --region $ZONE | grep $ELB_NAME | awk '{print $3}'`

echo The Load Balancer DNS name is $ELB_DNS_NAME

ADD_INSTANCES=`elb-register-instances-with-lb $ELB_NAME --region $ZONE --instances $INSTANCES`

