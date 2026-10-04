# Lab 05 Notes - ALB in front of ECS

## Floci support path: B (control plane only)

Every load balancer object could be created and read back (load balancer, target group, listener, rule, security groups). There was no data path: the load balancer name did not resolve, so no request could be sent. The ECS service never registered any targets, so the target group stayed empty. Everything in the lab was proved from control-plane facts instead.

## Floci limitations seen
- `update-service --load-balancers` was accepted and silently ignored. `create-service` stored it, so the service was recreated.
- `healthCheckGracePeriodSeconds` is never stored (it reads `None`).
- Targets are never registered, so target health stays empty.
- `revoke-security-group-ingress` by rule ID returns `true` but does nothing. Revoking with the original JSON file worked.
- `describe-security-group-rules` still lists a removed rule. `describe-security-groups` is the reliable view.
- The server-side `instance.group-id` filter is ignored, so I filter on the client side.

## Answers to the "Your turn" questions

**Step 4 - HTTPS.** A security group rule only opens port 443; it does not make anything listen on it. Two things are missing for HTTPS: an HTTPS listener, and a TLS certificate. AWS can give a certificate for free (AWS Certificate Manager), but the listener needs a domain name that I have to obtain and prove I own from somewhere else.

**Step 6 (a).** An application that always answers with a redirect (for example, a home page that sends a 301 to a login page) would be reported as unhealthy forever by the strict 200 matcher, even though it works.

**Step 6 (b).** It would be a bug in the script, not in my work, if the matcher had been left at 200-399 on purpose. A verification script exists to check what I intended to build, so when the intent changes, the script has to change with it.

**Step 11.** Without the service registering its own targets, I would have to register every new task and deregister every stopped one by hand after each scaling event.

## Review questions (Section 14)

**1. What do the security group rule and the load balancer have in common?**
Both exist because the tasks have no stable addresses. Instead of pointing at an address that keeps changing, I point at something stable that stands in for them: a group (the rule says "anything in this group") or a load balancer (the front door). The general problem is late binding: letting a caller refer to a name or a role, and finding the current members only when needed. A third solution is DNS, which lets people use one name while the numbers behind it change.

**2. "The health check says the task is unhealthy, so the application is broken."**
That is unsound because the target group's health check only sees the result of a request over the network. It cannot tell the difference between the application being broken and the network path being broken (for example, a missing security group rule). The ECS `healthStatus` field, which comes from a check run inside the task, does tell them apart. My diagnostic sequence: compare ECS health with target health. If ECS says HEALTHY and the target says unhealthy, the path is the problem, so I check the security group rule from Step 9, the health check path and the matcher, in that order. If both say unhealthy, the application is broken, so I read the container logs.

**3. No `update-target-group-target-type`.**
It shows that some settings define what an object *is* and cannot change, while others are just configuration. This is like Lab 4's task definition revisions, which are immutable: to change one, I make a new one. Two other fields in this lab that behave the same way are the load balancer's type and scheme (application and internet-facing), and the target group's VPC and name. One that looks like it should be fixed but is not is the health check matcher: I changed it from 200 to 200-399 and back in Step 6, and it took effect immediately.

**4. A request arrives just as ECS stops the task.**
The timers are: ECS deregisters the task first, and then the load balancer drains it for `deregistration_delay.timeout_seconds` (30 seconds, set on the target group). After that ECS sends SIGTERM and waits `stopTimeout` (set in the task definition) before sending SIGKILL. `minimumHealthyPercent`, set on the service, keeps enough other tasks running during the change. The request succeeds if it was already in flight and finishes within the 30 seconds. A request that arrives after draining begins is sent to another task instead. If the delay were left at 300 seconds, the old task would linger for up to five minutes, which makes deployments and scale-in much slower, and a fast API gains nothing from the wait.

**5. Step 13 made Lab 4's verify script fail.**
For updating it immediately: a script that fails all the time teaches everyone to ignore failures, and on a real system the check should change in the same commit as the change it describes. For leaving it failing and documented: Lab 4's script is a record of what Lab 4 built, and changing it just to make it green hides that the design changed. With four other engineers, I would update it right away, with a note explaining why, because a permanent red check would hide real problems from the whole team. One engineer might change my answer by pointing out that the script is also used as marked evidence of Lab 4, so it should stay as it was and be fixed in a separate, labelled change.

**6. Internet-facing, yet the tasks have no public address.**
The load balancer sits in `usms-public-subnet-a` and `usms-public-subnet-b`. Their route table `usms-public-rt` sends `0.0.0.0/0` to `usms-igw`, so the internet can reach it. The tasks sit in `usms-private-subnet-a` and `usms-private-subnet-b`, whose route table `usms-private-rt` has no route to the internet gateway (it goes out through `usms-nat` only), and the service has `assignPublicIp` set to DISABLED. The tasks' security group only admits `usms-alb-sg`. An attacker who changed the load balancer's configuration could redirect or alter what it forwards, and could reach whatever `usms-alb-sg` can reach, which is the tasks on port 80 only. If the tasks had public addresses, they would be directly reachable from the internet, and a single mistaken firewall rule would expose them without the load balancer in the way.

**7. Requests per target versus CPU.**
Requests per target measures the demand itself, and it rises the moment traffic arrives, while CPU only rises after the tasks are already working hard, which is too late for the first minutes of an enrolment rush. CPU is the better signal when the work is CPU-heavy and the cost per request varies, or when much of the load does not come through the load balancer at all (for example, background jobs). `ALBRequestCountPerTarget` would scale the enrolment application badly if its requests vary a lot in cost (a few expensive requests look the same as many cheap ones), if requests are very long-lived, or if the real bottleneck is the database, so that adding tasks just overloads it more.
