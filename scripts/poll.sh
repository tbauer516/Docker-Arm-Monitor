#!/bin/bash

SLEEP=30
POLL=30 #0.1

TEMPNET="$(dirname $0)/tmpnet"
TEMPCPU="$(dirname $0)/tmpcpu"
TEMPTOP="$(dirname $0)/tmptop"

echo "Press [CTRL+C] to stop..."

function getNetwork {
	local net=$(cat /proc/net/dev | grep 'eth0:' | awk '{ print $1" "$2" "$10; }')
	echo "$net"
	#read netnme netrec netout <<< $(cat /proc/net/dev | awk 'NR==3 { print $1" "$2" "$10; }')
}

function getNetRate {
	local net1=( $(getNetwork) )
	sleep $POLL
	local net2=( $(getNetwork) )
	local netInTotal=${net2[1]}
	local netOutTotal=${net2[2]}
	local netName=$(echo "${net2[0]}" | sed 's/://g')
	#local netIn=$(awk -v poll=$POLL -v r2=$NETINTOT -v r1=$rec1 'BEGIN { print (r2 - r1) / poll; }')
	local netIn=$(echo "scale=4; $(( $netInTotal - ${net1[1]})) * 100 / $POLL" | bc)
	#local netOut=$(awk -v poll=$POLL -v o2=$NETOUTTOT -v o1=$out1 'BEGIN { print (o2 - o1) / poll; }')
	local netOut=$(echo "scale=4; $(( $netOutTotal - ${net1[2]})) * 100 / $POLL" | bc)
	echo "$netName $netIn $netOut $netInTotal $netOutTotal" > $TEMPNET
}

function getStat {
	local cpustats=$(cat /proc/stat)
	echo "$cpustats"
}

function getCPU {
	if [ -z "$2" ]; then local row=1; else local row=$(($2+2)); fi
	local cpustat=$(echo "$1" | awk -v row=$row 'NR==row { print $1" "$2" "$3" "$4" "$5" "$6" "$7" "$8 }')
	echo "$cpustat"
}

function getCPUUse {
	local cpu1=()
	local cpu2=()

	local cpustats
	local cpustat

	for i in {1..2}; do

		if [ "$i" -gt "1" ];
			then sleep $POLL
		fi

		cpustats=$(getStat)

		for j in {0..3}; do
			cpustat=$(getCPU "$cpustats" "$j")
			if [ "$i" == "1" ];
				then cpu1[$j]="$cpustat";
				else cpu2[$j]="$cpustat";
			fi
		done
	done

	local stats1 stats2 previdl idl prevnidl nidl prevtot tot totd idld subd final
	local diff=()

	for i in {0..3}; do
		# nme usr nce sys idl iow irq sof
		stats1=( $(echo "${cpu1[$i]}") )
		stats2=( $(echo "${cpu2[$i]}") )

		previdl=$(( ${stats1[4]} + ${stats1[5]} ))
		idl=$(( ${stats2[4]} + ${stats2[5]} ))

		prevnidl=$(( ${stats1[1]} + ${stats1[2]} + ${stats1[3]} + ${stats1[6]} + ${stats1[7]} ))
		nidl=$(( ${stats2[1]} + ${stats2[2]} + ${stats2[3]} + ${stats2[6]} + ${stats2[7]} ))

		prevtot=$(( $previdl + $prevnidl ))
		tot=$(( $idl + $nidl ))

		totd=$(( $tot - $prevtot ))
		idld=$(( $idl - $previdl ))

		subd=$(( $totd - $idld ))
		final=$(echo "scale=2; $(( $totd - $idld)) / $totd * 100" | bc)

		diff[$i]="$final"

	done
	echo "${diff[*]}" > $TEMPCPU
}

function getTop {
	local top=$(top -b -n 2 -d $POLL)
	echo "$top" > $TEMPTOP
}

while :
do

