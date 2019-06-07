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

ORG_TASKS_TOTAL_MEM=$(load_all_pages "/v3/tasks?organization_guids=${ORG_GUID}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
ORG_PROCESSES_TOTAL_MEM=$(load_all_pages "/v3/processes?organization_guids=${ORG_GUID}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
ORG_TOTAL_MEM=$(($ORG_TASKS_TOTAL_MEM+$ORG_PROCESSES_TOTAL_MEM))

echo "ORG_TASKS_TOTAL_MEM ${ORG_TASKS_TOTAL_MEM}"
echo "ORG_PROCESSES_TOTAL_MEM ${ORG_PROCESSES_TOTAL_MEM}"
echo "ORG_TOTAL_MEM ${ORG_TOTAL_MEM}"

for SPACE in $(load_all_pages "/v3/spaces?organization_guids=${ORG_GUID}" | jq -r ' .[].guid'); do
   SPACE_NAME=$(cf curl "/v3/spaces/${SPACE}" | jq -r .name)
   SPACE_TASKS_TOTAL_MEM=$(load_all_pages "/v3/tasks?space_guids=${SPACE}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
   SPACE_PROCESSES_TOTAL_MEM=$(load_all_pages "/v3/processes?space_guids=${SPACE}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
   SPACE_TOTAL_MEM=$(($SPACE_TASKS_TOTAL_MEM+$SPACE_PROCESSES_TOTAL_MEM))
   echo "   SPACE_NAME ${SPACE_NAME}"
   echo "   SPACE_TASKS_TOTAL_MEM ${SPACE_TASKS_TOTAL_MEM}"
   echo "   SPACE_PROCESSES_TOTAL_MEM ${SPACE_PROCESSES_TOTAL_MEM}"
   echo "   SPACE_TOTAL_MEM ${SPACE_TOTAL_MEM}"
   for APP in $(load_all_pages "/v3/apps?space_guids=${SPACE}" | jq -r ' .[].guid'); do
      APP_NAME=$(cf curl "/v3/apps/${APP}" | jq -r .name)
      echo "      APP_NAME ${APP_NAME}"
      for TASK in $(load_all_pages "/v3/tasks?app_guids=${APP}" | jq -r ' .[].guid'); do
         TASK_NAME=$(cf curl "/v3/tasks/${TASK}" | jq -r .name)
         echo "         TASK_NAME ${TASK_NAME}"
      done
      for PROCESS in $(load_all_pages "/v3/processes?app_guids=${APP}" | jq -r ' .[].guid'); do
         PROCESS_NAME=$(cf curl "/v3/processes/${PROCESS}" | jq -r .type)
         echo "         PROCESS_NAME ${PROCESS_NAME}"
      done
   done  
done

echo "$OUTPUT"
