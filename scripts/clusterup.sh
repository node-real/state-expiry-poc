#!/usr/bin/env bash
basedir=$(cd `dirname $0`; pwd)
workspace=${basedir}/..

# global var
validatorAddr=()
validatorSecretLoc=()

bnbHolderAddr=''

function exit_previous() {
	# stop client
	echo "kill all nodes!"
	ps -ef  | grep ${workspace}/bin/geth | awk '{print $2}' | xargs kill
	ps -ef  | grep ${workspace}/bin/bootnode | awk '{print $2}' | xargs kill
  sleep 30
}

function generate_static_peers() {
    tool=${workspace}/bin/bootnode
    num=$1
    target=$2
    staticPeers=""
    for ((i=1;i<=$num;i++)); do
        if [ $i -eq $target ]
        then
           continue
        fi

        file=${workspace}/scripts/asset/nodekey${i}
        if [ ! -f "$file" ]; then
            $tool -genkey $file
        fi
        port=$((30331 + i))
        if [ ! -z "$staticPeers" ]
        then
            staticPeers+="\\,"
        fi
        staticPeers+="\"enode\\:\\/\\/$($tool -nodekey $file -writeaddress)\\@127\\.0\\.0\\.1\\:$port\""
    done

    echo $staticPeers
}

function generate_nodekey() {
    tool=${workspace}/bin/bootnode
    num=$1
    for ((i=1;i<=$num;i++)); do
        file=${workspace}/scripts/asset/nodekey${i}
        if [ ! -f "$file" ]; then
            $tool -genkey $file
        fi
    done
}

function prepare() {
    if ! [[ -f ${workspace}/bin/geth ]];then
         echo "bin/geth do not exist!"
         exit 1
    fi
    if ! [[ -f ${workspace}/bin/bootnode ]];then
         echo "bin/bootnode do not exist!"
         exit 1
    fi
    rm -rf ${workspace}/clusterNode
    cd  ${workspace}/genesis
    git stash
    cd ${workspace}
    git submodule update --remote
    cd  ${workspace}/genesis
    npm install
}

function prepareGethEnv(){
    num=$1
    for((i=1;i<=$num;i++)); do
        rm -rf ${workspace}/clusterNode/node${i}
        mkdir -p ${workspace}/clusterNode/node${i}
        echo 'password' >> ${workspace}/clusterNode/password.txt
        ${workspace}/bin/geth --datadir ${workspace}/clusterNode/node${i} account new --password ${workspace}/clusterNode/password.txt > ${workspace}/clusterNode/validator${i}Info
        validatorAddr=("${validatorAddr[@]}" `cat ${workspace}/clusterNode/validator${i}Info|grep 'Public address of the key'|awk '{print $6}'` )
        validatorSecretLoc=("${validatorSecretLoc[@]}" `cat ${workspace}/clusterNode/validator${i}Info|grep  'Path of the secret key file'|awk '{print $7}'`)
    done
}

function loadGethEnv(){
    num=$1
    for((i=1;i<=$num;i++)); do
        validatorAddr=("${validatorAddr[@]}" `cat ${workspace}/clusterNode/validator${i}Info|grep 'Public address of the key'|awk '{print $6}'` )
        validatorSecretLoc=("${validatorSecretLoc[@]}" `cat ${workspace}/clusterNode/validator${i}Info|grep  'Path of the secret key file'|awk '{print $7}'`)
    done
}

function generateGenesis(){
    rm ${workspace}/genesis/validators.conf
    num=$1
    for i in "${validatorAddr[@]}"
    do
       echo "${i},${i},${i},0x0000000010000000" >> ${workspace}/genesis/validators.conf
    done

    cp ${workspace}/scripts/init_holders.template ${workspace}/genesis/init_holders.template
    sed "s/{{INIT_HOLDER_ADDR}}/${bnbHolderAddr}/g" ${workspace}/genesis/init_holders.template > ${workspace}/genesis/init_holders.js
    node generate-validator.js
    node generate-genesis.js

    for((i=1;i<=$num;i++)); do
      validatorIndex=$(($i-1))
      ${workspace}/bin/geth --datadir ${workspace}/clusterNode/node${i} init ${workspace}/genesis/genesis.json
      staticPeers=$(generate_static_peers $num $i)
      sed "s/{{StaticNodes}}/${staticPeers}/g" ${workspace}/scripts/asset/config-cluster.toml > ${workspace}/clusterNode/node${i}/config.toml
      sed -i.bak "s/{{etherbase}}/${validatorAddr[$validatorIndex]}/g" ${workspace}/clusterNode/node${i}/config.toml

      p2p_port=$((30331 + i))
      sed -i.bak "s/30311/${p2p_port}/g" ${workspace}/clusterNode/node${i}/config.toml

      HTTPPort=$((8501 + i))
      sed -i.bak "s/8501/${HTTPPort}/g" ${workspace}/clusterNode/node${i}/config.toml

      WSPort=$((8546 + i))
      sed -i.bak "s/8546/${WSPort}/g" ${workspace}/clusterNode/node${i}/config.toml

      GraphQLPort=$((8557 + i))
      sed -i.bak "s/8557/${GraphQLPort}/g" ${workspace}/clusterNode/node${i}/config.toml

      cp ${workspace}/scripts/asset/nodekey${i} ${workspace}/clusterNode/node${i}/geth/nodekey
    done
}

