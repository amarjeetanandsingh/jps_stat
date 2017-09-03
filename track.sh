#!/bin/bash

MEMORY=0.0

declare -a pids
declare -a names
declare -a max


while true
do
    
    echo "pid    Name                                          CurrMem Max "
    echo "====   ============================================  ======= ===="

    IFS=$'\n'
    DATA=($("jps"))

    #insert process data into array
    IFS=$' '
    i=0
    for LINE in "${DATA[@]}"
    do
        read -ra TOKENS <<< "$LINE"
        pids[$i]=${TOKENS[0]}
        names[$i]=${TOKENS[1]}
        max[$i]=0
        i=$(( $i + 1 ))
    done


    #get the memroy use for each pid in pids
    i=0
    for pid in "${pids[@]}"
    do
        if [ "${names[$i]}" == "Jps" ]
        then
            continue
        else
            MEMORY=$(jstat -gc $pid | tail -n 1 | awk '{split($0,a," "); sum=a[3]+a[4]+a[6]+a[8]; mb=sum/1024; print mb}')
            if (( $(echo "${max[$i]} < $MEMORY" |bc -l) ));
            then
                max[$i]=$MEMORY
            fi
            
            #output for this pid
            printf "%-6s %-45s %-7.2f %-7.2f\n" $pid ${names[$i]} $MEMORY ${max[$i]}
        fi
        i=$(( $i + 1 ))
    done
    
    #clean stuff of this iteration
    printf "\n\n\n"
done
