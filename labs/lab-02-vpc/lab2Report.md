# Lab Report: Lab 2 – Virtual Private Cloud (VPC) and Networking
**Course:** DSO303
**Lab Reference:** Lab 2 - VPC (AWS CLI + Floci local emulator)

---

## 1. Aim / Objective

Designing and implementing a two-level VPC network for the USMS (University Student Management System) by employing AWS CLI and validating the functioning of the network. The components required are subnet, route, internet gateway, NAT gateway, security group, network ACL, and S3 gateway endpoint.

---

## 2. Introduction

Amazon VPC (Virtual Private Cloud) is the network layer where all AWS resources such as EC2 instances, RDS databases, and VPC Lambda functions need to be hosted. The role of Amazon VPC is to provide an isolated and software-defined network where the user has full control over IP addressing, subnetting, routing, and traffic filtering. Main features include CIDR-based IP addressing, public and private subnets, internet and NAT gateways for internet traffic control, two independent layers of traffic filtering such as stateful security groups (instance level) and stateless network ACLs (subnet level), and VPC endpoints to privately connect with other AWS services such as S3. Amazon VPC is critical for cloud computing as this is the only boundary which ensures that sensitive resources (for example, database) are not reachable from the public internet while still being able to perform their function, and it is the first layer of cloud security architecture. Possible use cases include hosting a web tier publicly in a public subnet, placing a database tier in a private subnet, and minimizing costs and latency through routing traffic to AWS services such as S3.

---

## 3. Use Case

- Hosting a scalable and publicly accessible web application on Amazon EC2 in a public subnet.
- Keeping a database or data tier in a private subnet, not accessible from the internet.
- Providing private subnet resources with internet access for outgoing traffic (like OS updates) via a NAT gateway.
- Saving money and time by accessing Amazon S3 using a VPC gateway endpoint rather than the internet.

---

## 4. System Architecture / Design


---

## 5. Implementation Procedure

* **Step 1:** Resumed the Floci environment and verified storage persistence.

![alt text](../../screenshots/lab2/1.png)

* **Step 2:** Sourced `course.env` and `lab-01.env`, confirmed identity via `whoami.sh`.

* Reviewed CIDR notation and AWS's address-plan rules.

![alt text](../../screenshots/lab2/2.png)

* **Step 3:** Assumed `usms-developer-role` via STS and created the VPC (`usms-vpc`, `10.0.0.0/16`) as that role.

![alt text](../../screenshots/lab2/3.png)

![alt text](../../screenshots/lab2/3.2.png)

![alt text](../../screenshots/lab2/3.3.png)

* **Step 4:** Restored the normal identity and verified the VPC via `describe-vpcs`.

![alt text](../../screenshots/lab2/4.1.png)

* **Step 5:** Enabled DNS support and DNS hostnames on the VPC.

![alt text](../../screenshots/lab2/5.png)

* **Step 6:** Created and attached the internet gateway (`usms-igw`).

![alt text](../../screenshots/lab2/6.png)

* **Step 7:** Created the public subnet `usms-public-subnet-a` (`10.0.1.0/24`, us-east-1a).

![alt text](../../screenshots/lab2/7.png)

* **Step 8:** Enabled auto-assign public IPv4 on the public subnet.

![alt text](../../screenshots/lab2/8.png)

* **Step 9:** Created the private subnet `usms-private-subnet-a` (`10.0.3.0/24`, us-east-1a).

![alt text](../../screenshots/lab2/9.png)

* **Step 10:** Created the public route table with a default route to the internet gateway.

![alt text](../../screenshots/lab2/10.png)

* **Step 11:** Associated the public subnet with the public route table (and created a second public subnet in us-east-1b).

![alt text](../../screenshots/lab2/11.png)

* **Step 12:** Created the private route table and associated the private subnet.

![alt text](../../screenshots/lab2/12.png)

* **Step 13:** Verified the public vs. private subnets differ by reading back their effective routes.

![alt text](../../screenshots/lab2/13.png)

* **Step 14:** Created `usms-app-sg` (HTTP/HTTPS from internet, SSH from VPC only).

![alt text](../../screenshots/lab2/14.png)

* **Step 15:** Created `usms-db-sg`, sourcing PostgreSQL access from `usms-app-sg` (group-to-group rule).

