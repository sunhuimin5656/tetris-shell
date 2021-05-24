#!/bin/bash 

# 屏幕大小
length=20
hight=15

# 方块信息变量
color="40"
box=()
offset=0
let base_xpos=1
let base_ypos=length/2-1
depth=()
map=()
score=0
last_score=0

# 进程通信信号
left_signal=20
right_signal=21
down_signal=22
arrate_signal=23
quit_signal=24

#-------------------------------------------------------------------------------------
# 产生方块形状和颜色
function create_new_shape(){
	local colbox=(41 42 43 44 45 46 47)
	local num
	let color=colbox[$RANDOM%7]
	let num=$RANDOM%5
	case $num in
		"0")
			box=(0 0 0 2 1 0 1 2) 
			;;
		"1")
			box=(0 2 1 0 1 2 1 4 0 2 1 2 1 4 2 2 1 0 1 2 1 4 2 2 0 2 1 0 1 2 2 2)
			;;
		"2")
			box=(0 0 1 0 1 2 1 4 0 2 0 4 1 2 2 2 1 0 1 2 1 4 2 4 0 2 1 2 2 0 2 2)
			;;
		"3")
			box=(0 4 1 0 1 2 1 4 0 2 1 2 2 2 2 4 1 0 1 2 1 4 2 0 0 0 0 2 1 2 2 2)
			;;
		*) 
			box=(0 2 1 2 2 2 3 2 1 0 1 2 1 4 1 6)
			;;
	esac
}

# 画得分 
function draw_score(){
	local xpos ypos
	xpos=5
	let ypos=length+5
	echo -e "\033[34m"
	echo -e "\033[${xpos};${ypos}Hscore : "
	let xpos++
	echo -e "\033[${xpos};${ypos}H${score}\033[0m"
}

# 画方块形状
function draw_shape(){
	local opt=$1
	local ipos xpos ypos
	if [ $opt -ne 0 ];then
		echo -e "\033[${color}m"
	else
		echo -e "\033[30;40m"
	fi
	for((i=0;i<4;i++))
	do
		let ipos=2*i+offset*8
		let xpos=base_xpos+box[ipos]
		let ypos=base_ypos+box[ipos+1]
		echo -e "\033[${xpos};${ypos}H  "
	done
	echo -e "\033[0m"
	draw_score
}
#-------------------------------------------------------------------------------------
# depth map 变量的判断处理
# 初始化图深度和积累形状
function init_depth_map(){
	local pos
	for((i=0;i<length;i++))
	do
		let depth[i]=hight+1
	done
	for((i=0;i<hight;i++))
	do
		for((j=0;j<length;j++))
		do
			let pos=i*length+j
			let map[pos]=40
		done
	done
}

# 方块落地，更新map depth
function update_depth_map(){
	local xpos ypos ipos dpos mpos
	local temp
	let temp=score-last_score
	for((i=0;i<4;i++))
	do
		let ipos=2*i+offset*8
		let xpos=base_xpos+box[ipos]
		let ypos=base_ypos+box[ipos+1]
		let dpos=ypos-1
		if [ $xpos -lt ${depth[$dpos]} ];then
			depth[$dpos]=$xpos
			depth[$dpos+1]=$xpos
		elif [ ${depth[$dpos]} -le 1 -a $temp -eq 0 ];then
			kill -${quit_signal} $ppid
			#发送不成功，可能无法退出，（方块堆满立即按enter影响脚本）
		fi
		let mpos=(xpos-1)*length+ypos-1
		map[$mpos]=$color
		map[$mpos+1]=$color
	done
}

# 解决上方方块消除，下方方块没填完的情况
# 方块消除后的depth
function depth_refresh(){
	local temp
	let temp=score-last_score
	[ $temp -eq 0 ] && return 0
	local i j pos
	for((j=0;j<length;j++))
	do
		for((i=0;i<hight;i++))
		do
			let pos=i*length+j
			[ ${map[$pos]} -ne '40' ] && break
		done
		let depth[j]=i+1
	done
	let last_score=score
}

# 方块消除后的map
function map_refresh(){
	local k=$1
	local i j
	local apos bpos
	if [ $k -eq 0 ];then
		for((j=0;j<length;j++))
		do
			let map[j]=40
		done
		return 0
	fi
	for((i=$k;i>0;i--))
	do
		for((j=0;j<length;j++))
		do
			let apos=i*length+j
			let bpos=(i-1)*length+j
			let map[apos]=map[bpos]
		done
	done
}

# 方块消除后，更新map depth
function by_delete_update_depth_map(){
	local i j
	local pos
	for((i=0;i<hight;i++))
	do
		for((j=0;j<length;j++))
		do
			let pos=i*length+j
			[ ${map[$pos]} -eq 40 ] && break
		done
		if [ $j -eq $length ];then
			map_refresh $i
			let score++
		fi
	done 
	depth_refresh
}

