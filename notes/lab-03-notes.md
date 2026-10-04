# Lab 03 notes
An IAM policy is a statement about ARNs, not a reference to existing objects. The role
usms-ec2-app-role can already be granted access to arn:aws:s3:::usms-student-data even
though that bucket does not exist yet. The permission has no effect until Lab 4 creates
the bucket, and then usms-web-01 can use it with no access keys on the server.
