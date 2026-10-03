#!/usr/bin/env bash
# Lab 04 Exercise 3 - ECS configuration drift report.
# One line per service in the cluster; verdicts are computed from the live API, never from names or tags.
# Also writes the same data as JSON to outputs/lab-04-ecs-inventory.json.
#
# No -e on purpose: one service that fails to describe (or has no networkConfiguration)
# must not abort the whole report. Each lookup is handled explicitly instead.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/configs/course.env"
source "$REPO_ROOT/configs/lab-04.env" 2>/dev/null || true
: "${USMS_ECS_CLUSTER:=usms-ecs-cluster}"

OUT_JSON="$REPO_ROOT/outputs/lab-04-ecs-inventory.json"
mkdir -p "$REPO_ROOT/outputs"

rows="[]"
svc_arns=$(aws ecs list-services --cluster "$USMS_ECS_CLUSTER" --query 'serviceArns[]' --output text 2>/dev/null)

for arn in $svc_arns; do
  d=$(aws ecs describe-services --cluster "$USMS_ECS_CLUSTER" --services "$arn" \
        --query 'services[0].{n:serviceName,d:desiredCount,r:runningCount,t:taskDefinition,p:networkConfiguration.awsvpcConfiguration.assignPublicIp}' \
        --output json 2>/dev/null) || { echo "$arn  ERROR describing service"; continue; }

  name=$(jq -r '.n' <<<"$d");  desired=$(jq -r '.d // "N/A"' <<<"$d")
  running=$(jq -r '.r // "N/A"' <<<"$d")
  td_arn=$(jq -r '.t // empty' <<<"$d")
  # Floci may store a bare family name; resolve it to the real family:revision.
  if [ -n "$td_arn" ]; then
    td_arn=$(aws ecs describe-task-definition --task-definition "$td_arn" \
               --query 'taskDefinition.taskDefinitionArn' --output text 2>/dev/null || echo "$td_arn")
  fi
  taskdef="${td_arn##*/}"; [ -n "$taskdef" ] || taskdef="N/A"

  roles="N/A"
  if [ -n "$td_arn" ]; then
    exec_r=$(aws ecs describe-task-definition --task-definition "$td_arn" \
               --query 'taskDefinition.executionRoleArn' --output text 2>/dev/null)
    task_r=$(aws ecs describe-task-definition --task-definition "$td_arn" \
               --query 'taskDefinition.taskRoleArn' --output text 2>/dev/null)
    if   [ -z "$exec_r" ] || [ -z "$task_r" ] || [ "$exec_r" = None ] || [ "$task_r" = None ]; then roles="N/A"
    elif [ "$exec_r" = "$task_r" ]; then roles="SAME"
    else roles="SEPARATE"; fi
  fi

  case "$(jq -r '.p // "none"' <<<"$d")" in
    ENABLED)  publicip="RISK" ;;
    DISABLED) publicip="OK" ;;
    *)        publicip="N/A" ;;
  esac

  printf '%-20s desired=%s  running=%s  taskdef=%s  roles=%s  publicip=%s\n' \
    "$name" "$desired" "$running" "$taskdef" "$roles" "$publicip"

  rows=$(jq --arg n "$name" --arg d "$desired" --arg r "$running" --arg t "$taskdef" \
            --arg ro "$roles" --arg p "$publicip" \
            '. + [{service:$n,desired:$d,running:$r,taskdef:$t,roles:$ro,publicip:$p}]' <<<"$rows")
done

echo "$rows" | jq . > "$OUT_JSON"