function startFullNodeWithExpiry() {
    num=$1
    nodeNum=$2
    remote=$3
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        nohup ${workspace}/bin/geth -unlock ${validatorAddr[$validatorIndex]} --http --http.port "$((8501+$nodeNum))" --ws.port "$((8545+$nodeNum))" \
         --config ${workspace}/clusterNode/node${nodeNum}/config.toml \
         --authrpc.port "$((8550+$nodeNum))" --password "${workspace}/clusterNode/password.txt" \
         --mine --miner.etherbase ${validatorAddr[$validatorIndex]} --rpc.allow-unprotected-txs --allow-insecure-unlock --light.serve 50 \
         --gcmode full --ws --datadir ${workspace}/clusterNode/node${nodeNum} \
         --metrics  --metrics.addr "0.0.0.0" --metrics.port "$((6060+$nodeNum))" --pprof --pprof.port "$((6070+$nodeNum))" --http.corsdomain "*" --rpc.txfeecap 0 \
         --state-expiry --state-expiry.remote ${remote} > ${workspace}/clusterNode/node${nodeNum}/geth-$(date +"%Y%m%d_%H%M").log 2>&1 &

        echo "start validator $nodeNum, enable state expiry, miner: ${validatorAddr[$validatorIndex]}"
        nodeNum=$(($nodeNum+1))

        sleep 1
    done
}

function startFullNodeNoExpiry() {
    num=$1
    nodeNum=$2
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        nohup ${workspace}/bin/geth -unlock ${validatorAddr[$validatorIndex]} --http --http.port "$((8501+$nodeNum))" --ws.port "$((8545+$nodeNum))" \
         --config ${workspace}/clusterNode/node${nodeNum}/config.toml \
         --authrpc.port "$((8550+$nodeNum))" --password "${workspace}/clusterNode/password.txt" \
         --mine --miner.etherbase ${validatorAddr[$validatorIndex]} --rpc.allow-unprotected-txs --allow-insecure-unlock --light.serve 50 \
         --gcmode full --ws --datadir ${workspace}/clusterNode/node${nodeNum} --rpc.txfeecap 0 \
         --metrics  --metrics.addr "0.0.0.0" --metrics.port "$((6060+$nodeNum))" --pprof --pprof.port "$((6070+$nodeNum))" --http.corsdomain "*" > ${workspace}/clusterNode/node${nodeNum}/geth-$(date +"%Y%m%d_%H%M").log 2>&1 &

        echo "start validator $nodeNum as full node, miner: ${validatorAddr[$validatorIndex]}"
        nodeNum=$(($nodeNum+1))
        sleep 1
    done
}

function pruneFullNodeNoExpiry() {
    num=$1
    nodeNum=$2
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        nohup ${workspace}/bin/geth snapshot prune-state --config ${workspace}/clusterNode/node${nodeNum}/config.toml \
         --datadir ${workspace}/clusterNode/node${nodeNum} > ${workspace}/clusterNode/node${nodeNum}/geth-prune-$(date +"%Y%m%d_%H%M").log 2>&1 &

        echo "start prune validator $nodeNum as full node"
        nodeNum=$(($nodeNum+1))
        sleep 1
    done
}

function pruneFullNodeWithExpiry() {
    num=$1
    nodeNum=$2
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        nohup ${workspace}/bin/geth snapshot prune-state --config ${workspace}/clusterNode/node${nodeNum}/config.toml \
         --datadir ${workspace}/clusterNode/node${nodeNum} \
         --state-expiry > ${workspace}/clusterNode/node${nodeNum}/geth-prune-$(date +"%Y%m%d_%H%M").log 2>&1 &

        echo "start prune validator $nodeNum as full node, enable state expiry feature"
        nodeNum=$(($nodeNum+1))

        sleep 1
    done
}

