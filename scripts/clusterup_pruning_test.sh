#!/usr/bin/env bash
basedir=$(cd `dirname $0`; pwd)
workspace=${basedir}/..

# global var
validatorAddr=()
validatorSecretLoc=()

bnbHolderAddr=''

function exit_previous() {
	# stop client
	ps -ef  | grep geth | grep  bsc-deploy| awk '{print $2}' | xargs kill
	ps -ef  | grep bootnode | grep  bsc-deploy| awk '{print $2}' | xargs kill
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

function generateGenesis(){
    rm ${workspace}/genesis/validators.conf
    num=$1
    for i in "${validatorAddr[@]}"
    do
       echo "${i},${i},${i},0x0000000010000000" >> ${workspace}/genesis/validators.conf
    done

    cp ${workspace}/scripts/init_holders.template ${workspace}/genesis/init_holders.template
    sed "s/{{INIT_HOLDER_ADDR}}/${validatorAddr[0]}/g" ${workspace}/genesis/init_holders.template > ${workspace}/genesis/init_holders.js
    node generate-validator.js
    node generate-genesis.js

    for((i=1;i<=$num;i++)); do
      ${workspace}/bin/geth --datadir ${workspace}/clusterNode/node${i} init ${workspace}/genesis/genesis.json
      staticPeers=$(generate_static_peers $num $i)
      sed "s/{{StaticNodes}}/${staticPeers}/g" ${workspace}/scripts/asset/config-cluster.toml > ${workspace}/clusterNode/node${i}/config.toml

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

function startArchiveNode() {
    num=$1
    nodeNum=$2
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        nohup ${workspace}/bin/geth -unlock ${validatorAddr[$validatorIndex]} --password "${workspace}/clusterNode/password.txt" --mine \
         --rpc.allow-unprotected-txs --light.serve 50 \
         --gcmode archive --ws --datadir ${workspace}/clusterNode/node${nodeNum} --config ${workspace}/clusterNode/node${nodeNum}/config.toml \
         --metrics --pprof --pprof.port "$((6060+$nodeNum))" --http.corsdomain "https://remix.ethereum.org" > ${workspace}/clusterNode/node${nodeNum}/bsc-node.log 2>&1 &
        
        echo "start validator $nodeNum as archive node"
        nodeNum=$(($nodeNum+1))
    done
}

function startFullNode() {
    num=$1
    nodeNum=$2
    for((i=1;i<=$num;i++)); do
        validatorIndex=$(($nodeNum-1))
        nohup ${workspace}/bin/geth -unlock ${validatorAddr[$validatorIndex]} --password "${workspace}/clusterNode/password.txt" --mine \
         --rpc.allow-unprotected-txs --light.serve 50 \
         --gcmode full --ws --datadir ${workspace}/clusterNode/node${nodeNum} --config ${workspace}/clusterNode/node${nodeNum}/config.toml \
         --metrics --pprof --pprof.port "$((6060+$nodeNum))" --http.corsdomain "https://remix.ethereum.org" > ${workspace}/clusterNode/node${nodeNum}/bsc-node.log 2>&1 &

        echo "start validator $nodeNum as full node"
        nodeNum=$(($nodeNum+1))
    done
}

CMD=$1

case ${CMD} in
start)
    source ~/.bash_profile
    exit_previous
    fullNum=2
    if [ ! -z $3 ] && [ "$3" -gt "0" ]; then
      fullNum=$3
    fi
    archiveNum=1
    if [ ! -z $4 ] && [ "$4" -gt "0" ]; then
      archiveNum=$4
    fi
    validatorNum=archiveNum+fullNum
    echo "===== generate node key ===="
    generate_nodekey $validatorNum
    echo "===== preparing ===="
    bnbHolderAddr=$2
    prepare $validatorNum
    prepareGethEnv $validatorNum
    generateGenesis $validatorNum
    echo "===== starting client ===="
    startFullNode fullNum 1
    startArchiveNode archiveNum $((fullNum+1))
    echo "Finish deploy"
    ;;
stop)
    echo "===== stopping client ===="
    exit_previous
    echo "===== client stopped ===="
    ;;
*)
    echo "Usage: localup.sh start | stop | genreate \${number} "
    ;;
esac

