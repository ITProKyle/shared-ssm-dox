#!/bin/bash -e

# ###################################################################
# SYNOPSIS
#   SmartTicket remediation script for high disk usage.
#
# DESCRIPTION
#   Reports back diagnostic information related to disk usage.
#   Supported: Yes
#   Keywords: faws,disk,high,smarttickets
#   Prerequisites: No
#   Makes changes: No
#
# INPUTS
#   TBD
#
# OUTPUTS
#   TBD
#
# ###################################################################

# shellcheck disable=SC1083
MOUNT_POINT={{ MountPoint }}

# output current date/time
echo "== Server Time: =="
date

# output disk summary information for usage (using df)
echo -e "\n== Filesystem Information: =="
df -PTh "${MOUNT_POINT}" | column -t

# output disk inode usage (using df)
echo -e "\n== Inode Information: =="
df -PTi "${MOUNT_POINT}" | column -t

# output largest directories sorted in descending order
echo -e "\n== Largest Directories: =="
du -hcx --max-depth=2 "${MOUNT_POINT}" 2>/dev/null | grep -P '^([0-9]\.*)*G(?!.*(\btotal\b|\./$))' | sort -rnk1,1 | head -n "${MOUNT_POINT}" | column -t

# output largest files sorted in descending order
echo -e "\n== Largest Files: =="
find "${MOUNT_POINT}" -mount -ignore_readdir_race -type f -exec du {} + 2>&1 | sort -rnk1,1 | head -n "${MOUNT_POINT}" | awk 'BEGIN{ CONVFMT="%.2f"
}{ $1=( $1 / 1024 )"M"
 print
}' | column -t

# output largest files older than 30 days sorted in descending order
echo -e "\n== Largest Files Older Than 30 Days: =="
find "${MOUNT_POINT}" -mount -ignore_readdir_race -type f -mtime +30 -exec du {} + 2>&1 | sort -rnk1,1 | head -n {{ResultCount}} | awk 'BEGIN{ CONVFMT="%.2f"
}{ $1=( $1 / 1024 )"M"
 print
}' | column -t
