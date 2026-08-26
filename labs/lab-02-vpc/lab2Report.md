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

## 6. Results and Evidence

### 6.1 AWS Management Console Verification

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