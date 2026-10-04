#!/usr/bin/env bash
# Print the ALBRequestCountPerTarget ResourceLabel for a load balancer and a target group.
# Usage: usms-resource-label.sh [load-balancer-name] [target-group-name]
# Defaults to this course's usms-enrolment-alb and usms-enrolment-tg.
# Both ARNs are looked up from the API; nothing is hard-coded or read from configs/lab-05.env.
# Works from any directory: it needs only the AWS CLI profile, not any repo-relative path.
set -uo pipefail

export AWS_PROFILE="${AWS_PROFILE:-floci}"
LB_NAME="${1:-usms-enrolment-alb}"
TG_NAME="${2:-usms-enrolment-tg}"

LB_ARN=$(aws elbv2 describe-load-balancers --names "$LB_NAME" \
           --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" \
           --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

if [ -z "$LB_ARN" ] || [ "$LB_ARN" = "None" ] || [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
  echo "ERROR: could not find load balancer '$LB_NAME' or target group '$TG_NAME'" >&2
  exit 1
fi

# The two suffixes need different treatment:
#  - the load balancer suffix must DROP the literal "loadbalancer/" word, so it starts at "app/...";
#    '#*:loadbalancer/' removes the shortest prefix ending in ":loadbalancer/".
#  - the target group suffix must KEEP the word "targetgroup/", so we only remove the
#    account/region part up to the last colon; '##*:' removes the longest prefix ending in ":".
LB_SUFFIX="${LB_ARN#*:loadbalancer/}"
TG_SUFFIX="${TG_ARN##*:}"
LABEL="${LB_SUFFIX}/${TG_SUFFIX}"

# Sanity checks: both names present, exactly six slash-separated segments, first segment "app".
IFS='/' read -r -a PARTS <<< "$LABEL"
if [ "${#PARTS[@]}" -ne 6 ] || [ "${PARTS[0]}" != "app" ] \
   || [[ "$LABEL" != *"$LB_NAME"* ]] || [[ "$LABEL" != *"$TG_NAME"* ]]; then
  echo "ERROR: implausible label '$LABEL' (${#PARTS[@]} segments)" >&2
  exit 1
fi

echo "$LABEL"