#	TOP=$(top -b -n 2 -d 0.01)
#	MPSTATA=$(mpstat -P ALL)
	DF=$(df --exclude-type tmpfs --exclude-type devtmpfs)
	getNetRate &
	getCPUUse &
	getTop &

	wait

	TOP=$(cat "$TEMPTOP")

	CPUUSE=$(echo "$TOP" | grep '^%Cpu' | tail -n 1 | awk '{ print $2 + $4 + $6; }')

	CPUTMP=$(cat /sys/class/hwmon/hwmon0/temp1_input | awk '{ print $1 / 1000; }')

	MEMTOT=$(echo "$TOP" | grep '^KiB Mem' | tail -n 1 | awk '{ print $4; }')
	MEMFRE=$(echo "$TOP" | grep '^KiB Mem' | tail -n 1 | awk '{ print $6; }')
	MEMUSE=$(echo "$TOP" | grep '^KiB Mem' | tail -n 1 | awk '{ print $8; }')
	MEMAVA=$(echo "$TOP" | grep '^KiB Swap' | tail -n 1 | awk '{ print $9; }')
	MEMBFC=$(echo "$TOP" | grep '^KiB Mem' | tail -n 1 | awk '{ print $10; }')

	SWAPTOT=$(echo "$TOP" | grep '^KiB Swap' | tail -n 1 | awk '{ print $3; }')
	SWAPFRE=$(echo "$TOP" | grep '^KiB Swap' | tail -n 1 | awk '{ print $5; }')
	SWAPUSE=$(echo "$TOP" | grep '^KiB Swap' | tail -n 1 | awk '{ print $7; }')

	UPTIME=$(cat /proc/uptime | awk '{ print $1; }')

	STORAGECNT=$(echo "$DF" | awk 'END { print NR; }')
	#can set NR>=2 for range
	STORAGENME=$(echo "$DF" | awk 'NR==2&&NR<='$STORAGECNT' { print $1; }')
	STORAGETOT=$(echo "$DF" | awk 'NR==2&&NR<='$STORAGECNT' { print $3 + $4; }')
	STORAGEUSE=$(echo "$DF" | awk 'NR==2&&NR<='$STORAGECNT' { print $3; }')
	STORAGEAVA=$(echo "$DF" | awk 'NR==2&&NR<='$STORAGECNT' { print $4; }')

	NET=$(cat "$TEMPNET")
	NETNME=$(echo "$NET" | awk '{ print $1; }')
	NETIN=$(echo "$NET" | awk '{ print $2; }')
	NETOUT=$(echo "$NET" | awk '{ print $3; }')
	NETINTOT=$(echo "$NET" | awk '{ print $4; }')
	NETOUTTOT=$(echo "$NET" | awk '{ print $5; }')

	CPU=$(cat "$TEMPCPU")
	CPUUSE0=$(echo "$CPU" | awk '{ print $1; }')
	CPUUSE1=$(echo "$CPU" | awk '{ print $2; }')
	CPUUSE2=$(echo "$CPU" | awk '{ print $3; }')
	CPUUSE3=$(echo "$CPU" | awk '{ print $4; }')

	$(rm "$TEMPNET")
	$(rm "$TEMPCPU")
	$(rm "$TEMPTOP")

	# echo $MEMTOT
	# echo $MEMFRE
	# echo $MEMUSE
	# echo $MEMAVA
	# echo $MEMBFC

	# echo $SWAPTOT
	# echo $SWAPFRE
	# echo $SWAPUSE

	# echo $UPTIME

	# echo $STORAGENME
	# echo $STORAGETOT
	# echo $STORAGEUSE
	# echo $STORAGEAVA

	# echo $NETNME
	# echo $NETIN
	# echo $NETOUT
	# echo $NETINTOT
	# echo $NETOUTTOT

	# echo $CPUUSE
	# echo $CPUUSE0
	# echo $CPUUSE1
	# echo $CPUUSE2
	# echo $CPUUSE3

	# echo $CPUTMP

	curl -i -XPOST 'http://localhost:8086/write?db=home' --data-binary "
	use_stats,host=c2,type=cpu,name=usage value=$CPUUSE
	use_stats,host=c2,type=cpu,name=usage,core=0 value=$CPUUSE0
	use_stats,host=c2,type=cpu,name=usage,core=1 value=$CPUUSE1
	use_stats,host=c2,type=cpu,name=usage,core=2 value=$CPUUSE2
	use_stats,host=c2,type=cpu,name=usage,core=3 value=$CPUUSE3
	use_stats,host=c2,type=cpu,name=temp value=$CPUTMP
	use_stats,host=c2,type=memory,name=total value=$MEMTOT
	use_stats,host=c2,type=memory,name=free value=$MEMFRE
	use_stats,host=c2,type=memory,name=used value=$MEMUSE
	use_stats,host=c2,type=memory,name=available value=$MEMAVA
	use_stats,host=c2,type=memory,name=buff_cache value=$MEMBFC
	use_stats,host=c2,type=swap,name=total value=$SWAPTOT
	use_stats,host=c2,type=swap,name=free value=$SWAPFRE
	use_stats,host=c2,type=swap,name=used value=$SWAPUSE
	use_stats,host=c2,type=uptime,name=uptime value=$UPTIME
	use_stats,host=c2,type=storage,name=total,device=$STORAGENME value=$STORAGETOT
	use_stats,host=c2,type=storage,name=used,device=$STORAGENME value=$STORAGEUSE
	use_stats,host=c2,type=storage,name=available,device=$STORAGENME value=$STORAGEAVA
	use_stats,host=c2,type=network,name=rate_in,interface=$NETNME value=$NETIN
	use_stats,host=c2,type=network,name=rate_out,interface=$NETNME value=$NETOUT
	use_stats,host=c2,type=network,name=total_in,interface=$NETNME value=$NETINTOT
	use_stats,host=c2,type=network,name=total_out,interface=$NETNME value=$NETOUTTOT
	"

	#sleep "$SLEEP"

done
