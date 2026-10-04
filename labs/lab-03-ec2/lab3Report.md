# Lab 03 Report: Amazon EC2 and Deploying the USMS Application

---

## 1. Objectives

- Launch a web server (EC2 instance) inside the network built in Lab 2.
- Give it a key pair, a firewall, a permission role and a startup script.
- Give the web server a fixed public address (Elastic IP).
- Add extra storage (EBS volume) to the web server.
- Launch a database server in a private subnet with no public address.
- Prove the setup is correct and survives a restart.
- Save a ready-made copy of the web server (AMI).

---

## 2. Steps

### Setup

1. **Start Floci and load the settings files.** Checked all six Lab 2 values were filled in.  
    ![alt text](../../screenshots/lab3/s1.png)
2. **Check the Lab 2 network is still there.** Ran the Lab 2 verify script.  
   ![alt text](../../screenshots/lab3/s2.png)

### Preparing the launch

3. **Pick an image (AMI) for the server.**  
   ![alt text](../../screenshots/lab3/s3.png)
4. **Create a key pair.** The private key was saved straight to a file and locked with `chmod 600`.  
   ![alt text](../../screenshots/lab3/s4.png)
5. **Check the key is ignored by git**, so it can never be uploaded by mistake.  
   ![alt text](../../screenshots/lab3/s5.png)
6. **Write the startup script** (`user-data.sh`) that installs a web server (nginx) and a portal page on first boot. Syntax checked.  
   ![alt text](../../screenshots/lab3/s6.png)
7. **Write the launch request as a JSON file** and checked it was valid.  
   ![alt text](../../screenshots/lab3/s7.png)

### Web server

8. **Launch `usms-web-01`** in the public subnet with the app firewall, the permission role and the startup script.  
   ![alt text](../../screenshots/lab3/s8.png)
9. **Wait until it is running.**  
   ![alt text](../../screenshots/lab3/s9.png)
10. **Read the server's details back** and checked the subnet, firewall and role were correct.  
    ![alt text](../../screenshots/lab3/s10.png)
11. **Trace the permission chain:** instance, to profile, to role, to policy. The S3 bucket in the policy does not exist yet (Lab 4 creates it).  
    ![alt text](../../screenshots/lab3/s11.png)
12. **Check the startup script was stored.**  
    ![alt text](../../screenshots/lab3/s12.png)
13. **Attach an Elastic IP** so the public address does not change.  
    ![alt text](../../screenshots/lab3/s13.png)
14. **Test the website.** The request timed out, which is expected on Floci. Instead, checked all six links that must be true for a website to be reachable: running, route to internet gateway, gateway attached, port 80 open, public address, network ACL.  
     ![alt text](../../screenshots/lab3/s14a.png) 
    ![alt text](../../screenshots/lab3/s14b.png)

### Storage and database

15. **Create and attach an 8 GiB data volume** in the same zone as the server. Tried to attach a volume from the other zone to confirm it is refused, then deleted that test volume.  
    ![alt text](../../screenshots/lab3/s15a.png)
    ![alt text](../../screenshots/lab3/s15b.png)
    ![alt text](../../screenshots/lab3/s15c.png)

16. **Launch `usms-db-01`** in the private subnet with the database firewall and no role.  
    ![alt text](../../screenshots/lab3/s16.png)
17. **Prove the two tiers are connected correctly:** the database firewall accepts port 5432 only from the web firewall, and the private subnet has no route to the internet gateway.  
    
    ![alt text](../../screenshots/lab3/s17.png)

### Restart, image and records

18. **Stop and start the web server** and checked the Elastic IP stayed attached. Not terminated.  
    
    ![alt text](../../screenshots/lab3/s18a.png)
    ![alt text](../../screenshots/lab3/s18b.png)

19. **Restart Floci and check everything is still there** by looking it up by tag.  
    ![alt text](../../screenshots/lab3/s19.png)
20. **Create an AMI** (`usms-web-golden`) from the web server.  
    ![alt text](../../screenshots/lab3/s20.png)
21. **List everything the lab created** (instances, volumes, Elastic IPs, images).  
    ![alt text](../../screenshots/lab3/s21.png)

    ![alt text](../../screenshots/lab3/s21b.png)
22. **Write `configs/lab-03.env`** with the IDs for later labs and checked them against the real values.  
    ![alt text](../../screenshots/lab3/s22.png)
23. **Run the Lab 3 verify script.**  
    
    ![alt text](../../screenshots/lab3/s23.png)


---

## 3. Challenges

| # | Problem | Cause | Fix |
|---|---------|-------|-----|
| 1 | `permission denied` when running the Lab 2 verify script | The file was not marked executable | Ran `chmod +x` on it |
| 2 | The Lab 2 verify script printed nothing, then showed 4 fails after rebuilding it | The file was empty. After re-creating it from the lab, 2 fails were real: `USMS_PRIVATE_NACL` in the env file held the default ACL's ID, because Floci ignored the tag filter. The other 2 were expected (optional second-zone subnets not created) or a false alarm (the check flagged the safe `.env` files that only hold IDs) | Replaced the wrong ID in `configs/lab-02.env` with the correct one. Noted the other two |
| 3 | The user data check failed with a MISMATCH | Floci returned `None` instead of the stored script, so the comparison had nothing to decode | Confirmed locally that the script and its encoding (`IyEvYmluL2Jhc2gK` = `#!/bin/bash`) were correct. Real AWS would return it and match exactly |
| 4 | `configs/lab-03.env` had the wrong Elastic IP | The tag lookup returned the NAT gateway's Elastic IP instead of `usms-web-eip` | Compared the file with the real values, then corrected the ID and IP by hand |

### Floci differences noticed (not mistakes)

- Server addresses did not match the subnet range: private `172.19.0.x` instead of `10.0.1.x`, public `127.0.0.1`.
- The Elastic IP showed on the address record but the instance's own public address did not change.
- The website could not be reached because Floci does not run a real operating system.
- The wrong-zone volume attach **was** refused, as on real AWS (different error name).

### Skipped (optional)

- `usms-web-02` and the second-zone subnets, because those subnets were not created in Lab 2.

---

## 4. Conclusion

This lab built a two-tier setup: a web server in a public subnet and a database server in a private subnet. It used the network from Lab 2 and the permission role from Lab 1 in one launch command.

Main things learned:

- **A subnet is public only because of its route to an internet gateway.** The private subnet has no such route, so the database cannot be reached from the internet.
- **A security group can name another security group as its source.** The database only accepts traffic from the web tier, whatever its address.
- **An Elastic IP stays fixed. An automatic public IP does not.**
- **A data volume survives when the server is deleted, but the root volume does not.**
- **A volume must be in the same zone as its server.**
- **A policy can grant access to a bucket that does not exist yet.** It starts working in Lab 4.
- **Always check the results.** Several commands succeeded but returned the wrong resource (wrong NACL, wrong Elastic IP), which only showed up when the values were compared with the real ones.

The Floci emulator cannot run a real website or return user data, so those parts were proven by checking the configuration instead.