# 画map 在屏幕里的方块
function draw_map(){
	local opt=$1
	local ipos xpos ypos
	for((i=0;i<hight;i++))
	do
		for((j=0;j<length;j++))
		do
			let xpos=i+1
			let ypos=j+1
			let ipos=i*length+j
			[[ -z $opt ]] && echo -e "\033[${map[$ipos]}m"
			[[ -n $opt ]] && echo -e "\033[40m"
			echo -e "\033[${xpos};${ypos}H \033[0m"
		done
	done
}
#-------------------------------------------------------------------------------------

# 判断移动位置是否越界
function ismove(){
	local basex=$1
	local basey=$2
	local off=$3
	local xpos ypos ipos dpos
	for((i=0;i<4;i++))
	do
		let ipos=2*i+off*8
		let xpos=basex+box[ipos]
		let ypos=basey+box[ipos+1]
		let dpos=ypos-1
		[[ -z ${depth[$dpos]} ]] && return 1
		[ $xpos -lt 1 -o $xpos -gt $hight ] && return 1
		[ $ypos -lt 1 -o $ypos -gt $(($length-1)) ] && return 1
		[ $xpos -ge ${depth[$dpos]} ] && return 1
	done
	return 0
}

function step_left(){
	local basey
	let basey=base_ypos-2
	ismove $base_xpos $basey $offset || return 1
	let base_ypos=basey
}

function step_right(){
	local basey
	let basey=base_ypos+2
	ismove $base_xpos $basey $offset || return 1
	let base_ypos=basey
}

function step_down(){
	local basex
	let basex=base_xpos+1
	ismove $basex $base_ypos $offset
	if [ $? -eq 0 ];then
		let base_xpos++
		return 0
	fi
	update_depth_map
	draw_map 0
	by_delete_update_depth_map
	draw_map

	#初始化变量
	create_new_shape
	base_xpos=1
	let base_ypos=length/2-1
	offset=0
	return 1
}

function step_arrate(){
	local off
	let off=offset+1
	let n=${#box[@]}/8
	let off=off%n
	ismove $base_xpos $base_ypos $off || return 1
	let offset=off
	return 0
}

#-------------------------------------------------------------------------------------

function interrupt(){
	local sig=$1
	case $sig in
			"a"|"A")
				step_left
				;;
			"d"|"D")
				step_right
				;;
			"s"|"S")
				step_down
				;;
			"w"|"W")
				step_arrate
				;;
			"q")
				printf "\033[%d;%dH" $hight $length
				exit 0
				;;
			"*")
				;;
	esac
}

#画图
function draw_picture(){
	local sig
	draw_map 
	while true :
	do
		sig=""
		trap "sig=a" ${left_signal}
		trap "sig=d" ${right_signal}
		trap "sig=s" ${down_signal}
		trap "sig=w" ${arrate_signal}
		trap "printf \"\033[%d;%dH\" $hight $length && exit 0 " ${quit_signal}
		draw_shape 1
		sleep 1  
		draw_shape 0
		interrupt $sig
		step_down
	done
}

function event_button(){
	local key 
	local pid=$!
	trap 'quitsig=q' 2
	trap 'quitsig=q' ${quit_signal}
	local akey=(0 0 0)
	local cESC=$(echo -ne "\033")
	while true :
	do
		read -s -n 1 -t 5 key
		akey[0]=${akey[1]}
		akey[1]=${akey[2]}
		akey[2]=$key
		if [[ ${key} == ${cESC} && ${akey[1]} == ${cESC} ]]
		then
			echo "ESC键"
		elif [[ ${akey[0]} == ${cESC} && ${akey[1]} == "[" ]]
		then
			if [[ ${key} == "A" ]];then 
				#echo "上键"
				kill -${arrate_signal} $pid
			elif [[ ${key} == "B" ]];then 
				#echo "向下"
				kill -${down_signal} $pid
			elif [[ ${key} == "D" ]];then 
				#echo "向左"
				kill -${left_signal} $pid
			elif [[ ${key} == "C" ]];then 
				#echo "向右"
				kill -${right_signal} $pid
			fi
		else
			if [[ ${key} == "W" || ${key} == "w" ]];then 
				#echo "上键"
				kill -${arrate_signal} $pid
			elif [[ ${key} == "S" || ${key} == "s" ]];then 
				#echo "向下"
				kill -${down_signal} $pid
			elif [[ ${key} == "A" || ${key} == "a" ]];then 
				#echo "向左"
				kill -${left_signal} $pid
			elif [[ ${key} == "D" || ${key} == "d" ]];then 
				#echo "向右"
				kill -${right_signal} $pid
			fi
		fi
		if [[ -n $quitsig ]];then
			echo -e "\n"
			kill -${quit_signal} $pid
			printf "\033[%d;%dH" $hight $length
			echo -e "\033[${hight};${length}Hgame over\033[0m\n"
			exit 1
		fi
	done
}

#-------------------------------------------------------------------------------------
ppid=$$
init_depth_map
create_new_shape
draw_picture &
event_button
