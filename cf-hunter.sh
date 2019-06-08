#!/bin/bash

function load_all_pages {
    url="$1"
    data=""
    until [ "$url" == "null" ]; do
        resp=$(cf curl "$url")
        data+=$(echo "$resp" | jq .resources)
        url=$(echo "$resp" | jq -r .next_url)
    done
    # dump the data
    echo "$data" | jq .[] | jq -s
}

org_guid=$(load_all_pages "/v3/organizations/" | jq -r ' .[] | select(.name == "dmathis") | .guid')

org_tasks_total_mem=$(load_all_pages "/v3/tasks?organization_guids=${org_guid}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
org_processes_total_mem=$(load_all_pages "/v3/processes?organization_guids=${org_guid}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
org_total_mem=$(($org_tasks_total_mem+$org_processes_total_mem))
org_tasks_total_disk=$(load_all_pages "/v3/tasks?organization_guids=${org_guid}" | jq -r ' .[].disk_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
org_processes_total_disk=$(load_all_pages "/v3/processes?organization_guids=${org_guid}" | jq -r ' .[].disk_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
org_total_disk=$(($org_tasks_total_disk+$org_processes_total_disk))

div1="printf '%80s\n' | tr ' ' ="
div2="printf '%80s\n' | tr ' ' -"

printf "%-50s%15s%15s\n" "Hierarchy" "Disk" "Memory" 
eval "$div1"
printf "%-50s%15s%15s\n" "Org: dmathis" "$org_total_disk MB" "$org_total_mem MB"

for space in $(load_all_pages "/v3/spaces?organization_guids=${org_guid}" | jq -r ' .[].guid'); do
   space_name=$(cf curl "/v3/spaces/${space}" | jq -r .name)
   space_tasks_total_mem=$(load_all_pages "/v3/tasks?space_guids=${space}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
   space_processes_total_mem=$(load_all_pages "/v3/processes?space_guids=${space}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
   space_total_mem=$(($space_tasks_total_mem+$space_processes_total_mem))
   space_tasks_total_disk=$(load_all_pages "/v3/tasks?space_guids=${space}" | jq -r ' .[].disk_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
   space_processes_total_disk=$(load_all_pages "/v3/processes?space_guids=${space}" | jq -r ' .[].disk_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
   space_total_disk=$(($space_tasks_total_disk+$space_processes_total_disk))
   eval "$div1"
   printf "%-5s%-45s%15s%15s\n" "" "Space :: $space_name" "$space_total_disk MB" "$space_total_mem MB"
   for app in $(load_all_pages "/v3/apps?space_guids=${space}" | jq -r ' .[].guid'); do
      app_name=$(cf curl "/v3/apps/${app}" | jq -r .name)
      app_tasks_total_mem=$(load_all_pages "/v3/tasks?app_guids=${app}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
      app_processes_total_mem=$(load_all_pages "/v3/processes?app_guids=${app}" | jq -r ' .[].memory_in_mb' | awk '{s+=$1} END {printf "%.0f", s}')
      app_total_mem=$(($app_tasks_total_mem+$app_processes_total_mem))
      eval "$div2"      
      printf "%-10s%-40s%30s\n" "" "App :: $app_name" "$app_total_mem MB"
      eval "$div2"
      for task in $(load_all_pages "/v3/tasks?app_guids=${app}" | jq -r ' .[].guid'); do
         task_name=$(cf curl "/v3/tasks/${task}" | jq -r .name)
         task_mem=$(cf curl "/v3/tasks/${task}" | jq -r .memory_in_mb)
         printf "%-15s%-35s%30s\n" "" "Task :: $task_name" "$task_mem MB"
      done
      for process in $(load_all_pages "/v3/processes?app_guids=${app}" | jq -r ' .[].guid'); do
         process_name=$(cf curl "/v3/processes/${process}" | jq -r .type)
         process_mem=$(cf curl "/v3/processes/${process}" | jq -r .memory_in_mb)
         printf "%-15s%-35s%30s\n" "" "Process :: $process_name" "$process_mem MB"
      done
   done  
done

echo "$output"
