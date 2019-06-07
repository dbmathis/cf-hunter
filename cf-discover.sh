#!/bin/bash

function load_all_pages {
    URL="$1"
    DATA=""
    until [ "$URL" == "null" ]; do
        RESP=$(cf curl "$URL")
        DATA+=$(echo "$RESP" | jq .resources)
        URL=$(echo "$RESP" | jq -r .next_url)
    done
    # dump the data
    echo "$DATA" | jq .[] | jq -s
}

# load_all_pages "/v3/tasks?states=RUNNING&organization_guids=0c2c4234-c66a-440a-8d54-1afffe9e1b18" 

ORG_GUID=$(load_all_pages "/v3/organizations/" | jq -r ' .[] | select(.name == "dmathis") | .guid')

load_all_pages "/v3/tasks?organization_guids=${ORG_GUID}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "Org: dmathis is using %.0f MB\n\n", s}'

load_all_pages "/v3/spaces?organization_guids=${ORG_GUID}" | jq -r ' .[].guid' | while read -r LINE ; do
   SPACE_MEM=$(load_all_pages "/v3/tasks?space_guids=${LINE}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f MB\n", s}')
   #echo $LINE
   SPACE_NAME=$(cf curl "/v3/spaces/${LINE}" | jq .name)
   echo "Space: ${SPACE_NAME} is using ${SPACE_MEM}";
done
