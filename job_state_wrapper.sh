#!/bin/bash
# 
# event hooks handler, called by cylc event hooks
#
# Purpose :
#
#   PBS does not provide a different signal for pre-emptive job
#   When Cylc trapped SIGTERM/SIGKILL signal, make a redundent check
#   to see if it's really killed or just re-queue/ru-run/held by PBS
#   and reset appropriate state if necessary
# 
# Location : 
#
#   suite bin/ directory
#
# Usage : 
#
#   job_state_wrapper -k keyword -host ip [-s state] [-w sec]
#
#   -k    Necessary, specifies the keyword(s) of job succeeded in job log
#   -host Necessary, specifies job host IP 
#   -w    Optional,  specifies job state poll interval in seconds, default 60
#   -s    Optional,  specifies the task state, default 'succeeded'
#
# Note :
# 
#   1. Handler may be concurrently called by tasks
#
#   2. Besides the optional aruguments, handler will be called with 
#      these implicit command line templates
#
#            %(event)s  %(suite)s  %(id)s  %(message)s
#
# History :
#   1st release 03/08/2018, jliu 
#
#set -x

# Default settings
time_to_wait=60
job_id=''
keyword=''
job_host=''
state='succeeded'

_cmdline=($@)
named_arg=0
while [[ $# -gt 1 ]]
do
    key="$1"
    case $key in
    -k)
      buff=($2)
      keyword="${buff[@]}"
      named_arg=$((named_arg+${#buff[@]}+1))
      shift
      ;;
    -s)
      state="$2"
      named_arg=$((named_arg+2))
      shift
      ;;
    -host)
      job_host=$2
      named_arg=$((named_arg+2))
      shift      
      ;;
    -w)
      time_to_wait=$2
      named_arg=$((named_arg+2))
      shift
      ;;
    *)
      # unknown option
      ;;
    esac
    shift
done

APP_NAM=`basename $0`
APP_DIR=`dirname $0`
[ "$APP_DIR" = "." ] && APP_DIR=`pwd`

# Implicit passed position arguments
#   %(event)s %(suite)s %(id)s %(message)s 
  event=${_cmdline[$((named_arg))]}
  suite=${_cmdline[$((named_arg+1))]}
     id=${_cmdline[$((named_arg+2))]}
message="${_cmdline[@]:$((named_arg+3))}"
 
name=`echo $id | cut -d'.' -f1`
point=`echo "$id" | cut -d'.' -f2`
log_dir=${CYLC_SUITE_RUN_DIR}/log/job/${point}/${name}/NN
job_out=$log_dir/job.out
job_status=$log_dir/job.status

if [ ${#job_host} -eq 0 -o ${#keyword} -eq 0 ] ; then
  echo "$APP_NAM : Error : Missing args"
  exit
fi

cmd_arg=(-wait $time_to_wait -state $state -suite $suite -task ${id})

batch_sys_name=`grep "CYLC_BATCH_SYS_NAME" $job_status | cut -d'=' -f2 | tr [a-z] [A-Z]`
if [ "${batch_sys_name}" = "PBS" ]; then
  job_id=`grep "CYLC_BATCH_SYS_JOB_ID" $job_status | cut -d'=' -f2`
  if [ ${#job_id} -gt 0 ]; then
    cmd_arg=(${cmd_arg[@]} -host $job_host -jobid $job_id)
    setsid  $APP_DIR/job_state_handler.sh ${cmd_arg[@]} -jobout $job_out -k "${keyword}"
  else
    echo "$APP_NAM : Error : Failed to get job ID"
  fi
fi
