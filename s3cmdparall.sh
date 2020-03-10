#!/bin/bash

<<EOF
cmd example
    put: ./test.sh -j 64 -f /run/s3tmp/binutils-2.27.tar
    get: ./test.sh -j 64 -g
    cln: ./test.sh -c
EOF

cachedir="/run/s3tmp/"
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
	file="$1"
	pr_notice "------caching file------"
	if ! [ -f $cachefile ] ;then
		cp $file  $cachefile
		sync
	fi
}

function s3cmdput(){
	bk=$1
	file=$2
	suffix=$3

    	filename="${file##*\/}"
	filestor="$filename.$suffix"
	pr_notice "s3cmdput starting file:%s filestor:%s" "$file" "$filestor"

    	stats=`s3cmd --no-progress --disable-multipart --no-check-md5 put  $file s3://$bk/$filestor | awk '{print "bytes,seconds,mb/s",$5,$8,$10}'`

	pr_notice "s3cmdput finished. file:%s, time: %s" "$filestor" "$stats"
}

function s3cmdputJobs(){
	opjobs=$1
	bk=$2
	file=$3
	idt=$4

	[[ $opjobs -eq 0 ]] && opjobs=4
	pr_debug "------s3cmdputJobs start :$opjobs-------"
	for i in `seq 1 $opjobs`;do
		s3cmdput $bk $file `printf "$idt.t%04d" "$i"` &
	done
	pr_debug "------s3cmdputJobs all start up: `date +%H:%M:%S`------"

	jobids=`echo $(jobs -p)`
	pr_debug "------jobs: %s" "$jobids"

	wait
	pr_debug "------s3cmdputJobs all finished:$opjobs-------"
}

function putloop(){
	loops=$1
	opjobs=$2
	bk=$3
	file=$4
	idt=$5

	[[ $loops -eq 0 ]] && loops=5
	[[ $opjobs -eq 0 ]] && opjobs=1
	[[ -f $file ]] || pr_err "file %s not exist" "$file"

	for i in `seq 1 $loops`;do
		pr_notice "------s3cmdput loop %2d: `date +%H:%M:%S`" "$i"
		s3cmdputJobs $opjobs $bk $file `printf "$idt.l%04d" "$i"`
		echo
	done
}

function put(){
    file=$1
    loops=$2
    opjobs=$3
    bk=$4
    idt=$5

    filename="${file##*\/}"
    cachefile=$cachedir/$filename
    file2cache $file $cachefile
    putloop $loops $opjobs $bk $cachefile $idt
}

function s3cmdget(){
	file=$1
	pr_notice "s3cmdget starting file: $file"
	elapsed=`{ time s3cmd get $file - > /dev/null; } 2>&1 | awk '{ if (NR==2) {print $2} }'`
	pr_notice "s3cmdget finished file: $file elapsed: $elapsed"
}

function s3cmdgetJobs(){
	filelist=$1
	fileNum=$2

	pr_debug "------s3cmdgetJobs filenum:$fileNum-------"
	for f in $filelist;do
		s3cmdget $f &
	done

	pr_debug "------s3cmdgetJobs all start up: `date +%H:%M:%S`------"

        jobids=`echo $(jobs -p)`
        pr_debug "------jobs: %s" "$jobids"
        wait
        pr_debug "------s3cmdgetJobs all finished: $opjobs-------"
}

function getloop(){
    file=$1
    loops=$2
    opjobs=$3
    bk=$4
    idt=$5

    [[ $loops -eq 0 ]] && loops=5
    [[ $opjobs -eq 0 ]] && opjobs=1

    if [ "$bk" == "X$bk" ];then
	lscmd="s3cmd ls"
    else
	lscmd="s3cmd ls s3://$bk"
    fi

    list=`$lscmd | awk '{print $NF}'`
    if [ "X$list" == "X" ] ;then
	pr_err "$lscmd list empty"
    fi
    rNum=`echo "$list" | wc -w`
    if [ $opjobs -lt $rNum ];then
	num=$opjobs
    else
	num=$rNum
    fi
    list=`echo $list | cut -d ' ' -f 1-$num`

    for i in `seq 1 $loops`;do
	pr_notice "------s3cmdget loop %2d: `date +%H:%M:%S`" "$i"
	s3cmdgetJobs "$list" "$num"
	echo
    done
}

function get(){
    file=$1
    loops=$2
    opjobs=$3
    bk=$4
    idt=$5

    getloop $file $loops $opjobs $bk $idt
}

function clean(){
	bk=$1
	pr_notice "------s3cmdclean--------"
	s3cmd rm --recursive --force s3://$bk
	pr_notice "------s3cmdclean finished. now list:------"
	s3cmd ls s3://$bk
}

function usage () {
	echo "Usage :  $0 [options]
		Options:
		    -h          this help
		    -l          loops num [$loops]
		    -j          jobs num  [$opjobs]
		    -i 		manual identify [$idt]
		    -b          target bucket [$bk]
		    -f          file to put/get [$file]
		    -g          do get . Now [$ops]
		    -c 		do clean . Now [$ops]
		    -v          more 'v' more msg [$verbose]
	"
    	exit 0
}


function main(){
    pr_debug "main pid: $$"
    ops="PUT"
    loops=1
    opjobs=1
    file="/home/iso/rhel-alt-server-7.5-ppc64le-dvd.iso"
    bk=111
    idt=`head /dev/urandom |cksum |md5sum |cut -c 1-9`

    while getopts "hl:j:vi:f:b:gc" opt;do
        case $opt in
            h)
                usage
                ;;
            g)
                ops="GET";
		;;
            c)
                ops="CLEAN";
		;;
            l)
                loops="$OPTARG";
                ;;
            j)
                opjobs="$OPTARG";
                ;;
            i)
                idt="$OPTARG";
                ;;
            f)
                file="$OPTARG";
		;;
            b)
                bk="$OPTARG";
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

    case $ops in
	"PUT")
    	    put $file $loops $opjobs $bk $idt
	    ;;
	"GET")
    	    get $file $loops $opjobs $bk $idt
	    ;;
	"CLEAN")
	    clean $bk
	    ;;
	*)
	    pr_err "unknown ops $ops"
	    ;;
    esac
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
