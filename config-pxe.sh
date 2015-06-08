#!/bin/bash
# Program:
#	This program will configure PXE boot environment.
#	*install necessory utils
#	*prompt NIC to deploy PXE
#	*Load latest Atragon by default
#	*Load provided image from samba share if available
# History:
# 2015/05/06	First release
# Contact:	michael.shen@emc.com
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

echo 'Installing all necessory utilities for PXE...' ;
sudo apt-get install isc-dhcp-server tftpd-hpa -y ;
sudo apt-get install cifs-utils -y ;


# func that insert NIC info to /etc/default/isc-dhcp-server
function add_nic()
{
declare -a ary_isc ;
iconf=/etc/default/isc-dhcp-server
echo $1;
# grep all nic id within string format |^INTERFACES=""|
ary_isc=(`cat $iconf | grep -v '^#' | grep 'INTERFACES=\".*\"' | sed -n 's/INTERFACES=//;s/\"//gp;'| awk '{for (i=0;i<NF;i++) {print $(i+1);}}'`)
# check if request ip exist in conf of isc-dhcp-server
if [[ "${ary_isc[*]}" == *"${1:0:4}"* ]] ;
then
	echo "DHCP server serving DHCP requests on \"${1:0:4}\" already!";
else
	echo "Adding \"${1:0:4}\" to Interface list serving DHCP Request...";
	# if no nic exist, add w/o blank 
	# else, insert nic id w/ blank
	if [[ ${#ary_isc[@]} -eq 0 ]];
	then
		sudo sed -i "s/INTERFACES=\"/INTERFACES=\"${1:0:4}/g" $iconf;
	else
		sudo sed -i "s/INTERFACES=\"/INTERFACES=\"${1:0:4} /g" $iconf;
	fi;
	echo "Restarting isc-dhcp-server to take effect..."
	sudo service isc-dhcp-server restart
fi;
}

# func that add default pxe configure into /etc/dhcp/dhcpd.conf
function add_conf()
{
#declare -a ary_conf ;

boot_str1='allow bootp;' ;
boot_str2='allow booting;' ;
dconf=/etc/dhcp/dhcpd.conf ;
subnet='192.168.1.0';
netmask='255.255.255.0';
netstart='192.168.1.11';
netend='192.168.1.99';
broadcast='192.168.1.255';
router="${1:5:19}";
echo "$router" ;

con=`grep "$subnet" $dconf | wc -l`  ;
if [ $con -gt 0 ]; then
	echo "Configure for $subnet already exist" ;
	echo "No change for file : $dconf" ;
else
	sudo cp "$dconf" "/home/sysadmin/dhcpd.conf.cbak" ;
	grep -q "^$boot_str1" "$dconf" || echo "$boot_str1" | sudo tee -a "$dconf" ;
	grep -q "^$boot_str2" "$dconf" || echo "$boot_str2" | sudo tee -a "$dconf" ;

	echo -e "subnet $subnet netmask $netmask {\n\t#rg#;\n\t#rt#;\n\t#msk#;\n\t#bcast#;\n\t#file#;\n\t#dns#;\n}" | sudo tee -a "$dconf";
	sudo sed -i "s/#rg#/range $netstart $netend/" $dconf ;
	sudo sed -i "s/#rt#/option routers $router/" $dconf ;
	sudo sed -i "s/#msk#/option subnet-mask $netmask/" $dconf ;
	sudo sed -i "s/#bcast#/option broadcast-address $broadcast/" $dconf ;
	sudo sed -i "s/#file#/filename \"pxelinux.0\"/" $dconf ;
	sudo sed -i "s/#dns#/next-server $router/" $dconf ;
fi ;
}

# Acquire all available NICs with current IP assignment
declare -a array ;
array=(`ifconfig | sed -rn '/^[^ \t]/{N;s/(^[^ ]*).*addr:([^ ]*).*/\1:\2/p}' | awk -F':' '$2!~/^127|^0|^$/{print $0}'`)
echo "You have ${#array[@]} Network Interface Cards" ;
echo "Network Interface Card list:";
for var in ${array[@]};
    do
	echo "$var";
done;

# Ask for NICs that needed to deploy PXE
read -p "Configure the PXE now?(Yes/No):[No]" gyn;
if [[ $gyn =~ ^([yY][eE][sS]|[yY])$ ]]; 
then
	for var in ${array[@]};
    do
    	read -p "Deploy PXE on $var?(Yes/No):[No]" eyn;
		if [[ $eyn =~ ^([yY][eE][sS]|[yY])$ ]];
		then
			echo "config $var start!";
			# exit if add nic func failed
			(add_nic $var)||{ exit 1; };
			echo "Add NIC $var complete.";
			echo $var ;
			add_conf "$var";
			sudo service isc-dhcp-server restart ;
			echo "Add subnet info of $var into dhcpd.conf complete."
		fi;
	done;
else
	echo "Abort PXE configure Utility...";
	exit 0 ;
fi;

# Ask if user need to set Atragon as default tftp os
read -p "Configure Atragton as default PXE?(Yes/No):[No]" gyn;
if [[ $gyn =~ ^([yY][eE][sS]|[yY])$ ]]; 
then
	# create temp share and copy atragon to tftpboot
	if [ -d /mnt/atgshare ]; then
		sudo rm -rf atgshare ;
	fi ;
	sudo mkdir /mnt/atgshare ;
	while true 
	do
    read -p 'Please enter your NT account for access Atragon Release share:' uid
    echo "Your input NT account is: $uid"
    read -p 'Confirm if your input is correct(Yes/No):' ack
    if [[ $ack =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Conutinue to access Atragon Release with $uid"
            break
        elif [[ $ack = 'exit' ]]; then
            exit 0
        else
            continue
    fi ;
	done ;
	sudo mount -t cifs //corpusfs11.corp.emc.com/gps_fwqa_drop/atragon/0.0.9 -o username=$uid /mnt/atgshare ;
	echo 'Install Atragon to tftp root...' ;
	sudo cp -a /mnt/atgshare/. /var/lib/tftpboot/ ;
	sudo umount /mnt/atgshare ;
	sudo rm -rf /mnt/stghare ;
	sudo service isc-dhcp-server restart ;
	echo "Configure Atragon as default PXE success." ;
else
	echo "Not configure Atragon as default PXE." ;
	echo "PXE configure script completed." ;

fi;
exit 0;