![alt text](../../screenshots/lab2/15.1.png)

![alt text](../../screenshots/lab2/15.2.png)

* **Step 16:** Reviewed both security groups and reasoned through a stateful request/response flow.

![alt text](../../screenshots/lab2/16.png)

* **Step 17:** Explored the default network ACL, then created `usms-private-nacl` with explicit allow rules.

![alt text](../../screenshots/lab2/17.1.png)

![alt text](../../screenshots/lab2/17.2.png)

![alt text](../../screenshots/lab2/17.3.png)

* **Step 18:** Associated the private NACL with the private subnet.

![alt text](../../screenshots/lab2/18.png)

* **Step 19:** Allocated an Elastic IP and created the NAT gateway (`usms-nat`) in the public subnet.

![alt text](../../screenshots/lab2/19.png)

* **Step 20:** Pointed the private route table's default route at the NAT gateway.

![alt text](../../screenshots/lab2/20.png)

* **Step 21:** Created the S3 gateway endpoint and attached it to the private route table.

![alt text](../../screenshots/lab2/21.png)

* **Step 22:** Audited all resources for the `Project=USMS` tag using `describe-tags`.

![alt text](../../screenshots/lab2/22.png)

* **Step 23:** Proved the network survives a Floci restart (VPC ID, subnet count, security group count unchanged).

![alt text](../../screenshots/lab2/23.png)

* **Step 24:** Wrote `configs/lab-02.env` with all resource IDs for reuse in Lab 3.

![alt text](../../screenshots/lab2/24.png)

* **Step 25:** Verified `.gitignore` rules and committed the lab's work to Git.

![alt text](../../screenshots/lab2/25.png)

---

## 6. Review Questions

1. A colleague creates a subnet, names it public-subnet, tags it Tier=public, and turns on auto-assign public IPv4. Instances launched into it cannot reach the internet. Explain exactly what is missing, and explain why the name, the tag and the public IP address all failed to make it public. 

= What's missing is a route. The name, the tag, and the auto-assigned public IP are all just labels or settings — none of them actually connect the subnet to the internet gateway. The only thing that makes a subnet "public" is its route table having a `0.0.0.0/0` route pointing at an internet gateway. My colleague never created or attached that route, so no matter what they named it or tagged it, the subnet has no path out.

2. Security groups are stateful and network ACLs are stateless. Describe a specific USMS request path name the ports and the direction of each leg where that difference changes how many rules you must write. Then say which of the two you would reach for first when a new requirement arrives, and why.

= Take a web request hitting the app server on port 80, then the app server calling the database on port 5432. With security groups, I only write one rule per direction of a *new* connection — the reply traffic is automatically allowed back because security groups remember the connection. With a NACL, I'd have to write a rule for every leg separately, plus a matching return-traffic rule using ephemeral ports, because NACLs don't remember anything. So for a new requirement, I'd reach for a security group first — it's simpler, and NACLs are really more of a blunt, subnet-wide backup.


3. usms-db-sg allows PostgreSQL from usms-app-sg rather than from 10.0.1.0/24. Give two concrete changes to the USMS architecture that would silently break the CIDR-based version while leaving the group-referenced version correct.

= If someone later re-IPs the web servers or adds more of them in a new subnet, the CIDR-based rule would silently stop matching (or match too much) because it's tied to a fixed address range that no longer reflects where the app tier actually lives. Same thing if the web tier scales into a second AZ with a new CIDR block — the old rule wouldn't cover it. The group-referenced rule doesn't care about any of that, because it just asks "did this traffic come from an instance in usms-app-sg," so it keeps working automatically.


4. The NAT gateway sits in usms-public-subnet-a but exists to serve usms-private-subnet-a. Explain why it must be in the public subnet. Then explain what would happen to the private subnet in AZ b if AZ a became unavailable, and what that implies about where the availability boundary really sits.

= The NAT gateway has to sit in the public subnet because that's the only subnet with a route to the internet gateway — it needs that path to translate and forward traffic outward. If AZ a went down, the private subnet in AZ b would lose its outbound internet access too, even though its own instances are fine, because there's only one NAT gateway and it lives in AZ a. That tells me the real availability boundary in this design isn't the private subnet itself, it's wherever the single NAT gateway happens to be.


