#!/bin/bash

################ Shift auto publisher ################
#
#	Actions:
#	1. add (+ pin)
#	2. publish (if needed)
#	3. Request at random peers (to create cache)
#	4. Generate and broadcast a pin transaction
#
#	To do:
#	- Collective pin (Wait till Phoenix has a queue?)
#
######################################################

init=false
ipfs_key="single"
url="http://startpage.freebrowser.org/zh/single.html"
parent=null
unpin=false

#generate a key at the first run
if [ $init != "false" ] ; then
	echo "Generating key ${ipfs_key}…"
	ipns_hash=`ipfs key gen --type=rsa $ipfs_key`
	echo $(date -u) " generated key ${ipns_hash}" | sudo tee -a publish.log
else
	output=`ipfs key list -l $ipfs_key`
	array=(`echo $output | cut -d " " -f 1-`)
	ipns_hash=${array[0]}
fi

echo "Adding (+pin) ${url}…"
#output=`echo "hello world" | ipfs add`
output=`ipfs add $url --pin=true`
array=(`echo $output | cut -d " " -f 1-`)
ipfs_hash=${array[1]}
echo $(date -u) " added ${ipfs_hash}" | sudo tee -a publish.log

echo "Get content size…"
output=`ipfs object stat ${ipfs_hash}`
bytes=(`echo $output | cut -d " " -f 10-`)
echo "cumulative object size is ${bytes} bytes."

echo "Lookup current ipfs hash…"
output=`ipfs name resolve $ipns_hash`
if [ $ipfs_hash != ${output//\/ipfs\/""} ] ; then
	output=`ipfs name publish $ipfs_hash --key=$ipfs_key`
	array=(`echo $output | cut -d " " -f 1-`)
	ipns_hash=${array[2]}
	echo $(date -u) " published ${ipfs_hash} > ${ipns_hash}" | sudo tee -a publish.log
else
	echo "object with hash $ipfs_hash is already published. Exiting."
	exit
fi

echo "Generating and broadcasting pin transaction…"
response=`node pin.js $ipfs_hash $bytes $unpin $parent`
success=`echo $response | jq '.success'`
if [ $success == false ] ; then
	message=`echo $response | jq '.message'`
	echo "Error broadcasting: ${message}"
else
	senderid=`echo $response | jq '.senderid'`
	transactionId=`echo $response | jq '.transactionId'`

	echo $(date -u) " pin transaction ${transactionId} by sender ${senderid} is broadcasted " | sudo tee -a publish.log
fi

echo "Get peer list…"
ip_list=()
output=`ipfs swarm peers`
IFS='\t' peers=($output)
for peer in "${peers[@]}"; do
	ip="$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' <<< "$peer")"
	if [ $ip ] ; then
		ip_list+=($ip)
	fi
done
unset IFS

echo "Pick ${len} random peers…"
cnt=1
max=3
while [ $cnt -le $max ]
do
	sleep 1
	random=${ip_list[RANDOM % ${#ip_list[@]}]}
	url="http://${random}/ipfs/${ipfs_hash}"
	output=`curl -Is $url | head -n 1| cut -d $' ' -f2`
	if [ $output == 200 ] ; then
		echo "✓ Request at random peer ${random}"
	else
		echo "✘ Request at peer ${random} failed"
	fi

	(cnt++)
done

echo "Done"

#https://storage-testnet.shiftproject.com/ipfs/QmRdopL2tRvFmcGuQfKnAgxHTxsDMHaZWQ2rHtL54ojjfp
#https://storage-testnet.shiftproject.com/ipns/QmYNKLdQHVpLSAytjcSXQAwYsJSzRS9J1UkhRxt31nVxzL
