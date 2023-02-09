#!/bin/bash

# Script updating the firewalld configuration of server using Consul catalog data.
# version: 0.0.1

CONSUL_HOST="localhost"
CONSUL_PORT="8500"
CONSUL_ENDPOINT="v1/catalog/service/wireguard"
FIREWALLD_ZONE_CONFIG="/etc/firewalld/zones"



################################################################################################
#####                                       Functions                                      #####
################################################################################################

function log_info() {
    # Escaping the xml so the format is valid for logstash
    message=$(echo "$1" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\t/\\t/g' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"message\":\"$message\"}"
}

function callConsul(){
    local filter=$1
    local data=$(curl -sSf --get "$CONSUL_HOST:$CONSUL_PORT/$CONSUL_ENDPOINT" --data-urlencode filter="$filter")
    echo "$data"
}

function getServiceAddressByEnvAndStage(){
    local nodeEnv=$1
    local nodeStage=$2
    local data=$(callConsul "Node.meta.env=$nodeEnv and NodeMeta.stage=$nodeStage" )
    local data=$(callConsul "${nodeEnv}_${nodeStage}"| jq -r '.[].ServiceAddress' )
    echo "$data"
}

function write_zone_firewalld(){
    local zone_name=$1
    local hosts_list=$2
    local ports=$3
    zone=$'<?xml version="1.0" encoding="utf-8"?>\n<zone  target="%%REJECT%%">\n'

    while read -r host; do 
        zone+=$'\t<source address="'${host}$'"/>\n'
    done <<< "$hosts_list"

    while read -r port; do
        zone+=$'\t<port port="'${port}$'" protocol="tcp"/>\n</zone>'    
    done <<< "$ports"
    log_info "Updating the firewalld zone ${zone_name} with $zone"
    echo "$zone" > "$FIREWALLD_ZONE_CONFIG/$zone_name"

}

################################################################################################
#####                                       Main                                           #####
################################################################################################
log_info "Starting the script"

   
# If the hostname of the host doesn't match the Node value in Consul, use the ServiceAddress as a filter
# and get the ip address of wireguard interface with  ``ip a s wg0 | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2``
host_data=$(callConsul "Node==$(hostname)" | jq '.[] | { Node, NodeMeta, ServiceMeta }')

host_env=$(echo $host_data | jq -r '.NodeMeta.env')
host_stage=$(echo $host_data | jq -r '.NodeMeta.stage')

log_info "The script run on $(hostname), from the $host_env fleet in $host_stage"


log_info "Updating rule for logs env"

hosts_logs=("$(getServiceAddressByEnvAndStage "logs" "prod")" "$(getServiceAddressByEnvAndStage "logs" "test")")
echo "$hosts_logs"
write_zone_firewalld "zone_log.xml" $hosts_logs "5141"

ports_metrics=(9100)

if [[ $host_env == "app" ]];
then
    ports_metrics+=("9104")
fi

log_info "Updating rule for metrics env"
hosts_metrics=("$(getServiceAddressByEnvAndStage "metrics" "prod")" "$(getServiceAddressByEnvAndStage "metrics" "test")")
write_zone_firewalld "zone_metrics.xml" "$hosts_metrics" $ports_metrics

if [[ $host_env == "app" ]];
then
    log_info "updating rule for backups in prod"
    hosts_backups=("$(getServiceAddressByEnvAndStage "backups" "prod")" "$(getServiceAddressByEnvAndStage "backups" "test")")
    write_zone_firewalld "zone_backups.xml" "$hosts_backups" "3306"
fi


log_info "Reloading firewalld after configuration"
firewall-cmd --reload
