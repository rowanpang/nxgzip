#!/bin/bash

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

function pr_hint(){
    #33m,blue
    fmt="$1" && shift
    [ $verbose -ge 4 ] && printf -- "\033[1;38m""HINT! $fmt\n""\033[0m" "$@"
}

function startmon(){
    wkdir=$1
    cd $wkdir ; cp -f $monroot/monitor.sh .; ./monitor.sh `date +%m%d%H%M%S`; cd - > /dev/null
}

function stopmon(){
    wkdir=$1
    cd $wkdir; ./monitor.sh `date +%m%d%H%M%S`; cd - > /dev/null
}

function fratiofactor(){
    # fratiofactor $threads $loops $usize1 $mondir
    th=$1
    rpt=$2
    nbyte1=$((1 << $3))
    wkdir=$4
    pr_hint "fratiofactor starting-- sfnames: $sfnames ,engine: $engines ,wkdir: $wkdir ,byte1: $nbyte1 ,thread: $th ,loops: $rpt"

    if [ `echo $engines | grep -c nx` -ge 1 ];then
	cmd="LD_PRELOAD=$pathlibnx $nxenv numactl -N 0 $cmdgzip junk2 $th $rpt $engwk"
    else
	cmd="numactl -N 0 $cmdgzip junk2 $th $rpt $engwk"
    fi

    cd $wkdir; nmon  -f -s 1 -c $nmoncnt ;cd - > /dev/null ;sleep 5;

    isfirst="Yes"

    for f in ${sfnames/,/ };do
	if [ "X$isfirst" == "XYes" ];then
	    isfirst=""
	else
	    sleep $waitsec
	fi
	
	tmpf=$tmpdir/$f
	rm -rf junk2
	head -c $nbyte1 $tmpf > junk2
	ls -l junk2

	pr_hint "seedtmf: $tmpf ,size $nbyte1 ,starting $(date +%m%d%H%M%S)"
	startmon $wkdir
	eval $cmd
	stopmon $wkdir
	pr_debug "seedtmf: $tmpf ,size $nbyte1 ,finished $(date +%m%d%H%M%S),sleep $waitsec seconds"

    done

    pkill nmon
}

function ewkfactor(){
    th=$1
    rpt=$2
    nbyte1=$((1 << $3))
    wkdir=$4
    pr_hint "ewkfactor starting--,seedf: $seedf, engine: $engines, wkdir: $wkdir, byte1: $nbyte1, thread: $th, loops: $rpt"

    if [ `echo $engines | grep -c nx` -ge 1 ];then
	cmd="LD_PRELOAD=$pathlibnx $nxenv numactl -N 0 $cmdgzip junk2 $th $rpt"
    else
	cmd="numactl -N 0 $cmdgzip junk2 $th $rpt"
    fi

    rm -rf junk2
    head -c $nbyte1 $seedf > junk2
    ls -l junk2

    cd $wkdir; nmon  -f -s 1 -c $nmoncnt ;cd - > /dev/null ;sleep 5;
    pr_hint "compress starting $(date +%m%d%H%M%S)"
    startmon $wkdir
    eval $cmd -c
    stopmon $wkdir

    sleep $waitsec

    pr_hint "decompress starting $(date +%m%d%H%M%S)"
    startmon $wkdir
    eval $cmd -d
    stopmon $wkdir;pkill nmon
}

function sizefactor(){
    th=$1
    rpt=$2
    nbyte1=$((1 << $3))
    nbyte2=$((1 << $4))
    wkdir=$5
    pr_hint "sizefactor starting--,seedf: $seedf, engine: $engines, wkdir: $wkdir, byte1: $nbyte1, byte2: $nbyte2, thread: $th, loops: $rpt"

    if [ `echo $engines | grep -c nx` -ge 1 ];then
	cmd="LD_PRELOAD=$pathlibnx $nxenv numactl -N 0 $cmdgzip junk2 $th $rpt $engwk"
    else
	cmd="numactl -N 0 $cmdgzip junk2 $th $rpt $engwk"
    fi
    rm -rf junk2
    head -c $nbyte1 $seedf > junk2
    ls -l junk2

    cd $wkdir; nmon  -f -s 1 -c $nmoncnt ;cd - > /dev/null ;sleep 5;
    pr_hint "size $nbyte1 starting $(date +%m%d%H%M%S)"
    startmon $wkdir
    eval $cmd
    stopmon $wkdir

    sleep $waitsec
    rm -rf junk2
    head -c $nbyte2 $seedf > junk2
    ls -l junk2

    pr_hint "size $nbyte2 starting $(date +%m%d%H%M%S)"
    startmon $wkdir
    eval $cmd
    stopmon $wkdir;pkill nmon
}

