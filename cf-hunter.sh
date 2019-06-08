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

div1="printf '%80s\n' | tr ' ' ="
div2="printf '%80s\n' | tr ' ' -"

jq_mem_select=' .[].memory_in_mb'
jq_disk_select=' .[].disk_in_mb'
jq_org_guid_select=' .[] | select(.name == "dmathis") | .guid'
awk_sum='{s+=$1} END {printf "%.0f", s}'

org_guid=$(load_all_pages "/v3/organizations/" | jq -r "$jq_org_guid_select")

org_tasks=$(load_all_pages "/v3/tasks?organization_guids=${org_guid}")
org_processes=$(load_all_pages "/v3/processes?organization_guids=${org_guid}")

org_tasks_total_mem=$(echo $org_tasks | jq -r "$jq_mem_select" | awk "$awk_sum")
org_processes_total_mem=$(echo $org_processes | jq -r "$jq_mem_select" | awk "$awk_sum")
org_total_mem=$(($org_tasks_total_mem+$org_processes_total_mem))
org_tasks_total_disk=$(echo $org_tasks | jq -r "$jq_disk_select" | awk "$awk_sum")
org_processes_total_disk=$(echo $org_processes | jq -r "$jq_disk_select" | awk "$awk_sum")
org_total_disk=$(($org_tasks_total_disk+$org_processes_total_disk))

printf "%-50s%15s%15s\n" "Hierarchy" "Disk" "Memory" 
eval "$div1"
printf "%-50s%15s%15s\n" "Org: dmathis" "$org_total_disk MB" "$org_total_mem MB"

for space in $(load_all_pages "/v3/spaces?organization_guids=${org_guid}" | jq -r ' .[].guid'); do
   space_tasks=$(load_all_pages "/v3/tasks?space_guids=${space}")
   space_processes=$(load_all_pages "/v3/processes?space_guids=${space}")
   space_name=$(cf curl "/v3/spaces/${space}" | jq -r .name)
   space_tasks_total_mem=$(echo $space_tasks | jq -r "$jq_mem_select" | awk "$awk_sum")
   space_processes_total_mem=$(echo $space_processes | jq -r "$jq_mem_select" | awk "$awk_sum")
   space_total_mem=$(($space_tasks_total_mem+$space_processes_total_mem))
   space_tasks_total_disk=$(echo $space_tasks | jq -r "$jq_disk_select" | awk "$awk_sum")
   space_processes_total_disk=$(echo $space_processes | jq -r "$jq_disk_select" | awk "$awk_sum")
   space_total_disk=$(($space_tasks_total_disk+$space_processes_total_disk))
   eval "$div1"
   printf "%-5s%-45s%15s%15s\n" "" "Space: $space_name" "$space_total_disk MB" "$space_total_mem MB"
   for app in $(load_all_pages "/v3/apps?space_guids=${space}" | jq -r ' .[].guid'); do
      app_tasks=$(load_all_pages "/v3/tasks?app_guids=${app}")
      app_processes=$(load_all_pages "/v3/processes?app_guids=${app}")
      app_name=$(cf curl "/v3/apps/${app}" | jq -r .name)
      app_tasks_total_mem=$(echo $app_tasks | jq -r "$jq_mem_select" | awk "$awk_sum")
      app_processes_total_mem=$(echo $app_processes | jq -r "$jq_mem_select" | awk "$awk_sum")
      app_total_mem=$(($app_tasks_total_mem+$app_processes_total_mem))
      app_tasks_total_disk=$(echo $app_tasks | jq -r "$jq_disk_select" | awk "$awk_sum")
      app_processes_total_disk=$(echo $app_processes | jq -r "$jq_disk_select" | awk "$awk_sum")
      app_total_disk=$(($app_tasks_total_disk+$app_processes_total_disk))
      eval "$div2"      
      printf "%-10s%-40s%15s%15s\n" "" "App: $app_name" "$app_total_disk MB" "$app_total_mem MB"
      eval "$div2"
      for task in $(load_all_pages "/v3/tasks?app_guids=${app}" | jq -r ' .[].guid'); do
         task_name=$(cf curl "/v3/tasks/${task}" | jq -r .name)
         task_mem=$(cf curl "/v3/tasks/${task}" | jq -r .memory_in_mb)
         task_disk=$(cf curl "/v3/tasks/${task}" | jq -r .disk_in_mb)
         printf "%-15s%-35s%15s%15s\n" "" "Task: $task_name" "$task_disk MB" "$task_mem MB"
      done
      for process in $(load_all_pages "/v3/processes?app_guids=${app}" | jq -r ' .[].guid'); do
         process_name=$(cf curl "/v3/processes/${process}" | jq -r .type)
         process_mem=$(cf curl "/v3/processes/${process}" | jq -r .memory_in_mb)
         process_disk=$(cf curl "/v3/processes/${process}" | jq -r .disk_in_mb)
         printf "%-15s%-35s%15s%15s\n" "" "Process: $process_name" "$process_disk MB" "$process_mem MB"
      done
   done  
done

echo "$output"
