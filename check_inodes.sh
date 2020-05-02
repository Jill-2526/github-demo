#!/bin/bash

# Plugin for checking count of inodes on a partition
# The total amount of free/used inodes will be checked, where
# multiple partitions may be checked on the same check run
# Copyright (C) 2017 Joern Rueffer

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


usage() {
cat<<EOF

Usage:

check_inodes  -w [warn, if free inode space is less than given percent] -c [critical, if free inode space is less than given percent]
              -p [Partition(s)]

All options are mandantory. Warning and critical thresholds must be given in percent with '%' sign and multiple partitions must be
seperated by comma

e.g. check_inodes -w 10% -c 5% -f /dev/sda1,/dev/mapper/VG_MYVG-LV_MYLV

EOF
exit 3
}

syntax() {
cat<<EOF

Error: one ore more options are incorrect!

EOF
usage
}

check_thresholds() {
if [[ $WARNING_LEVEL -le $CRITICAL_LEVEL ]]; then
cat<<EOF

Error: Warning threshold must be greater than critical threshold!

EOF
exit 3
fi
}

calc_inodes() {
run=1
IFS=',' read -a partinfo <<< "$PARTITIONS"
for partcheck in ${partinfo[@]}; do
    total_inodes=$(df -Pi $partcheck | awk 'NR==2 {print $2}')
    free_inodes=$(df -Pi $partcheck | awk 'NR==2 {print $3}')
    free_inodes_percentage=$(df -Pi $partcheck | awk 'NR==2 {free = 1 - ($3 / $2); printf "%.4f\n", free * 100}')
    free_inodes_percentage=$(echo $free_inodes_percentage | awk '{printf "%d", $1}')
    pnp_inode_percentage=$(df -Pi $partcheck | awk 'NR==2 {free = ($2 / $3); printf "%.1f\n", free}')
    if [[ $free_inodes_percentage -le $CRITICAL_LEVEL ]]; then
	out_actual_run=$(echo "$partcheck: CRITICAL $free_inodes from $total_inodes inodes (${free_inodes_percentage}%) available -  ")
	critical_state=1
    elif [[ $free_inodes_percentage -le $WARNING_LEVEL ]]; then
	out_actual_run=$(echo "$partcheck WARNING $free_inodes from $total_inodes inodes (${free_inodes_percentage}%) available - ")
	warning_state=1
    else
	out_actual_run=$(echo "$partcheck: OK $free_inodes from $total_inodes inodes (${free_inodes_percentage}%) available -  ")
    fi
    pnp_actual_run=$(echo "$partcheck=${pnp_inode_percentage}%;$WARNING_PERCENT;$CRITICAL_PERCENT ")
    if [[ $run -eq "1" ]]; then
	out_run=${out_actual_run}
	pnp_run=${pnp_actual_run}
    else
	out_run=${out_run}${out_actual_run}
	pnp_run=${pnp_run}${pnp_actual_run}
    fi
    run=$((run + 1))
done
}

print_results() {
if [[ $critial_state -eq "1" ]]; then
    echo $(echo "$out_run | $pnp_run")
    exit 1
elif [[ $warning_state -eq "1" ]]; then
    echo $(echo "$out_run | $pnp_run")
    exit 2
else
    echo $(echo "$out_run | $pnp_run")
fi
}


if [[ $1 == '--help' ]] || [[ $# == 0 ]]; then
    usage
elif  [[ $# != 6 ]]; then
    syntax
fi

while getopts "w:c:p:" OPTS; do
    case $OPTS in
	w) WARNING_PERCENT=${OPTARG};;
	c) CRITICAL_PERCENT=${OPTARG};;
	p) PARTITIONS=${OPTARG};;
    esac
done

WARNING_LEVEL=$(echo $WARNING_PERCENT | tr -d '%')
CRITICAL_LEVEL=$(echo $CRITICAL_PERCENT | tr -d '%')

check_thresholds
calc_inodes
print_results
