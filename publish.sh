#!/bin/bash

################ Shift auto publisher ################
#
#	Actions:
#    1. Check status
#    2. Download
#    3. Encrypt (optionally)
#    4. Upload (+ pin)
#    5. Publish (if needed)
#    6. Generate and broadcast a pin transaction
#    7. Collectively pin at Phoenix
#    8. Unpin older pins
#    9. Request at random peers (create cache)
#
######################################################

init=false
#ipfs_key="single"
ipfs_key="crypto"
url="http://startpage.freebrowser.org/zh/single.html"
phoenix="http://localhost"
host="http://localhost:9405"
parent=18061445502039238485
unpin_min=10 # Skip latest pins
unpin_max=50 # Limit batch size
filename="source.tmp"
encrypt_pass="testing"

DIR="$( cd "$( dirname "$0" )" && pwd )"

#generate a key at the first run
if [ $init != "false" ] ; then
	echo "Generating key ${ipfs_key}…"
	ipns_hash=`~/bin/ipfs key gen --type=rsa $ipfs_key`
	echo $(date -u) " generated key ${ipns_hash}" | sudo tee -a $DIR/publish.log
	exit
else
	output=`~/bin/ipfs key list -l $ipfs_key`
	array=(`echo $output | cut -d " " -f 1-`)
	ipns_hash=${array[0]}
fi

echo "Get page status…"
status=`curl -s -o /dev/null -I -w "%{http_code}" $url`
if [ $status != 200 ] ; then
        echo $(date -u) " ${status} returned, exiting" | sudo tee -a publish.log
        exit
fi

echo "Get content from url…"
curl $url --output $filename

if [ $encrypt_pass != "false" ] ; then
	echo "Encrypting content…"
	response=`node $DIR/encryption.js $encrypt_pass $filename`
	filename="${filename}.encrypted"
fi

echo "Adding (+pin) ${url}…"
output=`~/bin/ipfs add $filename --pin=true`
array=(`echo $output | cut -d " " -f 1-`)
ipfs_hash=${array[1]}
echo $(date -u) " added ${ipfs_hash}" | sudo tee -a $DIR/publish.log

echo "Get content size…"
output=`~/bin/ipfs object stat ${ipfs_hash}`
bytes=(`echo $output | cut -d " " -f 10-`)
echo "cumulative object size is ${bytes} bytes."

echo "Lookup current ipfs hash…"
output=`~/bin/ipfs name resolve $ipns_hash`
if [ $ipfs_hash != ${output//\/ipfs\/""} ] ; then
	output=`ipfs name publish $ipfs_hash --key=$ipfs_key`
	array=(`echo $output | cut -d " " -f 1-`)
	ipns_hash=${array[2]}
	echo $(date -u) " published ${ipfs_hash} > ${ipns_hash}" | sudo tee -a $DIR/publish.log
else
	echo "object with hash $ipfs_hash is already published. Exiting."
	exit
fi

echo "Generating and broadcasting pin transaction…"
response=`node $DIR/pin.js $ipfs_hash $bytes false $parent`
success=`echo $response | jq '.success'`
if [ $success == false ] ; then
	message=`echo $response | jq '.message'`
	echo "Error broadcasting: ${message}"
else
	senderid=`echo $response | jq '.senderid'`
	transactionId=`echo $response | jq '.transactionId'`

	echo $(date -u) " pin transaction ${transactionId} by sender ${senderid} is broadcasted " | sudo tee -a $DIR/publish.log
fi

echo "Send pin request to Phoenix for collective pinning…"
endpoint="${phoenix}/pin/queue?senderId=${senderid}&hash=${ipfs_hash}"
response=`curl -X POST -s $endpoint`
queued=`echo $response | jq '.Success'`
if [[ $queued == true ]] ; then
	echo $(date -u) " Pin successfully queued at Phoenix " | sudo tee -a $DIR/publish.log
else
	echo $(date -u) " Pin failed to queue at Phoenix " | sudo tee -a $DIR/publish.log
fi

echo "Generating and broadcasting unpin transaction(s)…"
endpoint="${host}/api/pins/parent?id=${parent}"
response=`curl -X GET -s $endpoint`

_jq() {
	pin=$(echo ${tx} | base64 --decode)
	if grep -q ${1} <<< $pin; then
		echo ${pin} | jq -r ${1}
	fi
}

cnt=1
txs=$(echo "${response}" | jq -R 'fromjson? | .[] | select(.latest==10)')
all=$(echo "${txs}" | grep -o $parent | wc -l)

for tx in txs | jq -r '@base64'); do
	if [ $cnt -gt $unpin_max ] ; then
		break
	fi

	queue=$(($all - $cnt))
	if [ $queue -le $unpin_min ] ; then
		break
	fi

	# Get pin details
	pin_hash=$(_jq '.hash')
	pin_bytes=$(_jq '.bytes')
	pin_tx=$(_jq '.transactionId')

	if [[ $pin_hash != "" ]] ; then
		broadcast=`node pin.js $pin_hash $pin_bytes true $parent`
		success=`echo $broadcast | jq '.success'`
		if [[ $success != false ]] ; then
			echo $(date -u) " Transaction $(pin_tx) successfully unpinned " | sudo tee -a $DIR/publish.log
			senderid=`echo $broadcast | jq '.senderid'`

			endpoint="${host}/pin/rm?senderId=${senderid}&hash=${pin_hash}"
			response=`curl -X POST -s $endpoint`
			removed=`echo $response | jq '.Success'`

			if [ $removed == true ] ; then
				echo $(date -u) " Successfully unpinned at Phoenix " | sudo tee -a $DIR/publish.log
			else
				echo $(date -u) " Unpinning at Phoenix failed" | sudo tee -a $DIR/publish.log
			fi
		fi
		sleep 1
	fi
	((cnt++))
done

echo "Get peer list…"
ip_list=()
output=`~/bin/ipfs swarm peers`
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
	if [[ $output == 200 ]] ; then
		echo "✓ Request at random peer ${random}"
		((cnt++))
	else
		echo "✘ Request at peer ${random} failed"
	fi
done

echo "Done"
