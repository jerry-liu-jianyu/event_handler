#!/bin/bash
#set -x

time_to_wait=60

while [[ $# -ge 1 ]]
do
    key="$1"
    case $key in
    -host)
      job_host=$2
      shift
      ;;
    -jobid)
      job_id="$2"
      shift
      ;;
    -jobout)
      job_out="$2"
      shift
      ;;
    -k)
      keyword="$2"
      shift
      ;;
    -state)
      state=$2
      shift
      ;;
    -suite)
      suite=$2
      shift
      ;;
    -task)
      id=$2
      shift
      ;;
    -wait)
      time_to_wait=$2
      shift
      ;;
    *)
      # unknown option
      ;;
    esac
    shift
done

while [[ ${#job_id} -gt 0 ]]
do
  sleep $time_to_wait
  buff=( $(ssh $job_host "qstat $job_id 2>/dev/null | tail -n 1") )
  if [ ${#buff[@]} -gt 4 ]; then
    job_id=${buff[0]}
    job_state=${buff[4]}
  else
    job_id=''
  fi
done

if [ -f $job_out ]; then
  grep -i -E "${keyword}" $job_out #> /dev/null 2>&1
  [ $? -eq 0 ] && cylc reset --state=${state} ${suite} ${id}
fi
