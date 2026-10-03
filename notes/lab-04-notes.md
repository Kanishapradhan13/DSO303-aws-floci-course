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