function storageProfile() {
    num=$1
    nodeNum=$2
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        echo "start profile validator $nodeNum"
        ${workspace}/bin/geth db inspect \
         --datadir ${workspace}/clusterNode/node${nodeNum} > ${workspace}/clusterNode/node${nodeNum}/geth-storage-inspect-$(date +"%Y%m%d_%H%M").log 2>&1
        ${workspace}/bin/geth db inspect-trie \
         --datadir ${workspace}/clusterNode/node${nodeNum} latest 1000 > ${workspace}/clusterNode/node${nodeNum}/geth-trie-inspect-$(date +"%Y%m%d_%H%M").log 2>&1

        nodeNum=$(($nodeNum+1))
        sleep 1
    done
}

CMD=$1

case ${CMD} in
start)
    exit_previous
    bnbHolderAddr="0xD8C0Aa483406A1891E5e03B21F2bc01379fc3b20"
    if [ ! -z $2 ] && [ "$2" -gt "0" ]; then
      bnbHolderAddr=$2
    fi
    fullNumWithExpiry=2
    if [ ! -z $3 ] && [ "$3" -gt "0" ]; then
      fullNumWithExpiry=$3
    fi
    fullNumNoExpiry=1
    if [ ! -z $4 ] && [ "$4" -gt "0" ]; then
      fullNumNoExpiry=$4
    fi
    validatorNum=fullNumWithExpiry+fullNumNoExpiry
    echo "===== generate node key ===="
    generate_nodekey $validatorNum
    echo "===== preparing ===="
    prepare $validatorNum
    prepareGethEnv $validatorNum
    generateGenesis $validatorNum
    echo "===== starting client ===="
    startFullNodeNoExpiry fullNumNoExpiry 1 # By default, last node is remoteDB
    remote="http://127.0.0.1:$((8501+1))"
    startFullNodeWithExpiry fullNumWithExpiry $((fullNumNoExpiry+1)) $remote
    echo "Finish deploy"
    ;;
restart)
    exit_previous
    fullNumWithExpiry=2
    if [ ! -z $3 ] && [ "$3" -gt "0" ]; then
      fullNumWithExpiry=$3
    fi
    fullNumNoExpiry=1
    if [ ! -z $4 ] && [ "$4" -gt "0" ]; then
      fullNumNoExpiry=$4
    fi
    validatorNum=fullNumWithExpiry+fullNumNoExpiry
    echo "===== preparing ===="
    loadGethEnv $validatorNum
    echo "===== restarting client ===="
    startFullNodeNoExpiry fullNumNoExpiry 1 # By default, last node is remoteDB
    remote="http://127.0.0.1:$((8501+1))"
    startFullNodeWithExpiry fullNumWithExpiry $((fullNumNoExpiry+1)) $remote
    echo "Finish restart"
    ;;
prune)
    exit_previous
    fullNumWithExpiry=2
    if [ ! -z $3 ] && [ "$3" -gt "0" ]; then
      fullNumWithExpiry=$3
    fi
    fullNumNoExpiry=1
    if [ ! -z $4 ] && [ "$4" -gt "0" ]; then
      fullNumNoExpiry=$4
    fi
    validatorNum=fullNumWithExpiry+fullNumNoExpiry
    echo "===== preparing ===="
    loadGethEnv $validatorNum
    echo "===== restarting client ===="
    pruneFullNodeNoExpiry fullNumNoExpiry 1
    pruneFullNodeWithExpiry fullNumWithExpiry $((fullNumNoExpiry+1))
    echo "Finish prune"
    ;;
storage)
    exit_previous
    fullNumWithExpiry=2
    if [ ! -z $3 ] && [ "$3" -gt "0" ]; then
      fullNumWithExpiry=$3
    fi
    fullNumNoExpiry=1
    if [ ! -z $4 ] && [ "$4" -gt "0" ]; then
      fullNumNoExpiry=$4
    fi
    validatorNum=fullNumWithExpiry+fullNumNoExpiry
    echo "===== preparing ===="
    loadGethEnv $validatorNum
    echo "===== restarting client ===="
    storageProfile validatorNum 1
    echo "Finish storage profile"
    ;;
stop)
    echo "===== stopping client ===="
    exit_previous
    echo "===== client stopped ===="
    ;;
*)
    echo "Usage: clusterup.sh start | stop"
    ;;
esac