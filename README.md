### Requirements

* Python 2.7
* Terraform
* AWS keys configured

### Setup

* Zip up lambda code: `zip modify_elastic_volume.zip modify_elastic_volume.py`
* Run terraform: `terraform apply`

### Testing

* Let all resources come up and verify EC2 instance's alarm status as "OK"
* SSH into the EC2 instance and fill up the disk space: `fallocate -l 6G file`
* Watch the alarm and see it trigger the lambda
* Within 10 minutes or so, your instance should have more space!
