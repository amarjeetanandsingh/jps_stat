#!/bin/bash
#
# MIT License
#
# Copyright (c) 2017 Amarjeet Anand
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to deal 
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is furnished 
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

RUNONCE=0
SHOW_HEADERS=1
commandline_args=("$@")

parse_options() {
  for var in "${commandline_args[@]}"; do
      if [ $var = "-h" ] || [ $var = "-help" ]
      then
          echo "usage: ./jpsstat.sh [options]"
          echo ""
          echo "[OPTIONS] :"
          echo "    -l"
          echo "        Displays the full package name for the application's main class or the full path name to the application's JAR file."
          echo ""
          echo "    -1 | --once"
          echo "        Just run the script once, do not continuously refresh"
          echo ""
          echo "    -H | --no-headers"
          echo "        Do not display the text header with the field names"
          echo ""
          echo "    -h | -help"
          echo "        Display this help menu"
          echo ""
          echo "/********* Output Format *****************"
          echo " * PID    : Process Id"
          echo " * Name   : Process Name"
          echo " * CurHeap: Heap memory(MB) currently in use"
          echo " * MaxHeap: Max Heap memory(MB) used by now"
          echo " * CurRAM : Current RAM(MB) used"
          echo " * MaxRAM : Max RAM(MB) used by now"
          echo " * %_CPU  : Current CPU use by PID"
          echo " */"
          exit 0
      elif [ $var = "-1" ] || [ $var = "--once" ]
      then
          RUNONCE=1
      elif [ $var = "-H" ] || [ $var = "--no-headers" ]
      then
          SHOW_HEADERS=0
      fi
  done
}

parse_options

if [ $SHOW_HEADERS -eq 1 ]; then
    echo "=====  ==============================  =======  =======  ======  ======  ====="
    echo " PID                Name               CurHeap  MaxHeap  CurRAM  MaxRAM  %_CPU"
    echo "=====  ==============================  =======  =======  ======  ======  ====="
fi

declare -A prev_pid_max_heap=()
declare -A prev_pid_max_ram=()

while true
do  

    declare -A curr_pid_name=()
    declare -A curr_pid_max_heap=()
    declare -A curr_pid_max_ram=()
    
    IFS=$'\n'
    DATA=
    ## check if -l option is given
    for var in "$@"
    do
        if [ $var = "-l" ]
        then
            DATA=($(jps -l))
        fi
    done

    if [ -z "$DATA" ]
    then
        DATA=($("jps"))
    fi
    
    # put curser up with # of prev processes
    if (( ${#prev_pid_max_heap[@]} > 0 ));
    then
        tput cuu $(( ${#prev_pid_max_heap[@]} )) 
    fi

    # for each process line we get in jps 
    IFS=$' '
    for LINE in "${DATA[@]}"
    do
        read -ra TOKENS <<< "$LINE"
        # if -l option is given, get the last element of the jar file/class name
        TOKENS[1]=${TOKENS[1]##*[\\ /]}

        # skip the process if its Jps or Jstat itself 
        if [ "${TOKENS[1]}" == "Jps" ] || [ "${TOKENS[1]}" == "sun.tools.jps.Jps" ] || [ "${TOKENS[1]}" == "Jstat" ] || [ "${TOKENS[1]}" == "sun.tools.jstat.Jstat" ]
        then
            continue
        fi
        pid=${TOKENS[0]}
        # insert to associative array
        curr_pid_name["$pid"]=${TOKENS[1]:-"<no name>"}

        # compare current heap with previous to get max_heap
        HEAP_MEMORY=$( (jstat -gc $pid 2>/dev/null || echo "0 0 0 0 0 0 0 0 0") | tail -n 1 | awk '{split($0,a," "); sum=a[3]+a[4]+a[6]+a[8]; print sum/1024}' ) 2>/dev/null
        HEAP_MEMORY=${HEAP_MEMORY%.*}
        if [ ${prev_pid_max_heap["$pid"]+_} ] && [ $HEAP_MEMORY -lt ${prev_pid_max_heap[$pid]} ]; then
            curr_pid_max_heap["$pid"]=${prev_pid_max_heap["$pid"]}
        else
            curr_pid_max_heap["$pid"]=$HEAP_MEMORY
        fi
        
        # compare current ram with previous to get max_ram
        RAM_MEMORY=$(( ` cut -d' ' -f2 <<<cat /proc/$pid/statm 2>/dev/null || echo "0" ` / 1024 ))
        RAM_MEMORY=${RAM_MEMORY%.*}
        if [ ${prev_pid_max_ram["$pid"]+_} ] && [ $RAM_MEMORY -lt ${prev_pid_max_ram[$pid]} ]; then
            curr_pid_max_ram["$pid"]=${prev_pid_max_ram["$pid"]}
        else
            curr_pid_max_ram["$pid"]=$RAM_MEMORY
        fi

        #output for current pid
        cpuuse=$( (ps -p $pid -o %cpu 2>/dev/null || echo "0") | tail -n 1 )
        cpuuse=${cpuuse%.*}
        printf "%-6s %-30s %8i %8i %7d %7d  %5i\n" $pid ${curr_pid_name["$pid"]:0:30} $HEAP_MEMORY ${curr_pid_max_heap["$pid"]} $RAM_MEMORY ${curr_pid_max_ram["$pid"]} $cpuuse | sort 
    done

    
    # clean stuff of previous iteration
    unset prev_pid_max_heap
    declare -A prev_pid_max_heap
    unset prev_pid_max_ram
    declare -A prev_pid_max_ram

    # put all current pid and max_memory into prev_associative_array
    for pid in "${!curr_pid_max_heap[@]}";
    do
        prev_pid_max_heap[$pid]=${curr_pid_max_heap[$pid]}
    done
    # put all current pid, max_ram_memory into prev associative array
    for pid in "${!curr_pid_max_ram[@]}";
    do
        prev_pid_max_ram[$pid]=${curr_pid_max_ram[$pid]}
    done

    if [ $RUNONCE -eq 1 ]
    then
        exit
    fi

    sleep 0.3
done
