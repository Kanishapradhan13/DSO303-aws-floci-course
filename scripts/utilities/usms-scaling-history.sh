#!/usr/bin/env bash
# Export the complete scaling configuration and history of every scalable target in the
# "ecs" namespace as one JSON document: outputs/lab-06-scaling-history.json
#
# Everything is discovered from the API: no resource ID, policy name or alarm name is typed here.
# Works from any directory (the repository root is found from this script's own path).
# A call that this Floci build does not implement is recorded in the document as an "error"
# string instead of aborting the export, so the file is always complete and valid JSON.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO_ROOT/outputs/lab-06-scaling-history.json"
mkdir -p "$REPO_ROOT/outputs"
export AWS_PROFILE="${AWS_PROFILE:-floci}"

python3 - "$OUT" << 'PY'
import datetime, json, subprocess, sys

out_path = sys.argv[1]

def aws(*args):
    """Run an AWS CLI call and return parsed JSON, or {"error": "..."} if it fails."""
    p = subprocess.run(["aws", *args, "--output", "json"], capture_output=True, text=True)
    if p.returncode != 0:
        msg = (p.stderr.strip().splitlines() or ["unknown error"])[-1]
        return {"error": msg}
    return json.loads(p.stdout) if p.stdout.strip() else {}

doc = {"generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}

targets = aws("application-autoscaling", "describe-scalable-targets", "--service-namespace", "ecs")
doc["scalableTargets"] = targets.get("ScalableTargets", targets)

doc["services"] = []
for t in (targets.get("ScalableTargets") or []):
    rid = t["ResourceId"]                      # service/<cluster>/<service>, taken from the target itself
    _, cluster, service = rid.split("/")
    svc = aws("ecs", "describe-services", "--cluster", cluster, "--services", service)
    svc_arn = (svc.get("services") or [{}])[0].get("serviceArn", "")
    policies = aws("application-autoscaling", "describe-scaling-policies",
                   "--service-namespace", "ecs", "--resource-id", rid).get("ScalingPolicies", [])
    scheduled = aws("application-autoscaling", "describe-scheduled-actions",
                    "--service-namespace", "ecs", "--resource-id", rid)
    activities = aws("application-autoscaling", "describe-scaling-activities",
                     "--service-namespace", "ecs", "--resource-id", rid,
                     "--include-not-scaled-activities")

    # Alarms: the managed ones (named after the resource ID), plus any alarm whose action is one of our policies.
    policy_arns = {p["PolicyARN"] for p in policies}
    all_alarms = aws("cloudwatch", "describe-alarms").get("MetricAlarms", [])
    alarms = [a for a in all_alarms
              if a["AlarmName"].startswith("TargetTracking-" + rid) or policy_arns & set(a.get("AlarmActions", []))]

    doc["services"].append({
        "resourceId": rid,
        "serviceArn": svc_arn,
        "desiredCount": (svc.get("services") or [{}])[0].get("desiredCount"),
        "scalingPolicies": policies,
        "scheduledActions": scheduled.get("ScheduledActions", scheduled),
        "alarms": [{"name": a["AlarmName"], "state": a["StateValue"], "namespace": a.get("Namespace"),
                    "metric": a.get("MetricName"), "threshold": a.get("Threshold"),
                    "comparison": a.get("ComparisonOperator"), "actions": a.get("AlarmActions", [])}
                   for a in alarms],
        "scalingActivities": activities.get("ScalingActivities", activities),
    })

# Derived from the service ARN: everything after its last colon is service/<cluster>/<service>.
doc["resourceId"] = doc["services"][0]["serviceArn"].rsplit(":", 1)[-1] if doc["services"] else None

with open(out_path, "w") as f:
    json.dump(doc, f, indent=2, default=str)
print(out_path)
PY