function engfactor(){
    th=$1
    rpt=$2
    nbyte=$((1 << $3))
    wkdir=$4

    pr_hint "engfactor starting--,seedf: $seedf, engines: $engines, wkdir: $wkdir, byte: $nbyte, thread: $th, loops: $rpt"

    rm -rf junk2
    head -c $nbyte $seedf > junk2
    ls -l junk2

    cd $wkdir; nmon  -f -s 1 -c $nmoncnt ;cd - > /dev/null ;sleep 5;
    if [ `echo $engines | grep -c nx` -ge 1 ];then
	startmon $wkdir
	pr_hint "nx test starting $(date +%m%d%H%M%S)"
	eval LD_PRELOAD=$pathlibnx $nxenv numactl -N 0 $cmdgzip junk2 $th $rpt $engwk
	stopmon $wkdir
    fi

    if [ `echo $engines | grep -c zlib` -ge 1 ];then
	sleep $waitsec
	startmon $wkdir
	pr_hint "zlib test starting $(date +%m%d%H%M%S)"
	numactl -N 0 $cmdgzip junk2 $th $rpt $engwk
	stopmon $wkdir
    fi
    pkill nmon
}

usize=10
loops=1
threads=1
engines="nx,zlib"
nodes="0"
tmpdir="/run/nxgzip"
sfnames="cbtmpgen.txt"
cmdgzip="/home/pwz/nx/power-gzip/samples/compdecomp_th_dyn"
pathlibnx="/home/pwz/nx/libnxz.as13000.47e2c50.so"
engwk="-c"
nxenv=""
monroot="/root/nmon"
nmoncnt="60000"

runmode="sf"
waitsec=20

verbose="5"
function usage () {
    echo "Usage :  $0 [options]
	exp:
	    ./rtest.sh -r wf -e zlib -j 64 -l 1000000 -s 18;	#zlib下2^18数据块,压缩/解压缩下的差异
	    ./rtest.sh -r sf -e zlib -j 64 -l 1000000 -s 10,12; #zlib下2^10,2^12两种数据块压缩[-w '-d' 解压]时的性能差异
	    ./rtest.sh -r ef -j 64 -l 1000000 -s 12;	 	#对2^12次数据块nx与zlib压缩[-w '-d' 解压]性能差异
	    ./rtest.sh -r rf -j 64 -l 1000000 -s 12;		#分别测试seedf1,seedf2
	Options:
	    -h          this help
	    -s 		size [$usize,max 16MiB]
	    -l          loops num [$loops]
	    -j          jobs num  [$threads]
	    -n          nodes list  [$nodes]
	    -e          engines to test current [$engines]
	    -w 		engine work type [$engwk]
	    -r 		run mode [$runmode]
	    -a 		append nxgzip save fd env [ $nxenv ]
	    -f 		seedfnames,sperate by<,> must under $tmpdir [ $sfnames ]
	    -v          more 'v' more msg [$verbose]
    "
    exit 0
}

function main(){
    while getopts "hs:l:j:n:e:w:r:f:av" opt;do
        case $opt in
            h)
                usage
                ;;
	    s)
		usize="$OPTARG";
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
            e)
		engines="$OPTARG";
                ;;
	    w)
		engwk="$OPTARG"
		;;
            r)
		runmode="$OPTARG";
                ;;
            f)
		sfnames="$OPTARG";
                ;;
            a)
		nxenv="NX_GZIP_DIS_SAVDEVP=0"
                ;;
            v)
		let verbose+=1
                ;;
            :)
                echo "Need arguement $OPTARG"
                usage
                ;;
            \?)
                echo "Invalid option: $OPTARG"
                usage
                ;;

        esac
    done
    if [ `echo $engines | grep -c nx` -ge 1 ];then
	if [ "X$nxenv" != X ];then
		idtpend=".sfd"
	fi
    fi

    sfname=${sfnames/,*/}
    seedf=$tmpdir/$sfname

    idt="$runmode-$sfnames-$engines.#$engwk#.$usize.$loops.$threads${idtpend}.`date +%m%d%H%M%S`"
    mondir=$monroot/$idt; mkdir -p $mondir

    logf="$mondir/$idt.log"
    usize1=${usize/,*/}
    case $runmode in
	"sf")
	    if [ `echo $usize | grep -c ","` -eq 0 ];then
		pr_err "sizefactor test,need 2 log2 sizeparam, exp 4,8"
	    else
		usize2=${usize/*,/}
	    fi
	    sizefactor $threads $loops $usize1 $usize2 $mondir
	    ;;
	"ef")
	    engfactor $threads $loops $usize1 $mondir
	    ;;
	"wf")
	    ewkfactor $threads $loops $usize1 $mondir
	    ;;
	"rf")
	    fratiofactor $threads $loops $usize1 $mondir $sfnames
	    ;;
    esac 2>&1 | tee $logf

}
main $@
