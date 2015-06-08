#!/bin/bash
# Program:
#	This program could replace assigned chart in specific documen.
# History:
# 2015/05/04	ShellBird First release
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Prompt for usage if arguments count is not correct.
if [ $# -lt 2 ]; then
	echo 1>&2 "$0: not enough arguments"
	echo "Follow below format to run this script:"
	echo "./pxeload.sh <platform> <os>"
	exit 2
elif [ $# -gt 2 ]; then
	echo 1>&2 "$0: too many arguments"
	echo "Follow below format to run this script:"
	echo "./pxeload.sh <platform> <os>"
fi
# The three arguments are available as "$1", "$2"

declare -a platforms ospool maclst;

echo "Set platform $1 to load $2 through PXE!";
pltfrm=$1
defos=$2;
hfile="/etc/dhcp/dhcpd.conf" ;
seed=`date +%s%N`;

# Pre-set platform information
# Plan to get these information from database controlled by CRANE Web.
platforms=( \
	'ep1' 'ep2' 'ep3' 'ep4' \
	'ob1b' 'ob1a' 'ob2b' 'ob2a' 'ob3b' 'ob3a' 'ob4b' 'ob4a' \
	'hy1b' 'hy1a' 'hy2b' 'hy2a' 'hy3b' 'hy3a' 'hy4b' 'hy4a' \
	'ln1b' 'ln1a' 'ln2b' 'ln2a' \
) ;

# Format as 
# ep1 ep2
# ep3 ep4
# ob1b ob1a
# ob2b ob2a
# ob3b ob3a
# ob4b ob4a
# hy1b hy1a
# hy2b hy2a
# hy3b hy3a
# hy4b hy4a
# ln1b ln1a
# ln2b ln2a


maclst=( \
	'00:60:16:74:C3:18' '00:60:16:6f:b9:b6' \
	'00:60:16:6F:B8:6A' '00:60:16:74:C2:2C' \
	'00:60:16:6F:9F:14' '00:60:16:6F:9F:12' \
	'00:99:99:99:99:2a' '00:99:99:99:99:2b' \
	'00:60:16:6F:B2:2E' '00:60:16:6F:AC:9E' \
	'00:60:16:6F:B2:66' '00:60:16:6F:AC:9E' \
	'00:60:16:6f:a1:be' '00:60:16:6f:a0:76' \
	'00:11:22:33:44:2b' '00:11:22:33:44:2a' \
	'00:11:22:33:44:3b' '00:11:22:33:44:3a' \
	'00:11:22:33:44:4b' '00:11:22:33:44:4a' \
	'00:11:22:33:44:1b' '00:11:22:33:44:1a' \
	'00:60:16:76:50:b4' '00:60:16:76:50:70' \
) ;

comlst=( \
	'33' '15' '47' '49' \
	'25' '11' '23' '13' '57' '43' '55' '45' \
	'39' '29' '37' '31' '41' '17' '21' '27' \
	'61' '59' '65' '63' \
) ;
ospool=( 'atragon' 'ipxe' 'eos' 'unity' 'ubuntu') ;

# Get MAC address and COM port setting of selected platform
for ((i=0;i<=${#platforms[@]};++i)) ;
	do
		if [[ "$pltfrm" == ${platforms[i]} ]]; then
		defmac=${maclst[i]} ;
		defcom=${comlst[i]} ;
		fi;
	done;

function rmhost()
{
hostmac=$1 ;
con=`grep "$hostmac" $hfile | wc -l`  ;
if [ $con -gt 0 ]; then
	echo "Delete $pltfrm configure mapped to $hostmac in this file : $hfile" ;
	sudo sed -i -e :a -e "$!N;s/.*\n\(.*$hostmac\)/\1/;ta" -e 'P;D' $hfile ;
	sudo sed -i "/$hostmac/,/#hostend/d" $hfile ;
else
    echo "======== no change for file : "$hfile ;
fi ;
}

function addhost()
{
hostname=$1 ;
hostmac=$2 ;
hostos=$3 ;
hostip="192.168.1.1$4" ;
confpath="/home/tmp" ;
ipxeconf="ppipxe" ;
tftpconf="macbind" ;
apacheip='192.168.1.3' ;
router='192.168.1.1' ;
tftpatragon='192.168.1.3' ;
tftpeos='192.168.1.4' ;
tftpunity='192.168.1.6' ;
tftpubuntu='192.168.1.5' ;
platform='europa_pp';
ipxetmp="ipxetmp$seed" ;
tftptmp="tftptmp$seed" ;


sudo mkdir -p "$confpath" ;
if [[ "$hostos" == 'atragon' ]]; then
    echo "Loading Atragon by default, no need to chnage." ;
elif [[ "$hostos" == 'ipxe' ]]; then
	echo "$hostname"
	if [[ "$hostname" == ep* ]]; then platform="europa_pp" ;
	elif [[ "$hostname" == ob* ]]; then platform="oberon_pp" ;
	elif [[ "$hostname" == hy* ]]; then platform="hyperion_pp" ;
	elif [[ "$hostname" == ln* ]]; then platform="luna_pp" ;
	else 
		echo "Not supported platform $hostname";
		exit 1 ;
	fi;
	echo "Add configure for ipxe load" ;
    sudo cp "$ipxeconf" "$confpath/$ipxetmp" ;
    sudo sed -i s/hostname/$hostname/ "$confpath/$ipxetmp" ;
    sudo sed -i s/hostmac/$hostmac/ "$confpath/$ipxetmp" ;
    sudo sed -i s/hostip/$hostip/ "$confpath/$ipxetmp" ;
    sudo sed -i s/apacheip/$apacheip/ "$confpath/$ipxetmp" ;
    sudo sed -i s/platform/$platform/ "$confpath/$ipxetmp" ;
	cat $confpath/$ipxetmp | sudo tee -a $hfile ;
	echo "Configure for ipxe load updated." ;
	sudo rm -f "$confpath/$ipxetmp" ;
elif [[ "$hostos" == {'eos'||'unity'||'ubuntu'} ]]; then
# Add configure for OS load
    sudo cp "$tftpconf" "$confpath/$tftptmp" ;
    sudo sed -i s/hostname/$hostname/ "$confpath/$tftptmp" ;
    sudo sed -i s/hostmac/$hostmac/ "$confpath/$tftptmp" ;
    sudo sed -i s/hostip/$hostip/ "$confpath/$tftptmp" ;
    sudo sed -i s/op-route/$router/ "$confpath/$tftptmp" ;
    if [[ "$hostos" == 'eos' ]]; then
    	echo "Add configure for EoS load" ;
		sudo sed -i s/op-tftp/$tftpeos/ "$confpath/$tftptmp" ;
    elif [[ "$hostos" == 'unity' ]]; then
    	echo "Add configure for unity load" ;
		sudo sed -i s/op-tftp/$tftpunity/ "$confpath/$tftptmp" ;
    elif [[ "$hostos" == 'ubuntu' ]]; then
    	echo "Add configure for ubuntu installation" ;
		sudo sed -i s/op-tftp/$tftpubuntu/ "$confpath/$tftptmp" ;
    fi;
	cat $confpath/$tftptmp | sudo tee -a $hfile ;
	echo "Configure for OS load updated."
	sudo rm -f "$confpath/$tftptmp" ;
else
    echo "Not a valid option, exit" ;
    exit 1;
fi;
sudo rm -rf "$confpath" ;
}


function switch()
{
bakfile="/home/sysadmin/dhcpd.conf.bak" ;
	sudo cp $hfile $bakfile ;
	# remove host $pltfrm contains $defmac"
	rmhost $defmac ;
	
	# add host $pltfrm + $defos"
	addhost $pltfrm $defmac $defos $defcom ;	
	sudo service isc-dhcp-server restart || \
	{ echo 'dhcp restart fail'; sudo cp "$backfile" "$hfile"; exit 1; } ;
}

if [[ " ${platforms[@]} " =~ " $pltfrm " ]]; then
# Continue if this is a valid platform
	if [[ " ${ospool[@]} " =~ " $defos " ]]; then
		echo "Change configure file for loading $defos" ;
		switch ;
		echo "Switching completed." ;
	else
		echo "Not supported OS: $defos"	;
		for ((i=0;i<=${#ospool[@]};++i)) ;
		do
			echo ${ospool[i]} ;
		done
		exit 1 ;
	fi;
else 
	echo "Not supported platform: $pltfrm" ;
	echo "Only platform from list below are supported(match case)"
	for ((i=0;i<=${#platforms[@]};++i)) ;
		do
		echo ${platforms[i]} ;
		done
	exit 1 ;
fi;


exit 0 ;
