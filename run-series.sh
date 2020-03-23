#!/bin/bash

plotfn=nx-log.log
echo "nx begin"
min=0
max=20
cmd=/home/pwz/nx/power-gzip/samples/compdecomp_th_dyn
for th in 1 2 4 8 16 32 64
do
    for a in `seq $min $max`  # size
    do
	b=$((1 << $a))
	nbyte=$(($b * 1024))
	rpt=$((1000 * 1000 * 1000 * 10)) # 10GB
	rpt=$(( ($rpt+$nbyte-1)/$nbyte )) # iters
	rpt=$(( ($rpt+$th-1)/$th )) # per thread
	rm -f junk2
	head -c $nbyte $1 > junk2;
	ls -l junk2;
	LD_PRELOAD=/home/pwz/nx/libnxz.as13000.47e2c50.so NX_GZIP_DIS_SAVDEVP=0 numactl -N 0 $cmd junk2 $th $rpt
    done
done  > $plotfn 2>&1

exit
echo "nx finished,gzip begin"

plotfn=zlib-log.log
for th in 1 2 4 8 16 32 64
do
    for a in `seq $min $max`  # size
    do
	b=$((1 << $a))
	nbyte=$(($b * 1024))
	rpt=$((1000 * 1000 * 1000 * 10)) # 10GB
	rpt=$(( ($rpt+$nbyte-1)/$nbyte )) # iters
	rpt=$(( ($rpt+$th-1)/$th )) # per thread
	rm -f junk2
	head -c $nbyte $1 > junk2;
	ls -l junk2;
	numactl -N 0 $cmd junk2 $th $rpt
    done
done  > $plotfn 2>&1
