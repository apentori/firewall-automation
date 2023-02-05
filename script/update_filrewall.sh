#!/bin/bash

# Script updating the firewalld configuration of fleets using Consul catalog data.
# version: 0.0.1

CONSUL_HOST="localhost"
CONSUL_PORT="8500"
# CONSUL_ENDPOINT="v1/catalog/service/wireguard"
CONSUL_ENDPOINT="v1/catalog/service"
CONSUL_ENDPOINT_2="v1/catalog/service/host"
# FIREWALLD_ZONE_CONFIG="/etc/firewalld/config/zones"
FIREWALLD_ZONE_CONFIG="./result"


################################################################################################
#####                                       Functions                                      #####
################################################################################################

function log_info() {
    # Escaping the message so it's valid for logstash
    message=$(echo "$1" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\t/\\t/g' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"message\":\"$message\"}"
}

function callConsul(){
    local filter=$1
    # TODO uncomment when not in test mode
    # local data=$(curl -sSf --get "$CONSUL_HOST:$CONSUL_PORT/$CONSUL_ENDPOINT" \
    # --data-urlencode filter="$filter")
    local data=$(curl -sSf --get "$CONSUL_HOST:$CONSUL_PORT/$CONSUL_ENDPOINT/$filter")
    echo "$data"
}

function getServiceAddressByEnvAndStage(){
    local nodeEnv=$1
    local nodeStage=$2
    # local data=$(callConsul "Node.meta.env=$nodeEnv and NodeMeta.stage=$nodeStage" )
    local data=$(callConsul "${nodeEnv}_${nodeStage}"| jq '.[].ServiceAddress' )
    echo "$data"
}

function write_zone_firewalld(){
    local zone_name=$1
    local hosts_list=$2
    local port=$3
    zone=$'<?xml version="1.0" encoding="utf-8"?>\n<zone>\n'

    while read -r host; do 
        # The quotes for the adress values are taken from the json lists. Can be done in a cleaner way
        zone+=$'\t<source address='${host}$'/>\n'
    done <<< "$hosts_logs_prod"

    zone+=$'\t<port port="'${port}$'"protocol="tcp"/>\n</zone>'
    log_info "Updating the firewalld zone ${zone_name} with $zone"
    echo "$zone" > "$FIREWALLD_ZONE_CONFIG/$zone_name"

}

################################################################################################
#####                                       Main                                           #####
################################################################################################
log_info "Starting the script"

# Test mode
host_data=$(curl -sSf --get "$CONSUL_HOST:$CONSUL_PORT/$CONSUL_ENDPOINT_2" | jq '.[] | { Node, NodeMeta, ServiceMeta }')
   
# TODO uncomment when not in test mode
# host_data=$(callConsul "Node==$(hostname)" | jq '.[] | { Node, NodeMeta, ServiceMeta }')

env=$(echo $hosts_data | jq '.NodeMeta.env')
stage=$(echo $hosts_data | jq '.NodeMeta.stage')

log_info "The script run on $hostname, it's env is  $env and stage is $stage"

log_info "updating rule for logs env in prod"
hosts_logs_prod=$(getServiceAddressByEnvAndStage "logs" "prod")
write_zone_firewalld 'logs_prod.xml' '$hosts_logs_prod' '5141'

log_info "updating rule for logs env in test"
hosts_logs_test=$(getServiceAddressByEnvAndStage "logs" "test")
write_zone_firewalld 'logs_test.xml' '$hosts_logs_test' '5141'

log_info "updating rule for metrics env in prod"
hosts_metrics_prod=$(getServiceAddressByEnvAndStage "metrics" "prod")
write_zone_firewalld 'metrics_prod.xml' '$hosts_metrics_prod' '9100'

log_info "updating rule for metrics env in test"
hosts_metrics_test=$(getServiceAddressByEnvAndStage "metrics" "test")
write_zone_firewalld 'metrics_test.xml' '$hosts_metrics_test' '9100'

if [[ $env == "app" ]];
then
    log_info "updating rule for sql metrics in prod"
    write_zone_firewalld "metrics_sql_prod.xml" "$hosts_metrics_test" "9104"
    log_info "updating rule for sql metrics in test"
    write_zone_firewalld "metrics_sql_test.xml" "$hosts_metrics_test" "9104"

    log_info "updating rule for backups in prod"
    hosts_backups_prod=$(getServiceAddressByEnvAndStage "backups" "prod")
    write_zone_firewalld "backups_prod.xml" "$hosts_backups_prod" "3306"
    log_info "updating rule for backups in test"
    hosts_backups_test=$(getServiceAddressByEnvAndStage "backups" "test")
    write_zone_firewalld "backups_test.xml" "$hosts_backups_test" "3306"
fi

log_info "Reloading firewalld after configuration"
firewall-cmd --reload

