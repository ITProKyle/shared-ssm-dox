#!/bin/bash -e

# ###################################################################
# SYNOPSIS
#   SmartTicket remediation script for high cpu usage.
#
# DESCRIPTION
#   Reports back diagnostic information related to cpu usage.
#   Supported: Yes
#   Keywords: faws,cpu,high,smarttickets
#   Prerequisites: No
#   Makes changes: No
#
# INPUTS
#   None
#
# OUTPUTS
#   System information and top process list sorted by RSZ
#   If sysstat is available, memory utilization and paging statistics
#   will also be returned
#
# ###################################################################

# shellcheck disable=SC1083
MAX_RESULTS={{ ResultCount }}

function sar_output() {
  echo "== Last $MAX_RESULTS Samples =="
  echo
    # Get line count, taking away 3 header and 1 footer lines
    LINE_COUNT=$(sar -r | wc -l)-4
    OUTPUT_LINES=$(( (MAX_RESULTS > LINE_COUNT ? LINE_COUNT : MAX_RESULTS) + 1 ))
    sar -u | head -n 3
    sar -u | tail -n $OUTPUT_LINES
  echo
    # Get line count, taking away 3 header and 1 footer lines
    LINE_COUNT=$(sar -B | wc -l)-4
    OUTPUT_LINES=$(( (MAX_RESULTS > LINE_COUNT ? LINE_COUNT : MAX_RESULTS) + 1 ))
    sar -P ALL | head -n 3
    sar -P ALL | tail -n $OUTPUT_LINES
  echo
}
echo
echo "Number of processors: $(grep -c processor /proc/cpuinfo)"
awk -F',' '{$1 = $2 = ""; gsub(/^[[:space:]]+|[[:space:]]+$/,"",$0) ; print $0 }' <(uptime)

# Output top {{ResultCount}} processes
echo
echo "Top $MAX_RESULTS Processes by CPU %"
echo
  ps -eo user,%cpu,%mem,rsz,args,pid,lstart|sort -rnk2|awk 'BEGIN {printf "%12s\t%s\t%s\t%s\t%s\n","USER","%CPU","%MEM","RSZ","COMMAND","PID","Started"}{printf "%12s\t%g%%\t%g%%\t%d MB\t%s\n",$1,$2,$3,$4/1024,$5}' | head -n $(( MAX_RESULTS + 1 ))

# Output last {{ResultCount}} SAR entries
echo
  command -v sar >/dev/null 2>/dev/null && sar_output || echo 'no sysstat available'
