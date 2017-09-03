#!/bin/bash

MEMORY=0.0

declare -A prev_pid_name=([1234]="Jps")
declare -A prev_name_max=(["Jps"]=0)
declare -A curr_pid_name=([1234]="Jps")
declare -A curr_name_max=(["Jps"]=0)

echo "pid    Name                                          CurrMem Max "
echo "====   ============================================  ======= ===="




while true
do
    
    
    IFS=$'\n'
    DATA=($("jps"))
    #insert process data into array
    IFS=$' '
    
    
    #clear previous loop output from screen
    tput cuu $(( ${#prev_pid_name[@]} -1 )) && tput el
    
    for LINE in "${DATA[@]}"
    do
        read -ra TOKENS <<< "$LINE"
        
        if [ "${TOKENS[1]}" == "Jps" ] || [ "${TOKENS[1]}" == "Jstat" ] || [ "${TOKENS[0]}" -eq 0 ]
        then
            continue
        fi
        
        # insert to associative array
        curr_pid_name["${TOKENS[0]}"]=${TOKENS[1]}
        
        if [ ${prev_name_max["${TOKENS[1]}"]+_} ]; then
            curr_name_max["${TOKENS[1]}"]=${prev_name_max["${TOKENS[1]}"]}
        else
            curr_name_max["${TOKENS[1]}"]=0
        fi
        
    done


    #get the memroy use for each pid in curr_pid_name
    
    for pid in "${!curr_pid_name[@]}"; 
    do
        name=${curr_pid_name["$pid"]}
        if [ "$name" == "Jps" ] || [ "$name" == "Jstat" ] || [ "$pid" -eq 0 ]
        then
            continue
        else
            MEMORY=$(jstat -gc $pid | tail -n 1 | awk '{split($0,a," "); sum=a[3]+a[4]+a[6]+a[8]; mb=sum/1024; print mb}')
            if (( $(echo "${curr_name_max[$name]} < ${prev_name_max[$name]}" |bc -l) ));
            then
                curr_name_max["$name"]=${prev_name_max[$name]}
            fi
            
            #output for this pid
            printf "%-6s %-45s %-7.2f %-7.2f\n" $pid $name $MEMORY ${curr_name_max["$name"]} | sort
        fi
    done
    
    
    
    
    #clean stuff of this iteration
    unset prev_pid_name
    declare -A prev_pid_name
    unset prev_name_max
    declare -A prev_name_max
    
    #insert all current pid, name and max_memory into prev_associative_array[]
    for pid in "${!curr_pid_name[@]}";
    do
        prev_pid_name[$pid]=${curr_pid_name[$pid]}
    done
    for name in "${!curr_name_max[@]}";
    do
        prev_name_max[$name]=${curr_name_max[$name]}
    done
    
    #unset current associative array to make it empty
    unset curr_pid_name
    declare -A curr_pid_name=([1234]="Jps")
    unset curr_name_max
    declare -A curr_name_max=(["Jps"]=0)
   
   
    
done
