#!/bin/bash

# Script updating the firewalld configuration of fleets using Consul catalog data.
# version: 0.0.1

CONSUL_HOST="192.168.57.5"
CONSUL_PORT="8500"
# CONSUL_ENDPOINT="v1/catalog/service/wireguard"
CONSUL_ENDPOINT="v1/catalog/service"
FIREWALLD_ZONE_CONFIG="/etc/firewalld/zones"


################################################################################################
#####                                       Functions                                      #####
################################################################################################

function log_info() {
    # Escaping the message so xml can be valid for logstash
    message=$(echo "$1" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\t/\\t/g' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"message\":\"$message\"}"
}

function callConsul(){
    local filter=$1
    local data=$(curl -sSf --get "$CONSUL_HOST:$CONSUL_PORT/$CONSUL_ENDPOINT/$filter")
    if [[ $? -ne 0 ]]; then
        log_info "Error when getting data from Consul. Premature end of script"
        exit 1;
    fi
    echo "$data"
}

function getServiceAddressByEnvAndStage(){
    local nodeEnv=$1
    local nodeStage=$2

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

row_data=$(curl -sSf --get "$CONSUL_HOST:$CONSUL_PORT/$CONSUL_ENDPOINT/$(hostname)")
 if [[ $? -ne 0 ]]; then
        log_info "Error when getting data from Consul. End of script"
        exit 1;
fi   

host_data=$(row_data | jq '.[] | { Node, NodeMeta, ServiceMeta }')

host_env=$(echo $host_data | jq -r '.NodeMeta.env')
host_stage=$(echo $host_data | jq -r '.NodeMeta.stage')

log_info "The script run on $(hostname), from the $host_env fleet in $host_stage"




ports_metrics=(9100)

if [[ $host_env == "app" ]];
then
    ports_metrics+=("9104")
elif [[ $host_env == "logs" ]];
then
    ports_metrics+=("5141")
fi

log_info "Updating rule for metrics env"
hosts_metrics=("$(getServiceAddressByEnvAndStage "metrics" "prod")" "$(getServiceAddressByEnvAndStage "metrics" "test")")
write_zone_firewalld "zone_metrics.xml" "$hosts_metrics" $ports_metrics

if [[ $host_env == "app" ]];
then
    log_info "updating rules to allow access from backups env"
    hosts_backups=("$(getServiceAddressByEnvAndStage "backups" "prod")" "$(getServiceAddressByEnvAndStage "backups" "test")")
    write_zone_firewalld "zone_backups.xml" "$hosts_backups" "3306"
elif [[ $host_env == "logs" ]];
then 
    log_info "updating rules to allow access from  backups env"
    hosts_backups=("$(getServiceAddressByEnvAndStage "backups" "prod")" "$(getServiceAddressByEnvAndStage "backups" "test")")
    write_zone_firewalld "zone_backups.xml" "$hosts_backups" "5141"

    log_info "updating rules to allow access from app env"
    hosts_app=("$(getServiceAddressByEnvAndStage "app" "prod")" "$(getServiceAddressByEnvAndStage "app" "test")")
    write_zone_firewalld "zone_app.xml" "$hosts_app" "5141"

    hosts_logs=("$(getServiceAddressByEnvAndStage "logs" "prod")" "$(getServiceAddressByEnvAndStage "logs" "test")")
    echo "$hosts_logs"
    write_zone_firewalld "zone_log.xml" $hosts_logs "5141"
fi


log_info "Reloading firewalld after configuration"
firewall-cmd --reload

