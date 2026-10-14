# Lab 07 Report: Amazon EKS and the USMS Microservices

---

## 1. Objectives

- Create an EKS cluster and a node group inside the network built in Lab 2.
- Give the cluster and the nodes their own permission roles.
- Connect `kubectl` to the cluster.
- Deploy three small services (gateway, enrolment, results) from manifest files.
- Check that the services find each other by name.
- Do a rolling update and a rollback, and break a pod on purpose three times.
- Use a ConfigMap and a Secret.
- Prove the cluster survives a restart and save its details for Lab 8.

---

## 2. Steps

### Setup

1. **Start Floci and load the settings files.** Checked the storage mode, the earlier verify scripts and all four subnet IDs.  
   ![alt text](../../screenshots/lab7/s1a.png)
   ![alt text](../../screenshots/lab7/s1b.png)
2. **Check which EKS path this Floci build gives.** The `eks` commands answer, and `kubectl` and `k3d` are installed, so it is **Path A**. Wrote the answer in `notes/lab-07-notes.md`.  
   ![alt text](../../screenshots/lab7/s2.png)

### IAM roles and firewall

3. **Write the two trust policies.** The cluster role trusts `eks.amazonaws.com` and the node role trusts `ec2.amazonaws.com`.  
   ![alt text](../../screenshots/lab7/s3.png)
4. **Write the two permission policies** (cluster and node). Both are valid JSON, 3 and 5 statements.  
   ![alt text](../../screenshots/lab7/s4.png)
5. **Create the cluster role and the cluster security group** (port 443 from the VPC only).  
   ![alt text](../../screenshots/lab7/s5.png)
6. **Create the node role** and attached Lab 1's `USMSStudentDataReadWrite` to it. Three roles now carry that policy.  
   ![alt text](../../screenshots/lab7/s6.png)

### Cluster and nodes

7. **Write the cluster request as a JSON file.** All four subnets, plus the `_lb_ports_` tag that Lab 8 needs.  
   ![alt text](../../screenshots/lab7/s7.png)
8. **Create the cluster** while holding the developer role, then switched back to the normal identity.  
   ![alt text](../../screenshots/lab7/s8.png)
9. **Wait until the cluster is `ACTIVE`** and read its details back.  
   ![alt text](../../screenshots/lab7/s9.png)
10. **Print the Kubernetes version and the OIDC issuer.** The issuer is a URL on this build.  
    ![alt text](../../screenshots/lab7/s10.png)
11. **Create the node group** `usms-eks-nodes` in the two private subnets (min 2, max 4, desired 2).  
    ![alt text](../../screenshots/lab7/s11.png)
12. **Point `kubectl` at the cluster** and checked it can reach the API server.  
    ![alt text](../../screenshots/lab7/s12.png)
13. **Check the nodes and what `kubectl` is allowed to do.** One node is ready.  
    ![alt text](../../screenshots/lab7/s13.png)
14. **Create the namespace `usms`** and made it the default.  
    ![alt text](../../screenshots/lab7/s14.png)

### The three services

15. **Deploy `usms-enrolment`** (2 pods, a service and a ConfigMap). Both pods ready and two endpoints.  
    ![alt text](../../screenshots/lab7/s15.png)
16. **Call the service from a temporary pod.** It answered with its own pod name.  
    ![alt text](../../screenshots/lab7/s16.png)
17. **Deploy `usms-results`** (2 pods) and checked the endpoints.  
    ![alt text](../../screenshots/lab7/s17.png)
18. **Deploy `usms-gateway`** (1 pod). Five pods running in total.  
    ![alt text](../../screenshots/lab7/s18.png)
19. **Prove the names work from inside the cluster.** The names resolved to service addresses, the gateway reached both services, and 12 requests were answered by two different pods.  
    ![alt text](../../screenshots/lab7/s19.png)
20. **Delete one enrolment pod.** A new one appeared straight away and requests kept working.  
    ![alt text](../../screenshots/lab7/s20.png)

### ConfigMaps, Secrets and rollouts

21. **Create a Secret** from dummy values and moved the file out of the repository into `outputs/`, so it is ignored by git.  
    ![alt text](../../screenshots/lab7/s21.png)
22. **Show that a Secret is only encoded.** Decoded the token with `base64` using no key.  
    ![alt text](../../screenshots/lab7/s22.png)
23. **Give the Secret to the enrolment pods.** Checked the 4 `APP_` and 2 `ENROLMENT_` values inside the pod.  
    ![alt text](../../screenshots/lab7/s23.png)
24. **Change the version in the ConfigMap.** The running pods still said `1.0.0`.  
    ![alt text](../../screenshots/lab7/s24.png)
25. **Restart the Deployment** and the pods now said `1.1.0`.  
    ![alt text](../../screenshots/lab7/s25.png)
26. **Read the rollout history and roll back.** The pods still said `1.1.0` afterwards. Then set the ConfigMap back to `1.0.0`.  
    ![alt text](../../screenshots/lab7/s26.png)
