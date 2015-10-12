#!/system/bin/sh

# This is a startup script designed for /system/etc/init.d/.
# Note that "run-parts" support (for init.d/ scripts) is normally provided by custom a initramfs,
# which should bundle busybox in /sbin/. The /sbin/run-parts.sh script should take care of
# running init scripts (by calling /sbin/runparts), and it should subsequently trigger
# the device startup (using "setprop filesystem.ready 1", or similar).
# Note that the recovery mode typically doesn't run /system/etc/init.d/ startup scripts.

# Ensure /sbin/busybox takes precedence.
# Normally this is redundant, because the /init.rc startup script already sets the correct path.
export PATH=/sbin:$PATH

# Logging of old/new sysfs values, useful for double-checking.
logFile=/data/local/tmp/S_perf_tweaks.log

if [ -f $logFile ]
then
rm $logFile
fi

touch $logFile

# This function logs the old value and writes the new value.
echo_()
{
	echo '' >> $logFile
	echo -n "${2}${3} (${1}): " >> $logFile
	#head -1 ${2}${3} >> $logFile
	#read $firstLine < ${2}${3}
	#echo -n $firstLine >> $logFile
	contents=`echo -n $(cat ${2}${3})`
	echo -n $contents >> $logFile
	echo -n " ---> " >> $logFile
	echo $1 > ${2}${3}
	contents=`echo -n $(cat ${2}${3})`
	echo -n $contents >> $logFile
}

# Note that the settings pushed by VoltageControl.apk
# could also be managed here (this only applies to kernels with clock/frequency tables and undervolt sysfs support):
#echo_ "50 50 50 25 25 25 25 " "/sys/devices/system/cpu/cpu0/cpufreq" "/UV_mV_table"
#echo_ 1400000 "/sys/devices/system/cpu/cpu0/cpufreq" "/scaling_max_freq"

echo "---------" >> $logFile

# Remount all partitions that use relatime with noatime and nodiratime instead.
# Note: atime generates a write-after-every-read, relatime is an optimized version of atime.
for k in $(mount | grep relatime | cut -d " " -f3)
do
	echo "mount -o remount,noatime,nodiratime $k" >> $logFile
	sync
	mount -o remount,noatime $k
done

# Here is a sample test to measure read/write performance on rfs partitions:
### test for write: dd if=/dev/zero of=/data/test count=30000
### test for read:  dd if=/data/test of=/dev/zero

echo "---------" >> $logFile

# Log the mount table
mount >> $logFile

echo "---------" >> $logFile

# Optimize the cfq/bfq I/O scheduler for flash memory (defaults are designed for spinning harddisks).
# Lower the idle wait, re-enable the low latency mode, remove the penalty for back-seeks,
# and explicitly tell the kernel that the storage is not a spinning disk.

for i in $(ls -1 /sys/block/stl*) $(ls -1 /sys/block/mmc*) $(ls -1 /sys/block/bml*) $(ls -1 -d /sys/block/tfsr*)
#for i in `ls /sys/block/stl* /sys/block/mmc* /sys/block/bml* /sys/block/tfsr*`;
do
	# DEF noop anticipatory deadline cfq [bfq]
	echo_ "bfq" $i "/queue/scheduler"
	
	# DEF 1 ?
	echo_ "0" $i "/queue/rotational"
	
	# DEF 1 ?
	echo_ "1" $i "/queue/iosched/low_latency"
	
	# DEF 2 ?
	echo_ "1" $i "/queue/iosched/back_seek_penalty"
	
	# DEF 16384 ?
	echo_ "1000000000" $i "/queue/iosched/back_seek_max"
	
	# DEF 6 ?
	echo_ "3" $i "/queue/iosched/slice_idle"
	
	sync
done

# Set tendency of kernel to swap to minimum, since swap isn't used anyway.
# (swap = move portions of RAM data to disk partition or file, to free-up RAM)
# (a value of 0 means "do not swap unless out of free RAM", a value of 100 means "swap whenever possible")
# (the default is 60 which is okay for normal Linux installations)

# DEF 60
echo_ "0" "/proc/sys/vm" "/swappiness"

# Lower the amount of unwritten write cache to reduce lags when a huge write is required.

# DEF 20
echo_ "10" "/proc/sys/vm" "/dirty_ratio"

# Increase minimum free memory, in theory this should make the kernel less likely to suddenly run out of memory.

# DEF 3102
echo_ "4096" "/proc/sys/vm" "/min_free_kbytes"

# Increase tendency of kernel to keep block-cache to help with slower RFS filesystem.

# DEF 100
echo_ "1000" "/proc/sys/vm" "/vfs_cache_pressure"

# Increase the write flush timeouts to save some battery life.

# DEF 250
echo_ "2000" "/proc/sys/vm" "/dirty_writeback_centisecs"

# DEF 200
echo_ "1000" "/proc/sys/vm" "/dirty_expire_centisecs"

# Make the task scheduler more 'fair' when multiple tasks are running,
# which improves user-interface and application responsiveness.

# DEF 10000000
echo_ "20000000" "/proc/sys/kernel" "/sched_latency_ns"

# DEF 2000000
echo_ "2000000" "/proc/sys/kernel" "/sched_wakeup_granularity_ns"

# DEF 1000000
echo_ "1000000" "/proc/sys/kernel" "/sched_min_granularity_ns"

sync

# Miscellaneous tweaks
setprop dalvik.vm.startheapsize 8m
#setprop wifi.supplicant_scan_interval 90

echo '' >> $logFile
echo "---------" >> $logFile



#This apply a tweaked deadline scheduler to all RFS (and ext2/3/4, if existent) partitions.
#for i in /sys/block/*
#do
	# DEF noop anticipatory deadline cfq [bfq]
	#echo deadline > $i/queue/scheduler
	
	#echo 4 > $i/queue/iosched/writes_starved
	#echo 1 > $i/queue/iosched/fifo_batch
	#echo 256 > $i/queue/nr_requests
#done