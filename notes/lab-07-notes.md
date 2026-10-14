## Lab 07 support path
Probed on 2026-10-16T09:56:54Z
PATH A  - use aws eks throughout

## Step 3 - "EKS is just ECS with different names"
That is false because EKS has a data plane I run myself: the worker nodes are EC2 instances in my account that I have to size and patch, and a cluster with no node group runs nothing, whereas ECS on Fargate hides all of that. It is nearly true in the sense that both do the same job (keep the wanted number of copies of a container running, replace failed ones, and register them with a load balancer), and in both I describe the wanted state and the system makes reality match.

## Floci observations
- Floci's EKS runs a **single k3s node**, so the node group's desired size of 2 (`t3.small`) is recorded as an AWS object but not realised. Pods all share one node.
- The Kubernetes API server timed out while other Kubernetes clusters (the `dso202-*` and `kustomize-lab-*` containers) were running on the same machine and using most of the CPU. Pods failed their probes and restarted once, and `CreateContainerConfigError` appeared briefly. Stopping the other clusters fixed it.

## Step 20 - ECS and Kubernetes, compared with both running

| Question | ECS answer | Kubernetes answer |
| --- | --- | --- |
| What holds the container spec? | A task definition (`usms-enrolment:2`), an immutable, numbered revision | The Deployment's pod template (plus ConfigMaps for configuration) |
| What keeps N copies alive? | The ECS service, which keeps `runningCount` equal to `desiredCount` | The ReplicaSet created by the Deployment |
| What gives it a stable name? | The Application Load Balancer's DNS name | A Service, with a fixed ClusterIP and a DNS name |
| How does another service find it? | Through the load balancer's name (or a service discovery name I did not set up) | Cluster DNS: `usms-enrolment.usms.svc.cluster.local` |
| What does a rolling update create? | A new deployment, with tasks started from the new task definition revision | A new ReplicaSet, scaled up as the old one scales down |
| Where does rollback state live? | In the old task definition revisions, which are kept; I point the service back at one | In the old ReplicaSets, kept up to `revisionHistoryLimit`; `kubectl rollout undo` scales one back up |
| Which IAM role does the app code use? | The task role (`usms-ecs-task-role`) | The node role today (`usms-eks-node-role`), shared by every pod; the finer way is IRSA, one role per ServiceAccount |
| What would I have to change to move to another cloud? | Nearly everything: task definitions, services, roles and the load balancer are all AWS-specific | The manifests mostly move as they are; the IAM roles, VPC, node groups and load balancer annotations would have to be redone |

For USMS I would choose ECS on Fargate: it is simpler, has no nodes to patch, and the three services are small. I would choose Kubernetes if the team needed to run on more than one cloud, or if the number of services and the tooling around them grew a lot.

## Answers to the "Your turn" questions

**Step 9 - OIDC issuer.** The command printed `1.30` and an https URL (`https://oidc.eks.us-east-1.amazonaws.com/id/...`), so this build gives the cluster an issuer, which is more than most. The OIDC issuer is how the cluster identifies the tokens it signs for its pods, so that IAM can be told to trust a specific Kubernetes service account.

**Step 16.** The replacement for the deleted `usms-enrolment` pod was created by the **ReplicaSet**, not by the Deployment and not by me.

**Step 18 (usms-results image roll).** After the rollback, `kubectl rollout history` shows **two revisions** (2 and 3), and the Deployment is back on its original image. At the peak there were **three pods**: the two old ones still running and one new one being created. This did not look different from `usms-enrolment`, which also peaks at 3. With only two replicas, the default 25% rounds down to zero unavailable pods and up to one extra pod, so the default behaves like `maxUnavailable: 0`, `maxSurge: 1`. The difference only shows with more replicas.

**Step 21 - IRSA.** Of the six IRSA steps: (1) the cluster published an issuer, yes; (2) I registered it in IAM as an OpenID Connect provider, yes (a provider ARN was returned); (3) the role whose trust policy accepts the service account, not done; (4) I created the `usms-enrolment-sa` ServiceAccount but did not annotate it, because there is no role yet; (5) and (6) the token injection and `AssumeRoleWithWebIdentity` could not be completed, since the issuer is a local one that real STS cannot reach. Until IRSA works, the node role gives its permissions to every pod on the node.

## Review questions (Section 14)

**1. Cluster `ACTIVE` but every pod `Pending`.**
The control plane (run by AWS) and the data plane (the nodes I run) are separate, so the first can be healthy while the second does not exist or cannot take pods. Two causes: no node group was created, so there are no nodes to schedule on; or the nodes exist but cannot join, for example a node role missing the permission to describe the cluster. A third, which I met myself, is a node so short of CPU that it drops out and pods cannot start.

**2. Swapping the two trust policies.**
The cluster role would trust EC2, so the EKS control plane could not assume it. On real AWS, `create-cluster` in Step 8 would fail. The node role would trust EKS, so the EC2 instances could not assume it, and the node group in Step 10 would fail to create or its nodes would never join, so `kubectl get nodes` in Step 11 would show nothing. Floci does not enforce trust, so I would not have noticed anything.

**3. Readiness versus liveness.**
Readiness decides whether a pod receives traffic from its Service (a failing pod is taken out of the endpoints, but kept running). Liveness decides whether the container is killed and restarted. If a load-sensitive check is wired to liveness, a busy pod fails the check and is restarted, leaving fewer pods and even more load: a restart storm. I saw a mild version of this when the node was starved of CPU: the probes timed out and containers restarted.

**4. The rollback that still said 1.1.0.**
`rollout undo` reverts the Deployment's pod template, but the ConfigMap is a separate object, and it was still at 1.1.0. For a release that changes an image and its configuration, it only recovers the image, so it is not a complete rollback. The practice that fixes it is versioning configuration together with the workload, for example giving the ConfigMap a versioned name (or a hash of its contents) that the pod template refers to, so that changing the configuration changes the template and a rollback restores both.

**5. `maxUnavailable: 0` versus the default.**
With `maxUnavailable: 0` and `maxSurge: 1`, Kubernetes starts a new pod first and never goes below two ready pods, which suits a customer-facing API such as the enrolment service. The default (25% and 25%) lets a few pods be unavailable at once on larger deployments, which suits an internal or less critical service where speed matters more. For two replicas, the default rounds to the same thing, as I saw. `maxUnavailable: 0` is closer to Lab 4's ECS configuration of a minimum healthy percent of 100 and a maximum of 200.

**6. "A Secret is encrypted, so it is fine to commit."**
A Secret is only base64-encoded, which anyone can decode, as I did in Step 17. It keeps the value out of the image, can be restricted separately with RBAC, and is hidden from `kubectl describe`. It does not give confidentiality at rest, and a committed manifest stays in Git history forever. On real EKS I would turn on envelope encryption of Secrets with KMS, use IRSA and a secrets manager instead of stored credentials, and never commit the manifest. I moved my Secret file into the git-ignored `outputs/` folder.

**7. ECS or Kubernetes for USMS.**
I would choose ECS on Fargate. USMS is a small team in one region, quiet for eight months, and busy for two: Fargate has no nodes to patch and pay for, and the scaling from Lab 6 handles the busy months, while an EKS cluster costs per hour even when idle. Lab 7 was harder than Lab 4 in several ways: two extra IAM roles and a node group, `kubectl` and kubeconfig tooling, node CPU and memory limits (which caused my probe failures), and IRSA, which was complicated and could not be completed. What Kubernetes gave me that ECS could not was portability: I ran the same manifests on a local cluster, and the built-in DNS names for services made service discovery simple.
