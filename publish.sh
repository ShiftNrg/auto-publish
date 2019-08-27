#!/bin/bash

################ Shift auto publisher ################ 
#
#	Actions:
#	1. add (+ pin)
#	2. publish
#
#	To do: 
#	- Hash compare before re-publish
#	- Collective pin (Phoenix): host+'/pin/add?senderId='+userService.address+'&hash='+hash
#	- Request at some random peers? (to create cache)
#
######################################################

init=false
ipfs_key="single"
url="http://startpage.freebrowser.org/zh/single.html"

#generate a key at the first run
if [ $init != "false" ] ; then
	echo "Generating key ${ipfs_key}…"
	ipns_hash=`ipfs key gen --type=rsa $ipfs_key`
	echo $(date -u) " generated key ${ipns_hash}" | sudo tee -a publish.log
fi

echo "Adding (+pin) ${url}…"
#output=`echo "hello world" | ipfs add`
output=`ipfs add $url --pin=true`
array=(`echo $output | cut -d " " -f 1-`)
ipfs_hash=${array[1]}
echo $(date -u) " added ${ipfs_hash}" | sudo tee -a publish.log

output=`ipfs name publish $ipfs_hash --key=$ipfs_key`
array=(`echo $output | cut -d " " -f 1-`)
ipns_hash=${array[2]}
echo $(date -u) " published ${ipfs_hash} > ${ipns_hash}" | sudo tee -a publish.log

#echo "✘ Error"
echo "✓ Done"

#https://storage-testnet.shiftproject.com/ipfs/QmRdopL2tRvFmcGuQfKnAgxHTxsDMHaZWQ2rHtL54ojjfp
#https://storage-testnet.shiftproject.com/ipns/QmdLhPya78it59pXWZz7fSuB4Qs6cV2Bs5djHshKfDBTKx
