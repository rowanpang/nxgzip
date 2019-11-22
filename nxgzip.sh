#!/bin/bash

loops=2
threads=1
todevnull="yes"
cmpZlib="yes"
options="-i 1MiB -o 1MiB"
nodes=

file="linux/git.tar"
fileName="${file##*\/}"
filemd5="bd422f5e2d9cb78e34e5a6f664bd87fb"

tmpdir='/run/'

verbose="5"
function pr_debug(){
    fmt="$1" && shift
    [ $verbose -ge 7 ] && printf -- "$fmt\n" "$@"
}

function pr_info(){
    fmt="$1" && shift
    [ $verbose -ge 6 ] && printf -- "$fmt\n" "$@"
}

function pr_notice(){
    fmt="$1" && shift
    [ $verbose -ge 5 ] && printf -- "$fmt\n" "$@"
}

function pr_warn(){
    #33m,yellow
    fmt="$1" && shift
    [ $verbose -ge 4 ] && printf -- "\033[1;33m""WARNING! $fmt\n""\033[0m" "$@"
}

function pr_err(){
    #31m,red
    fmt="$1" && shift
    [ $verbose -ge 3 ] && printf -- "\033[1;31m""ERROR! $fmt,Exit -1!\n""\033[0m" "$@"
    exit -1
}


function file2cache(){
	pr_notice "-----caching file"
	cat $file > /dev/null;
}

function nxgzipComp(){
	suffix=$1
	filegz="$tmpdir/$fileName.gz.$suffix"
	filetar="$tmpdir/$fileName.$suffix"
	[[ "$todevnull" == "yes" ]] && filegz="/dev/null";

	pr_debug "%04d: nxgzipComp starting" "$suffix"
	if [ "X$nodes" == "X" ]; then
	    time=`{ time LD_PRELOAD=/root/nxgzip/ver-0.59/nx-zlib_v0.59/libnxz.so ./genwqe_gzip $options $file -c > $filegz; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
	else
	    time=`{ time LD_PRELOAD=/root/nxgzip/ver-0.59/nx-zlib_v0.59/libnxz.so numactl -N $nodes ./genwqe_gzip $options $file -c > $filegz; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
	fi
	filegzSize=`stat -c %s $filegz`
	pr_notice "%04d: nxgzipComp finished $time,size $filegzSize" "$suffix"

	[[ "$todevnull" == "yes" ]] && return;

	gunzip	$filegz -c > $filetar
	[[ $? ]] && rm -f $filegz

	md5=`md5sum $filetar | awk '{print $1}'`
	if [ $md5 != $filemd5 ]; then
		pr_err "$suffix: md5 check error for orgfile: $file, gzipfile:$filegz, tarfile:$filetar"
		exit 1
	else
		pr_debug "$suffix: md5 check ok"
		rm -f $filetar
	fi
}

function zlibComp(){
	suffix=$1
	filegz="/dev/null"
	filegz="$tmpdir/$fileName.gz.$suffix"
	filetar="$tmpdir/$fileName.$suffix"
	[[ "$todevnull" == "yes" ]] && filegz="/dev/null";

	pr_debug "%04d: zlibComp starting" "$suffix"
	time=`{ time ./genwqe_gzip $options $file -c > $filegz; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
	filegzSize=`stat -c %s $filegz`
	pr_notice "%04d: zlibComp finished $time, size $filegzSize" "$suffix"
	[[ "$todevnull" == "yes" ]] && return;

	rm -f $filegz
}

function nxgzipThread(){
	threads=$1
	pr_debug "--------nxgzipThread start :$threads-------"
	[[ $threads -eq 0 ]] && threads=4

	for i in `seq 1 $threads`;do
		nxgzipComp $i &
	done
	pr_debug "-------nxgzipThread all start up: `date +%H:%M:%S`------"
	jobids=`echo $(jobs -p)`
	pr_debug "-------jobs: %s" "$jobids"

	wait
	pr_debug "--------nxgzipThread all finished:$threads-------"
}

function zlibThread(){
	pr_debug "--------zlibThread start :$threads-------"
	threads=$1
	[[ $threads -eq 0 ]] && threads=4
	for i in `seq 1 $threads`;do
		zlibComp $i &
	done
	pr_debug "-------zlibThread all start up: `date +%H:%M:%S`------"
	jobids=`echo $(jobs -p)`
	pr_debug "-------jobs: %s" "$jobids"

	wait
	pr_debug "--------zlibThread all finished:$threads-------"
}

function loopTest(){
	loops=$1
	threads=$2
	[[ $loops -eq 0 ]] && loops=5
	[[ $threads -eq 0 ]] && threads=1
	for i in `seq 1 $loops`;do
		pr_notice "-----nxgzip loop %2d: `date +%H:%M:%S`" "$i"
		nxgzipThread $threads
		echo
	done

	[[ $cmpZlib == "yes" ]] || return

	for i in `seq 1 $loops`;do
		pr_notice "-----zlib loop %2d: `date +%H:%M:%S`" "$i"
		zlibThread $threads
		echo
	done
}

function usage () {
	echo "Usage :  $0 [options]
		Options:
		    -h          this help
		    -l          loops num [$loops]
		    -j          jobs num  [$threads]
		    -n          nodes list  [$nodes]
		    -o          not devnull [$todevnull]
		    -z          not cmpZlib [$cmpZlib]
		    -d          for genwqe_gzip  use defualt options [$options]
		    -v          more 'v' more msg [$verbose]
	"
    	exit 0
}


function main(){
    while getopts "hl:j:bzvn:" opt;do
        case $opt in
            h)
                usage
                ;;
            l)
                loops="$OPTARG";
                ;;
            j)
                threads="$OPTARG";
                ;;
            o)
                todevnull="no";
                ;;
            n)
                nodes="$OPTARG";
                ;;
            d)
		options=""
                ;;
            z)
		cmpZlib="no"
                ;;
            v)
		let verbose+=1
                ;;
            :)
                echo "--Need arguement $OPTARG"
                usage
                ;;
            \?)
                echo "Invalid option: $OPTARG"
                usage
                ;;

        esac
    done

    pr_debug "pid: $$"
    file2cache
    loopTest $loops $threads
}

trap 'onCtrlC' INT
function onCtrlC () {
    pr_notice 'Ctrl+C is captured'
    jobids=`echo $(jobs -p)`
    pr_debug "do kill $jobids,Exit 0"
    kill $jobids
    exit 0
}


main $@