5. This lab created a gateway endpoint for S3. Describe the path a request from a private instance to usms-student-data takes with the endpoint, and the path it would take without one. Identify which path leaves the AWS network and what that costs in money and in exposure.

= With the S3 gateway endpoint, traffic from a private instance to the S3 bucket goes through a route that stays entirely inside AWS's network — it never leaves. Without the endpoint, that same traffic would have to go out through the NAT gateway to the public internet and back in to reach S3. That path costs extra NAT data-processing charges, and it briefly exposes transcript data to the public internet path instead of staying inside AWS.


6. Step 23 restarted Floci and looked the VPC up by tag rather than reusing the VPC_ID shell variable. Explain what specifically would not have been proven had the variable been reused. Relate your answer to the failure described in Lab 1 Step 14.

=  If I'd just reused the `VPC_ID` shell variable, all that would prove is that Bash still remembered a string — it says nothing about whether the VPC actually still exists in Floci after the restart. Looking it up by tag forces a real API call that only succeeds if the resource genuinely persisted. That's the same lesson as Lab 1 Step 14: don't check a proxy for the thing, check the actual thing.

7. Floci does not enforce security groups. Given that, explain how you can still be confident that the rules you wrote in Steps 14 and 15 are correct and describe one specific mistake that this lab's verification would catch and one that it would not.

= qEven though Floci won't actually block or allow real traffic, I can still trust the rules because I read them back with `describe-security-groups` and confirmed the exact ports, protocols, and sources are what I intended — that's a configuration check, not a traffic check. Verification would catch something like a wrong port number or a CIDR-based rule where I meant a group-based one, since that's visible in the returned rule set. What it would *not* catch is whether the rule actually blocks or allows real traffic correctly in practice, since Floci never sends real packets through it.

---

## 7. Analysis and Discussion

- **Accomplished:** Creation of full two-tier VPC network with public/ private subnets, routing, NAT, security group, NACL, and S3 endpoint using AWS CLI.
- **As Expected:** Passed all checkpoints (1-9) as expected; lastly, confirmed the architectural match using CLI.
- **Errors Experienced:** None – smooth build process, following the instructions from the guide step-by-step without any difficulties.
- **Resolution:** Not applicable – no critical errors to resolve.
- **Notes:** The distinction between "public" and "private" subnet is completely defined by its route table; there is no property of the subnet itself. The S3 gateway endpoint may not always add the prefix-list route to the route table, but the endpoint itself works fine.

---

## 8. Reflection

1. **What did you learn about this AWS service?**
   I learned that VPC networking is all about traffic control through route tables – the subnet is not public or private in itself, it's the attached route table that dictates whether the traffic is allowed to connect to the internet.

2. **What challenges did you encounter?**
   There were no issues with the build in general although there was a need to pay attention while connecting route table, NAT gateway, and NACL rule to the appropriate subnets since AWS does not separate them visually into public and private.

3. **How would you apply this service in a real-world cloud environment?**
   Exactly this setup with the public and private subnets is used when running a real application with public subnets for load balancers or web servers and private ones to hide databases and backend.

4. **What additional concepts or features would you like to explore?**
    I am interested in learning more about VPC Peering and Transit Gateway.

---

## 9. Conclusion

The practical created a full-fledged two-tier VPC architecture for a fictional university system by splitting the system into two subnets, namely, a public web tier and a private data tier, through the use of subnets, route tables, internet gateway, and NAT gateway. Security groups and network ACLs were used together to allow traffic at instance and subnet levels, respectively, while an S3 gateway endpoint was added to ensure that S3 traffic stayed within the AWS network only. Some important concepts covered through this practical include CIDR addressing, the use of routing table to determine public subnets, and the difference between stateful and stateless of security groups and NACLs.

---

## 10. Appendix (Optional)

- Policy files: `policies/usms-db-sg-ingress.json`
- Config files: `configs/lab-02.env`
- Scripts: `scripts/utilities/verify-lab-02.sh`, `scripts/cleanup/lab-02-cleanup.sh`
- Lab source: [Lab 2 – VPC (DSO303)](https://norbutlepcha25.github.io/dso303/Lab/Lab-02_VPC.html)