# Firewall Automation with Consul 

Task description <https://gist.github.com/jakubgs/678322ffa776e89e6c9a6bc0b474d01c>


## Usage 

* Copy the script `update_firewall.sh` in the node (example ``/usr/bin/update_firewall.sh``).
* Run the command ``crontab -e`` as a user allow to use firewalld command
* Add the following line ``30 12 * * * /usr/bin/update_firewall.sh >> /var/log/firewalld_script.log``

## Test

1. Deploy the stack with ``docker-compose.yaml``
2. TODO

## Improvement

* [Deployment] Create an ansible playbook to deploy the script and init the cron job
* [Security] Run the script with a non root user who has access to firewalld ?
* [Scalability] Get the rules (which node can access to which env on which port) from a file so a new rule can be added without modification
  * Store the rules configuration in Consul KV so it can be easily queried
* [] Improve the firewall configuration to be more strict. 


## Doubt 

* Why does the test environment can access to the prod ? Allowing test host to reach prod environement is dangerous.



