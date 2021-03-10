#!/bin/bash -e

# ###################################################################
# SYNOPSIS
#   Smart Ticket remediation script for high memory usage.
#
# DESCRIPTION
#   Reports back diagnostic information related to memory usage.
#   Supported: Yes
#   Keywords: faws,memory,high,smarttickets
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
  echo ""
  # Get line count, taking away 3 header and 1 footer lines
  LINE_COUNT=$(sar -r | wc -l)-4
  OUTPUT_LINES=$(( (MAX_RESULTS > LINE_COUNT ? LINE_COUNT : MAX_RESULTS) + 1 ))
  sar -r | head -n 3
  sar -r | tail -n $OUTPUT_LINES
  echo ""
  # Get line count, taking away 3 header and 1 footer lines
  LINE_COUNT=$(sar -B | wc -l)-4
  OUTPUT_LINES=$(( (MAX_RESULTS > LINE_COUNT ? LINE_COUNT : MAX_RESULTS) + 1 ))
  sar -B | head -n 3
  sar -B | tail -n $OUTPUT_LINES
  echo ""
}


# Output memory details
echo ""
free -m

# Output top {{ ResultCount }} processes
echo ""
echo "Top $MAX_RESULTS Processes by MEM %"
echo ""
ps -eo user,%cpu,%mem,rsz,args | sort -rnk4 | awk 'BEGIN {printf "%8s\t%6s\t%6s\t%8s\t%s\n","USER","%CPU","%MEM","RSZ","COMMAND"}{printf "%8s\t%6s\t%6s\t%8s MB\t%-12s\n",$1,$2,$3,$4/1024,$5}' | head -n $(( MAX_RESULTS + 1 ))

# Output last {{ ResultCount }} SAR entries
echo ""
command -v sar >/dev/null 2>/dev/null && sar_output || echo 'no sysstat available'
