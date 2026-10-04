# Lab 06 Notes - Auto Scaling

## Floci support path: B (control plane only, with two gaps)

From the Step 3 probe, checked by hand:
- **Supported:** `describe-scalable-targets` (returns an empty list), `describe-scaling-policies`, and the `register-scalable-target` and `put-scaling-policy` operations (only checked as skeletons so far), CloudWatch alarms, metric data and `set-alarm-state`, and the service-linked role operation.
- **Not supported:** `describe-scheduled-actions` and `describe-scaling-activities` both fail with `UnsupportedOperation`.

Effect: scalable targets and policies can be created and read back, but scheduled actions cannot be created at all (`PutScheduledAction` also fails with `UnsupportedOperation`), and no scaling activity history can be read. Step 12 used its control-plane fallback.

## What I observed on this Floci build
- Raising `MinCapacity` to 5 did not move `desiredCount`; the floor is stored but not enforced.
- Forcing the queue alarm to `ALARM` did not change `desiredCount` (it stayed at 2 for all ten polls), so the scaling loop does not run. The six-block proof in `outputs/lab-06-scaling-proof.txt` shows the wiring instead.
- Target tracking creates its two managed alarms each, but `describe-scaling-policies` shows an empty `Alarms` list for the step policy; the link exists only on the alarm's `AlarmActions`.
- Lowering the minimum back to 2 does not lower `desiredCount`; I set it back by hand.
- `lab-06.env`: the lab's `awk '{print \$NF}'` leaves `USMS_SCALABLE_RESOURCE_ID` empty, so I filled that line in by hand.


## Answers to the "Your turn" questions

**Step 6 (a).** The scalable target made the change: it enforces its own minimum when it is registered. It was not a scaling policy and not ECS, which only carried the new number out.

**Step 6 (b).** The cost is that five tasks run all night and all week instead of two, more than double the bill, and nobody knows why. `describe-scalable-targets` would have shown `MinCapacity: 5`.

**Step 8.** Four delays: alarm period times evaluations (60 s x 3 = 180 s), policy invocation (about 0 s), task start-up (20 to 60 s on real Fargate), and the 60 s grace period. That is about 260 to 300 seconds. The first I would change is the grace period, shortening it to match the measured start-up time; the cost is that a slow-starting task could be marked unhealthy and replaced in a loop.

**Step 11.** I could not do the one-off `at()` action because Floci rejects `PutScheduledAction`. An `at()` action does not remove itself after it fires, so a stale entry is left behind, and months later it can confuse someone or fire again. The runbook page that creates it should also contain `delete-scheduled-action`.

## Review questions (Section 14)

**1. The nine lines, and what this lab owns.**
(1) A student clicks Register. (2) Requests per target pass 1000, or the queue passes 100. (3) An alarm fires and invokes a policy. (4) The policy writes `desiredCount`, kept between 2 and 10. (5) ECS starts a task from `usms-enrolment:2`. (6) The task gets a network interface in a private subnet, with no public address. (7) `usms-enrolment-sg` admits port 80 from `usms-alb-sg` only. (8) The service registers the task's address in the target group. (9) The load balancer health-checks it and, after the 60-second grace period, sends it traffic.
This lab owns lines 2, 3 and 4. The other six needed no change because everything after the number is already driven by `desiredCount`: the task definition, the network settings, the firewall rule, the registration and the health checks were all built in Labs 4 and 5.
Auto scaling changes only how many copies of my application are running, not the application itself.

**2. The resource ID.**
The resource ID is the string `service/<cluster>/<service>`, which is the last part of the service's ARN. Application Auto Scaling works for many services, so it can't use one ARN format. It takes a namespace, a constructed resource ID and a dimension instead. For `dynamodb` the ID looks like `table/<table-name>`, and for `lambda` it looks like `function:<name>:<alias>`. Other constructed identifiers here: the ALB ResourceLabel (`app/<alb>/<id>/targetgroup/<tg>/<id>`, built from the load balancer ARN after `loadbalancer/` and the target group ARN after its last colon), and the managed alarm names (`TargetTracking-<resource id>-...`).

**3. Registering with a minimum of 2 against a one-task service.**
The scalable target made the change, by enforcing its minimum. A policy only reacts to a metric through an alarm and leaves an activity record, while a floor is a standing rule applied at once. At 3 a.m. an on-call engineer might raise the minimum to keep capacity during an incident, even while metrics lag. The evidence for the person at 8 a.m. is `describe-scalable-targets` showing the raised `MinCapacity`, plus a note in the incident record. On Floci this floor was stored but not enforced.

**4. Managed alarms versus mine.**
The two managed alarms belong to the target tracking policy: they are recreated when the policy changes, deleting one leaves a policy that no longer scales in one direction, and they cannot notify anything else. My alarm belongs to me: deleting it only stops that policy being triggered, and it can notify an SNS topic and use my own metric, period and thresholds. `breaching` is the better setting for missing data: if the queue metric stops arriving, the sender may be dead, so it is safer to treat that as a problem than to do nothing. It would go wrong if the metric is legitimately absent when the queue is empty, because the alarm would stay in `ALARM` and keep scaling out for no reason.

**5. Why reactive scaling is always late.**
A metric has to be published and aggregated, compared by an alarm, and turned into a policy action. The managed alarm waits 60 s x 3 = 180 s (mine 60 s x 1), the policy acts in seconds, ECS then starts a task (20 to 60 s), and the load balancer takes it only after the 60 s grace period. That is two to five minutes, served by existing capacity. Three consequences: the minimum is a latency decision (justifies `MinCapacity` 2), scale out eagerly and scale in slowly (justifies cooldowns of 60 s out and 300 s in), and for a known spike use scheduled scaling (justifies the 07:45 action, which Floci could not create).

**6. The CPU and request policies disagree.**
Scaling out takes the largest capacity any policy asks for, and scaling in happens only when every policy agrees. It is asymmetric because wrongly adding a task costs a little money, but wrongly removing one hurts users. Two target tracking policies on the same metric with different targets fight each other, because each pulls the count in a different direction. A step policy and a target tracking policy on one metric are the same mistake, since both react to one signal and undo each other's changes.

**7. Requests per target versus CPU.**
Three reasons: it measures the cause (requests) and not a symptom, it does not depend on a task's CPU reservation, and it moves the instant load does. CPU is better for CPU-bound work whose cost per request varies a lot. `ALBRequestCountPerTarget` would scale this service badly if a few requests were very expensive or very long, or if the real bottleneck were the database, so that more tasks only overload it. `TargetResponseTime` (or the database's CPU or connection count) would have warned me.
