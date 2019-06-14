#!/bin/bash
# Hunt down tasks and processes in an org that are discreetly using memory / disk space.
# It's not possible see the memory or disk that a task is using from the UI, so this is helpful.
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

# Initialize all the option variables.
# This ensures we are not contaminated by variables from the environment.
org=
space=
verbose=0

# Define usage
function usage {
    cat <<EOM
Usage: 
  $(basename "$0") -o <org> [-s <space>]
      
  -o|--org       <text> a single cf org 
  -s|--space     <text> a single cf space 
  -h|--help                   
Examples:
  $ $(basename "$0") -o system -s autoscaling 
EOM
    exit 2
}

# Process options
while :; do
    case $1 in
        -\?|--help)
            usage               # Display a usage synopsis.
            exit
            ;;
        -o|--org)               # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                org=$2
                shift
            else
                die 'ERROR: "--org" requires a non-empty option argument.'
            fi
            ;;
        --org=?*)
            org=${1#*=}         # Delete everything up to "=" and assign the remainder.
            ;;
        --org=)                 # Handle the case of an empty --org=
            die 'ERROR: "--org" requires a non-empty option argument.'
            ;;
        -s|--space)             # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                space_filter=$2
                shift
            fi
            ;;
        --space=?*)
            space_filter=${1#*=}       # Delete everything up to "=" and assign the remainder.
            ;;
       -v|--verbose)
            verbose=$((verbose + 1))  # Each -v adds 1 to verbosity.
            ;;
        --)                      # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)                       # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

# If no org parameter exit
if [ -z $org ]; then
   usage
fi

echo -e "Please be patient while the report generates. This may take a while..."

