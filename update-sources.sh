#!/bin/bash
# Program:
#	This program will update source to cn.archive 
#	so as to speed up the download from China 
# History:
# 2015/05/07	First release
# Contact:	michael.shen@emc.com
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# update sources.list to cn for better download speed on util update
sudo cp /etc/apt/sources.list /home/sysadmin/sources.list.bak ;
echo "Replacing all sources to cn.archive..." ;
sleep 3
sudo sed -i "s/us.archive/cn.archive/" /etc/apt/sources.list ;
sudo sed -i "s/security.ubuntu/cn.archive.ubuntu/" /etc/apt/sources.list ;
echo "Run update to take effect..." ;
sleep 3
sudo apt-get update ;

exit 0
