# Lab 03 notes
An IAM policy is a statement about ARNs, not a reference to existing objects. The role
usms-ec2-app-role can already be granted access to arn:aws:s3:::usms-student-data even
though that bucket does not exist yet. The permission has no effect until Lab 4 creates
the bucket, and then usms-web-01 can use it with no access keys on the server.

## Review questions (Section 14)

**1. The five things in Step 8: wrong or missing?**
- **Subnet:** a missing or non-existent subnet fails immediately. A wrong but valid subnet launches fine and is wrong silently (for example, an instance in the private tier with no public address).
- **Security group:** a non-existent ID fails immediately. A wrong group launches fine, and traffic is silently blocked or allowed.
- **Instance profile:** a non-existent name fails immediately. The wrong profile is silent until the app calls AWS and gets AccessDenied.
- **Key pair:** a non-existent name fails immediately. The wrong key is silent until I try to log in.
- **User data script:** always silent. The instance starts either way, and a missing or broken script only shows up as an app that isn't there.

So the immediate failures are the ones where a name or ID does not exist. The silent ones are wrong-but-valid choices and the script.

**2. A policy for a bucket that does not exist.**
It is valid because an IAM policy is a statement about ARNs, not a link to a real object. Today the instance holds the permission but has nothing to use it on, so an S3 call would fail with "no such bucket" and not "access denied". The moment `create-bucket` runs, `usms-web-01` can read and write it with no change to the role, the policy or the instance, and no key stored on the server.

**3. Putting deployment in user data.**
User data runs once, at first boot, so a restart does not run it again. Two approaches that do work: (1) bake the app into a new AMI and replace the instance from it; (2) deploy with a tool that can run on demand, such as SSM Run Command or CodeDeploy.

**4. Auto-assigned public IP versus Elastic IP.**
The auto-assigned address belongs to AWS's pool: it changes when the instance is stopped and started, and is released on stop. An Elastic IP belongs to my account: it stays the same until I release it, survives a stop, and costs money when it is not in use. Failover that only works with an Elastic IP: if `usms-web-01` fails, I re-attach the Elastic IP to a standby instance, and clients keep using the same address.

**5. EBS volumes versus snapshots across AZs.**
A volume lives inside one Availability Zone, while a snapshot is stored regionally, so it can be restored in any zone. To survive the loss of a zone, I need regular snapshots (or copies) and a plan to restore them in another zone. A single volume is not enough.

**6. Is verifying six properties enough?**
It is good evidence that the setup was built as intended, but it is not proof that the app works. It cannot detect runtime faults: the app crashing, a broken user data script, a service not listening on its port, or a firewall that behaves differently from how it reads.

**7. `usms-web-01` versus `usms-db-01`.**
| Difference | Web | DB | Belongs to |
|---|---|---|---|
| Subnet | public subnet a | private subnet a | the VPC (the subnet) |
| Public address | yes, plus an Elastic IP | none | the instance (assigned from the subnet's setting) |
| Security group | `usms-app-sg` | `usms-db-sg` | the instance |
| Instance profile | yes | none | the instance |
| User data | yes | none | the instance |
| Data volume | attached | none | the instance |
| Name and tags | `usms-web-01` | `usms-db-01` | the instance |