output=$(

# Page through api call results
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

# Store divider lines
div1="printf '%80s\n' | tr ' ' ="
div2="printf '%80s\n' | tr ' ' -"

# Define jq and awk strings
jq_mem_select='.[].memory_in_mb'
jq_disk_select='.[].disk_in_mb'
jq_org_guid_select=".[] | select(.name == \"${org}\") | .guid"
jq_app_mem_select='.memory_in_mb'
jq_app_disk_select='.disk_in_mb'
jq_app_state_select='.state'
jq_name_select='.name'
jq_type_select='.type'
awk_sum='{s+=$1} END {printf "%.0f", s}'

# Get org guid
org_guid=$(load_all_pages "/v3/organizations/" | jq -r "$jq_org_guid_select")

# Get org tasks and processes
org_tasks=$(load_all_pages "/v3/tasks?organization_guids=${org_guid}")
org_processes=$(load_all_pages "/v3/processes?organization_guids=${org_guid}")

# Do org queries and calculations
org_tasks_total_mem=$(echo $org_tasks | jq -r "$jq_mem_select" | awk "$awk_sum")
org_processes_total_mem=$(echo $org_processes | jq -r "$jq_mem_select" | awk "$awk_sum")
org_total_mem=$(($org_tasks_total_mem+$org_processes_total_mem))
org_tasks_total_disk=$(echo $org_tasks | jq -r "$jq_disk_select" | awk "$awk_sum")
org_processes_total_disk=$(echo $org_processes | jq -r "$jq_disk_select" | awk "$awk_sum")
org_total_disk=$(($org_tasks_total_disk+$org_processes_total_disk))

# Print org info
printf "\n%-54s%13s%13s\n" "Hierarchy" "Disk" "Memory"

if [ -z "$space_filter" ]; then
   eval "$div1";
   printf "%-54s%13s%13s\n" "Org: $org" "$org_total_disk MB" "$org_total_mem MB"; 
fi

# Loop through spaces for specified org
for space in $(load_all_pages "/v3/spaces?organization_guids=${org_guid}" | jq -r ' .[].guid'); do
   # Get space name
   space_name=$(cf curl "/v3/spaces/${space}" | jq -r "$jq_name_select")

   # If no space filter interrogate all spaces, else just the space filter 
   if [ -z "$space_filter" ] || [ "$space_name" = "$space_filter" ]; then
      # Get space tasks and processes
      space_tasks=$(load_all_pages "/v3/tasks?space_guids=${space}")
      space_processes=$(load_all_pages "/v3/processes?space_guids=${space}")

      # Do space queries and calculations
      space_tasks_total_mem=$(echo $space_tasks | jq -r "$jq_mem_select" | awk "$awk_sum")
      space_processes_total_mem=$(echo $space_processes | jq -r "$jq_mem_select" | awk "$awk_sum")
      space_total_mem=$(($space_tasks_total_mem+$space_processes_total_mem))
      space_tasks_total_disk=$(echo $space_tasks | jq -r "$jq_disk_select" | awk "$awk_sum")
      space_processes_total_disk=$(echo $space_processes | jq -r "$jq_disk_select" | awk "$awk_sum")
      space_total_disk=$(($space_tasks_total_disk+$space_processes_total_disk))

      # Print space info
      eval "$div1"
      printf "%-5s%-49s%13s%13s\n" "" "Space: $space_name" "$space_total_disk MB" "$space_total_mem MB"
 
      # Loop through apps for specified space
      for app in $(load_all_pages "/v3/apps?space_guids=${space}" | jq -r ' .[].guid'); do
         # Get app tasks and processes
         app_tasks=$(load_all_pages "/v3/tasks?app_guids=${app}")
         app_processes=$(load_all_pages "/v3/processes?app_guids=${app}")

         # Do app queries and calculations
         app_name=$(cf curl "/v3/apps/${app}" | jq -r "$jq_name_select")
         app_state=$(cf curl "/v3/apps/${app}" | jq -r "$jq_app_state_select")
	 app_tasks_total_mem=$(echo $app_tasks | jq -r "$jq_mem_select" | awk "$awk_sum")
         app_processes_total_mem=$(echo $app_processes | jq -r "$jq_mem_select" | awk "$awk_sum")
         app_total_mem=$(($app_tasks_total_mem+$app_processes_total_mem))
         app_tasks_total_disk=$(echo $app_tasks | jq -r "$jq_disk_select" | awk "$awk_sum")
         app_processes_total_disk=$(echo $app_processes | jq -r "$jq_disk_select" | awk "$awk_sum")
         app_total_disk=$(($app_tasks_total_disk+$app_processes_total_disk))

         # Print app info
         eval "$div2"      
         printf "%-10s%-44s%13s%13s\n" "" "App: $(echo $app_name | cut -c 1-29) ($(echo $app_state | awk {'print tolower($0)'}))" "$app_total_disk MB" "$app_total_mem MB"
         eval "$div2" 

         # Loop through tasks for specified app
         for task in $(load_all_pages "/v3/tasks?app_guids=${app}" | jq -r ' .[].guid'); do
            # Do task queries and calculations
            task_name=$(cf curl "/v3/tasks/${task}" | jq -r "$jq_name_select")
            task_mem=$(cf curl "/v3/tasks/${task}" | jq -r "$jq_app_mem_select")
            task_disk=$(cf curl "/v3/tasks/${task}" | jq -r "$jq_app_disk_select")
            
            # Print task info
            printf "%-15s%-39s%13s%13s\n" "" "Task: $task_name" "$task_disk MB" "$task_mem MB"
         done

         # Loop through processes for specified app
         for process in $(load_all_pages "/v3/processes?app_guids=${app}" | jq -r ' .[].guid'); do
            # Do process queries and calculations
            process_name=$(cf curl "/v3/processes/${process}" | jq -r "$jq_type_select")
            process_mem=$(cf curl "/v3/processes/${process}" | jq -r "$jq_app_mem_select")
            process_disk=$(cf curl "/v3/processes/${process}" | jq -r "$jq_app_disk_select")
            
            # Print process info
            printf "%-15s%-39s%13s%13s\n" "" "Process: $process_name" "$process_disk MB" "$process_mem MB"
         done
      done
   fi  
done

)

echo "$output"
