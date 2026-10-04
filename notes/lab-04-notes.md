# Lab 04 Notes - ECS

## Floci support path: A (with one gap)

Probe results (Step 3):

| Check | Result |
|---|---|
| ecs list-clusters | SUPPORTED |
| ecs register-task-definition | SUPPORTED |
| ecs describe-services | Answered with `ClusterNotFoundException` (the cluster "probe" does not exist). The probe printed "not available" only because the CLI exits non-zero on any error. The service itself is supported. |
| application-autoscaling describe-scalable-targets | SUPPORTED |
| application-autoscaling describe-scaling-policies | SUPPORTED |
| application-autoscaling describe-scheduled-actions | NOT SUPPORTED (`UnsupportedOperation`) |
| cloudwatch put-metric-data / describe-alarms / set-alarm-state | SUPPORTED |
| logs describe-log-groups | SUPPORTED |

Effect: ECS works, so every step in this lab is done as written.
Lab 06: scalable targets and scaling policies work, but scheduled scaling does not in this build. Use a documented fallback for that part.

## Challenges
- Private subnet b was `None` (Lab 2 Exercise 5 skipped). Fixed by completing the exercise.
- Step 3 probe falsely showed "not available" for describe-services (see above).

## Review questions (Section 14)

**1. "I put auto scaling on the task definition."**
That is wrong on three counts. Auto scaling is attached to the **service**, through a scalable target (`service/<cluster>/<service>`, dimension `ecs:service:DesiredCount`) in Lab 6. It changes only `desiredCount`, not the task definition, which is an immutable blueprint with no count. The ECS **service** is what makes reality match, by starting or stopping tasks until `runningCount` equals `desiredCount`. Because ECS itself knows nothing about the scalable target, `describe-services` shows no scaling information at all, and if the target were deleted the service would simply stay at whatever count it was last set to.

**2. One policy, two delivery mechanisms.**
On the EC2 instance, the instance profile makes temporary role credentials available to the instance. In the Fargate task, the task role does the same for the container. In both, the SDK fetches short-lived, automatically rotating credentials when it runs, so nothing is stored on disk. The moment the bucket exists, both start working with no change, because the policy already names its ARN.

**3. Execution role versus task role.**
If the **execution role** is wrong, the task never starts (the stopped reason mentions the image pull or logs). If the **task role** is wrong, the task starts and then the app gets AccessDenied. Both share the same trust policy because trust only says who may assume the role (the ECS tasks service), which is the same for both. What differs is the permissions attached to each.

**4. Why the security group rule uses a group, not a CIDR.**
Even with a fixed task count, tasks get new private addresses every time they are replaced (a deployment, a failure), and the web tier's addresses can change as well. A group rule says "anything in this group", which holds whatever the addresses are. Once Lab 6 lets the count change, new tasks and new addresses appear all the time, so a CIDR rule would keep going out of date.

**5. What Fargate removes from the EC2 model.**
It removes the instances: no choosing sizes, patching, SSH or capacity to manage. It does not remove the network: an `awsvpc` task still has its own network interface in my subnet, its own security group, and follows Lab 2's route tables (it needed the NAT gateway to pull its image). It also does not remove IAM roles or the VPC design.

**6. Persistence after a restart.**
A command that looks identical in memory and hybrid mode is `aws sts get-caller-identity`, because the account is fixed and says nothing about stored resources. One that would not is `aws ecs describe-services` for `usms-enrolment-svc` after a restart: in hybrid mode it is still ACTIVE with desired count 2, and in memory mode it would be gone. The difference is that identity is built in, while resources are stored state that has to be saved to disk.
