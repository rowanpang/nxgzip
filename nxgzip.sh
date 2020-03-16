#!/bin/bash

loops=1
threads=2
todevnull="yes"
cmpZlib="yes"
options="-i 1MiB -o 1MiB"
nodes=
wktype="comp"

tmpdir='/run/nxgzip'
cmdgzip="/root/nx/git/genwqe_gzip"
pathlibnx="/root/nx/libnxz.as13000.47e2c50.so"

#put file in ram basedfs so ignore disk io limit.
fcomp="$tmpdir/git.tar"
fcompname="${fcomp##*\/}"
fcompmd5="bd422f5e2d9cb78e34e5a6f664bd87fb"

fdcomp="$tmpdir/git.tar.gz"
fdcompname="${fdcomp##*\/}"
fdcompmd5="bd422f5e2d9cb78e34e5a6f664bd87fb"


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


function nxComp(){
    sfx=$1
    fgz="$tmpdir/$fcompname.gz.$sfx"
    ftar="$tmpdir/$fcompname.$sfx"
    [[ "$todevnull" == "yes" ]] && fgz="/dev/null";

    pr_debug "%04d: nxComp starting,fcomp: $fcomp" "$sfx"
    if [ "X$nodes" == "X" ]; then
	cmd="LD_PRELOAD=$pathlibnx $cmdgzip $options $fcomp -c > $fgz"
    else
	cmd="LD_PRELOAD=$pathlibnx numactl -N $nodes $cmdgzip $options $fcomp -c > $fgz"
    fi
    secspent=`{ time eval $cmd; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
    fcompSize=`stat -c %s $fcomp`
    pr_notice "%04d: nxComp finished,time spend: $secspent, fcomp size: $fcompSize" "$sfx"

    [[ $fgz == "/dev/null" ]] && return;

    gunzip $fgz -c > $ftar
    [[ $? ]] && rm -f $fgz

    md5=`md5sum $ftar | awk '{print $1}'`
    if [ $md5 != $filemd5 ]; then
	pr_err "$sfx: md5 check error for orgfile: $file, gzipfile:$fgz, tarfile:$ftar"
	exit 1
    else
	pr_debug "$sfx: md5 check ok"
	rm -f $ftar
    fi
}

function nxdcomp(){
    sfx=$1
    ftar="$tmpdir/$fdcompname.$sfx.tar"
    [[ "$todevnull" == "yes" ]] && ftar="/dev/null";
    pr_debug "%04d: nxdcomp starting,fdcomp: $fdcomp" "$sfx"

    if [ "X$nodes" == "X" ]; then
	cmd="LD_PRELOAD=$pathlibnx $cmdgzip $options -d $fdcomp -c > $ftar"
    else
	cmd="LD_PRELOAD=$pathlibnx numactl -N $nodes $cmdgzip $options -d $fdcomp -c > $ftar"
    fi
    #secspent=`{ time LD_PRELOAD=$pathlibnx $cmdgzip $options -d $fdcomp -c > $ftar; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
    secspent=`{ time eval $cmd; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
    fdcompSize=`stat -c %s $fdcomp`
    pr_notice "%04d: nxdcomp finished,time spend: $secspent, fdcomp size: $fdcompSize" "$sfx"

    [[ $ftar == "/dev/null" ]] && return;

    md5=`md5sum $ftar | awk '{print $1}'`
    if [ $md5 != $fdcompmd5 ]; then
	pr_err "$sfx: md5 check error for orgfile: $fdcomp, tarfile:$ftar"
	exit 1
    else
	pr_debug "$sfx: md5 check ok"
	rm -f $ftar
    fi
}

function zlibComp(){
    sfx=$1
    fgz="/dev/null"
    fgz="$tmpdir/$fileName.gz.$sfx"
    [[ "$todevnull" == "yes" ]] && fgz="/dev/null";

    pr_debug "%04d: zlibComp starting,fcomp: $fcomp" "$sfx"

    if [ "X$nodes" == "X" ]; then
        cmd="$cmdgzip $options $fcomp -c > $fgz"
    else
        cmd="numactl -N $nodes $cmdgzip $options $fcomp -c > $fgz"
    fi
    secspent=`{ time eval $cmd; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
    fcompSize=`stat -c %s $fcomp`
    pr_notice "%04d: zlibcomp finished,time spend: $secspent, fcomp size: $fcompSize" "$sfx"

    [[ $fgz == "/dev/null" ]] && return;

    rm -f $fgz
}

function zlibdcomp(){
    sfx=$1
    ftar="$tmpdir/$fdcompname.$sfx.tar"
    [[ "$todevnull" == "yes" ]] && ftar="/dev/null";

    pr_debug "%04d: zlibdcomp starting,fdcomp: $fdcomp" "$sfx"

    if [ "X$nodes" == "X" ]; then
	cmd="$cmdgzip $options -d $fdcomp -c > $ftar"
    else
	cmd="numactl -N $nodes $cmdgzip $options -d $fdcomp -c > $ftar"
    fi
    secspent=`{ time eval $cmd; } 2>&1 | awk '{ if( NR==2 ) {print $2}}'`
    fdcompSize=`stat -c %s $fdcomp`
    pr_notice "%04d: zlibcomp finished,time spend: $secspent, fdcomp size: $fdcompSize" "$sfx"

    [[ $ftar == "/dev/null" ]] && return;

    rm -f $ftar

}

function nxThread(){
    threads=$1
    pr_debug "--------nxThread start :$threads-------"
    [[ $threads -eq 0 ]] && threads=4

    for i in `seq 1 $threads`;do
	if [ "X$wktype" = "Xdecomp" ];then
	    nxdcomp $i &
	else
	    nxComp $i &
	fi
    done
    pr_debug "-------nxThread all start up: `date +%H:%M:%S`------"
    jobids=`echo $(jobs -p)`
    pr_debug "-------jobs: %s" "$jobids"

    wait
    pr_debug "--------nxThread all finished:$threads-------"
}

function zlibThread(){
    pr_debug "--------zlibThread start :$threads-------"
    threads=$1
    [[ $threads -eq 0 ]] && threads=4
    for i in `seq 1 $threads`;do
	if [ "X$wktype" = "Xdecomp" ];then
	    zlibdcomp $i &
	else
	    zlibComp $i &
	fi
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
	pr_notice "-----nx loop %2d: `date +%H:%M:%S`" "$i"
	nxThread $threads
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
	    -f 		target file [comp: $fcomp, dcomp: $fdcomp]
	    -l          loops num [$loops]
	    -j          jobs num  [$threads]
	    -n          nodes list  [$nodes]
	    -i          ignore output file, current [$todevnull]
	    -z          if compare to libz current [$cmpZlib]
	    -r          reset preptions [$options]
	    -d          do decmprees [$wktype]
	    -v          more 'v' more msg [$verbose]
    "
    exit 0
}

function main(){
    while getopts "hf:l:j:n:izrdv" opt;do
        case $opt in
            h)
                usage
                ;;
	    f)
		fcomp="$OPTARG";
		fdcomp="$OPTARG";
		;;
            l)
                loops="$OPTARG";
                ;;
            j)
                threads="$OPTARG";
                ;;
            n)
                nodes="$OPTARG";
                ;;
            i)
                todevnull="no";
                ;;
            z)
		cmpZlib="no"
                ;;
            r)
		options=""
                ;;
            d)
		wktype="decomp"
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
