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

ORG_GUID=$(load_all_pages "/v3/organizations/" | jq -r ' .[] | select(.name == "dmathis") | .guid')

OUTPUT=$(load_all_pages "/v3/tasks?organization_guids=${ORG_GUID}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "Org dmathis tasks are using %.0f MB of memory.\n", s}')

for SPACE in $(load_all_pages "/v3/spaces?organization_guids=${ORG_GUID}" | jq -r ' .[].guid'); do
   SPACE_MEM=$(load_all_pages "/v3/tasks?space_guids=${SPACE}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f MB\n", s}')
   SPACE_NAME=$(cf curl "/v3/spaces/${SPACE}" | jq -r .name)
   OUTPUT=$(echo -e "${OUTPUT} \nSpace ${SPACE_NAME} tasks are using ${SPACE_MEM} of memory.")    
done

echo "$OUTPUT"
