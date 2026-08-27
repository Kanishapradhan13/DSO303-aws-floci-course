#!/usr/bin/env bash
# Print one line per subnet in usms-vpc: name, CIDR, AZ, PUBLIC/PRIVATE/ISOLATED
# derived strictly from the subnet's route table — never from tags.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
source "$REPO_ROOT/configs/lab-01.env" 2>/dev/null || true
source "$REPO_ROOT/configs/lab-02.env" 2>/dev/null || true

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=usms-vpc" \
  --query 'Vpcs[0].VpcId' --output text)

SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].SubnetId' --output text)

for s in $SUBNET_IDS; do
  name=$(aws ec2 describe-subnets --subnet-ids "$s" \
    --query 'Subnets[0].Tags[?Key==`Name`]|[0].Value' --output text)
  cidr=$(aws ec2 describe-subnets --subnet-ids "$s" \
    --query 'Subnets[0].CidrBlock' --output text)
  az=$(aws ec2 describe-subnets --subnet-ids "$s" \
    --query 'Subnets[0].AvailabilityZone' --output text)

  rt=$(aws ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=$s" \
    --query 'RouteTables[0].RouteTableId' --output text)

  target=$(aws ec2 describe-route-tables --route-table-ids "$rt" \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0]' --output json)

  if echo "$target" | grep -q '"GatewayId": "igw-'; then
    gw=$(echo "$target" | grep GatewayId | cut -d'"' -f4)
    status="PUBLIC     via $gw"
  elif echo "$target" | grep -q '"NatGatewayId": "nat-'; then
    gw=$(echo "$target" | grep NatGatewayId | cut -d'"' -f4)
    status="PRIVATE    via $gw"
  else
    status="ISOLATED   no default route"
  fi

  printf '%-24s %-16s %-12s %s\n' "$name" "$cidr" "$az" "$status"
done
