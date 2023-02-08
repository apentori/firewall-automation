# Firewall Automation with Consul 

Task description <https://gist.github.com/jakubgs/678322ffa776e89e6c9a6bc0b474d01c>


## Installation

### Requirement

To use the script, the following package needs to be installed on the VM :

* `bash`,
* `curl`,
* `jq`,

### Systemd timer

* Copy the script ``update_firewall.sh`` in the directory ``/etc/systemd/system/``
* Create add the service  ``update-firewall.service`` in the directory``/etc/systemd/system/``
* Enable the service with ``systemctl enable update-firewall.service`` and start it with ``systemctl start update-firewall.service``
* Create the timer ``update-firewall.timer`` in the directory ``/etc/systemd/system/``
* Enable the timer with ``systemctl enable update-firewall.timer`` and start it with ``systemctl start update-firewall.timer``

### Crontab

* Copy the script `update_firewall.sh` in the node (example ``/usr/bin/update_firewall.sh``).
* Run the command ``crontab -e`` as a user allow to use firewalld command
* Add the following line ``30 12 * * * /usr/bin/update_firewall.sh >> /var/log/firewalld_script.log``

## Test

### Requirement

* Docker installed (with docker compose plugin)
* Vagrant with VirtualBox Provider.


````mermaid
flowchart LR
  VM1[App node]
  VM2[Metric node]
  VM3[Consul]

  VM1-- Call Consul API --> VM3
  VM2-- Call Consul API --> VM3
  VM2 -- Port 9100 allowed --> VM1
  Consul -- No port allowed --> VM1

````

### Steps

1. Launch the VMs with `vagrant up`
2. Connect to the App node VM1 (``vagrant ssh vm1``), launch the web server on port 9100 with ``python3 /vagrant_data/server.py``.
3. Verify that firewall rules are updated with ``sudo firewall-cmd --get-active-zones``, 3 groups should appear : `zone_backups`, ``zone_log``, ``zone_metrics``.
4. Connect to the Metric node VM2 (``vagrant ssh vm2``), call the App node ``curl 192.168.57.2:9100``, the server should answer ``{"status":"ok"}``.
5. Connect to the Consul node (``vagrant ssh vm3``), call the App node ``curl 192.168.57.2:9100``, an error saying there is no route to host should appear.


> Note: the IP range `10.10.00/24`  could not be used for the vagrant VM due to an error when trying to add a private network with it in virtual box, the data mocked from consul have been modify to follow the IP of each VM.
> @see https://www.virtualbox.org/manual/ch06.html#network_internal part 6.7. Host-Only Networking to try to change the private network IP range.

## Improvement

* [Deployment] Create an ansible playbook to deploy the script and init the cron job / the service and timer
* [Scalability] Get the rules (which node can access to which env on which port) from a file so a new rule can be added without modifying the script
  * Store the rules configuration in Consul KV so it can be easily queried
* [Configuration] Improve the firewall configuration to be more strict. 
  * Add the interface in the wireguard network in the zones files.
  * Add service type for each zone


## Doubt 

* Why does the test environment can access to the prod ? Allowing test host to reach prod environement is dangerous.