27. **Change the image of `usms-results` and roll it back.** Peak of 3 pods, and two revisions in the history.  
    ![alt text](../../screenshots/lab7/s27.png)

### Breaking things on purpose

28. **Wrong image name.** The new pod went to `ImagePullBackOff` while the old pods kept serving. Rolled back.  
    ![alt text](../../screenshots/lab7/s28.png)
29. **A pod asking for too much.** It stayed `Pending` with `FailedScheduling`. Deleted it.  
    ![alt text](../../screenshots/lab7/s29.png)
30. **A container that exits straight away.** `CrashLoopBackOff`, and the log showed why. Deleted it.  
    ![alt text](../../screenshots/lab7/s30.png)
31. **Compare ECS and EKS side by side.** Filled in the comparison table in the notes.  
    ![alt text](../../screenshots/lab7/s31.png)

### IRSA, restart and records

32. **Try IRSA.** The cluster has an issuer URL and the provider was registered in IAM. Created the `usms-enrolment-sa` service account, but the role and token steps could not be finished here.  
    ![alt text](../../screenshots/lab7/s32.png)
33. **Record the state before the restart.**  
    ![alt text](../../screenshots/lab7/s33.png)
34. **Restart Floci and look everything up again.** Cluster, node group, namespace and the three Deployments all came back.  
    ![alt text](../../screenshots/lab7/s34.png)
35. **Write `configs/lab-07.env`** and checked it has 21 values and none are empty.  
    ![alt text](../../screenshots/lab7/s35.png)
36. **Run the Lab 7 verify script.** 29 passed, 1 failed (see Challenges).  
    ![alt text](../../screenshots/lab7/s36.png)

---

## 3. Challenges

| # | Problem | Cause | Fix |
|---|---------|-------|-----|
| 1 | `kubectl apply` failed with `TLS handshake timeout` | Ten other containers from other Kubernetes practice clusters (`dso202-*`, `kustomize-lab-*`) were using most of the CPU, so the API server answered too slowly | Saved the list of those containers, stopped them, and started again |
| 2 | The enrolment pods showed `CreateContainerConfigError`, then restarted once each | Same cause as above. The node was too busy, the config sync timed out and the probes failed | Did not re-apply anything. The pods recovered on their own once the CPU was free |
| 3 | Step 18 said to use `kubectl annotate` to start a rollout | That changes the Deployment's own labels and not the pod template, so it does not roll | Used `kubectl rollout restart` instead |
| 4 | After the rollback the pod still said `1.1.0` | `rollout undo` only reverts the pod template. The ConfigMap is a separate object and was still at `1.1.0` | Changed the ConfigMap back to `1.0.0` by hand and restarted |
| 5 | The Secret manifest would have been committed with a base64 value | `kubectl create secret ... > file` writes the value into the repo folder | Moved it to `outputs/` and checked it is ignored by git |
| 6 | The verify script showed `FAIL=1` | The "no secret is tracked by git" check flags `outputs/.gitkeep`, which is only an empty placeholder | Noted it as a false alarm, same as in earlier labs |

### Floci differences noticed (not mistakes)

- Only **one node** ran, so the node group's desired size of 2 (`t3.small`) is recorded but not real. All pods were on the same node.
- The cluster had an OIDC issuer URL, but it is a local one that real AWS cannot reach, so IRSA could not be finished.
- Roles and policies are stored but not checked, so a wrong trust policy would not have been noticed.
- Floci runs the cluster as a real Kubernetes node inside Docker, which is why the other clusters on the machine affected it.

---

## 4. Conclusion

This lab built an EKS cluster with a node group in the Lab 2 network, and ran three small services on it. The gateway found the other two services by name only, and traffic was shared between two pods. It also covered a rolling update, a rollback, a Secret, three kinds of failure, and a restart of Floci.

Main things learned:

- **EKS has two halves.** The control plane is run by AWS, but the nodes are mine. A cluster can be `ACTIVE` and still run nothing.
- **The cluster role and the node role are different.** They trust different services (`eks` and `ec2`) and cannot be swapped.
- **A Service gives a fixed name and address.** The pods behind it can be replaced and the gateway never notices.
- **Changing a ConfigMap does not restart the pods.** The pod template has to change, or the Deployment has to be restarted.
- **`rollout undo` rolls back the pod template only.** The ConfigMap stays as it was, so configuration should be versioned with the application.
- **A Secret is only encoded, not encrypted.** Anyone who can read it can decode it, so its manifest must never be committed.
- **`describe` shows why a pod is failing.** `ImagePullBackOff`, `Pending` and `CrashLoopBackOff` each looked different and needed a different fix.
- **A busy machine causes failures that look like bugs.** The API timeouts and the pod restarts were caused by the other clusters using the CPU, not by the manifests.

Floci runs a single node and cannot finish IRSA, so those parts were checked from the configuration instead.
