# Firewall Automation with Consul 

Task description <https://gist.github.com/jakubgs/678322ffa776e89e6c9a6bc0b474d01c>


## Todos

* [ ] Create an ansible playbook for
  * [ ] Deploying the script
  * [ ] Setting a cron job to execute the script
* [ ] 


## Usage 

//TODO 

## Test

1. Deploy the stack with ``docker-compose.yaml``
2. ...
// TODO

## Improvement

* [Security] Run the script with a non root user who has access to firewalld
* [Scalability] Get the rules (which node can access to which env on which port) from a file so a new rule can be added without modification
  * Store the rules configuration in Consul KV so it can be easily queried
* [] Improve the firewall configuration to be more strict. 


## Doubt 

* Why does the test environment can access to the prod ? Allowing test host to reach prod environement is dangerous.



