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

load_all_pages "/v3/tasks?states=RUNNING&organization_guids=0c2c4234-c66a-440a-8d54-1afffe9e1b18" 
