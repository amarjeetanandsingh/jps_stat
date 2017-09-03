#!/bin/bash

declare -A prev_pid_max=()

echo "/**"
echo " * PID    : Process Id"
echo " * Name   : Process Name"
echo " * CurHeap: Heap memory(MB) currently in use"
echo " * MaxHeap: Max Heap memory(MB) used by now"
echo " * %CPU   : Current CPU use by PID"
echo " */"
echo "=====  ============================================  =======  =======  ====="
echo " PID                       Name                      CurHeap  MaxHeap  %_CPU"
echo "=====  ============================================  =======  =======  ====="


while true
do  

    declare -A curr_pid_name=()
    declare -A curr_pid_max=()
    
    IFS=$'\n'
    DATA=($("jps"))
    
    #put curser up with # of prev processes
    if (( ${#prev_pid_max[@]} > 0 ));
    then
        tput cuu $(( ${#prev_pid_max[@]} )) 
    fi

    #for each process line we get in jps in current loop
    IFS=$' '
    for LINE in "${DATA[@]}"
    do
        read -ra TOKENS <<< "$LINE"
        
        #skip the process if its Jps or Jstat itself 
        if [ "${TOKENS[1]}" == "Jps" ] || [ "${TOKENS[1]}" == "Jstat" ] || [ "${TOKENS[0]}" -eq 0 ]
        then
            continue
        fi
        
        # insert to associative array
        curr_pid_name["${TOKENS[0]}"]=${TOKENS[1]}
        
        if [ ${prev_pid_max["${TOKENS[0]}"]+_} ]; then
            curr_pid_max["${TOKENS[0]}"]=${prev_pid_max["${TOKENS[0]}"]}
        else
            curr_pid_max["${TOKENS[0]}"]=0.0
        fi
    done


    #get the memroy use for each pid in curr_pid_name
    for pid in "${!curr_pid_name[@]}"; 
    do
        name=${curr_pid_name["$pid"]}
        MEMORY=$(jstat -gc $pid | tail -n 1 | awk '{split($0,a," "); sum=a[3]+a[4]+a[6]+a[8]; mb=sum/1024; print mb}')
        if [ ${prev_pid_max[$pid]+_} ] && (( $(echo "$MEMORY < ${prev_pid_max[$pid]}" | bc -l)  ))
        then
            curr_pid_max["$pid"]=${prev_pid_max[$pid]}
        else
            curr_pid_max["$pid"]=$MEMORY
        fi
            
        #output for current pid
        cpuuse=$(ps -p $pid -o %cpu | tail -n 1 )
        printf "%-6s %-44s %8.2f %8.2f  %5.1f\n" $pid $name $MEMORY ${curr_pid_max["$pid"]} $cpuuse | sort 
    done 
    
    
    
    
    #clean stuff of previous iteration
    unset prev_pid_max
    declare -A prev_pid_max

    #insert all current name and max_memory into prev_associative_array
    for pid in "${!curr_pid_max[@]}";
    do
        prev_pid_max[$pid]=${curr_pid_max[$pid]}
    done

done
