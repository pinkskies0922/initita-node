#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 配置参数功能
function set_info() {
    # 检查 ~/.bashrc 是否存在，如果不存在则创建
    if [ ! -f ~/.bashrc ]; then
        touch ~/.bashrc
    fi
    echo "接下来请确认是否成功查询出钱包地址和验证者地址，如果没有正确输出两个地址 请重新执行一遍配置参数功能获取地址"
    read -p "请输入创建节点时的密码: " new_pwd

    # 检查 ~/.bashrc 中是否已存在 0g_pwd，如果存在则替换为新密码，如果不存在则追加
    if grep -q '^0g_pwd=' ~/.bashrc; then
    sed -i "s|^0g_pwd=.*$|0g_pwd=$new_pwd|" ~/.bashrc
    else
    echo "0g_pwd=$new_pwd" >> ~/.bashrc
    fi

    # 输入钱包名
    read -p "请输入钱包名: " wallet_name

    # 检查 ~/.bashrc 中是否已存在 0g_wallet，如果存在则替换为新钱包名，如果不存在则追加
    if grep -q '^0g_wallet=' ~/.bashrc; then
    sed -i "s|^0g_wallet=.*$|0g_wallet=$wallet_name|" ~/.bashrc
    else
    echo "0g_wallet=$wallet_name" >> ~/.bashrc
    fi

    echo "正在查询钱包地址"
    # 检查 ~/.bashrc 中是否已存在 0g_address，如果存在则替换为新地址，如果不存在则追加
    if grep -q '^0g_address=' ~/.bashrc; then
        # 执行命令，并将输出赋值给变量shg_address
        shg_address=$(0gchaind keys show $wallet_name -a)
        sed -i "s|^0g_address=.*$|0g_address=$shg_address|" ~/.bashrc
        echo "钱包地址为: $shg_address"
    else
        echo "0g_address=$shg_address" >> ~/.bashrc
        echo "钱包地址为: $shg_address"
    fi

    # 输入验证者名字
    read -p "请输入验证者名字: " validator_name

    # 检查 ~/.bashrc 中是否已存在 0g_validator_name，如果存在则替换为新钱包名，如果不存在则追加
    if grep -q '^0g_validator_name=' ~/.bashrc; then
    sed -i "s|^0g_validator_name=.*$|0g_validator_name=$validator_name|" ~/.bashrc
    else
    echo "0g_validator_name=$validator_name" >> ~/.bashrc
    fi

    echo "正在查询验证者地址"
    # 检查 ~/.bashrc 中是否已存在 0g_validator
    if grep -q '^0g_validator=' ~/.bashrc; then
        shg_validator=$(0gchaind keys show $wallet_name --bech val -a)
        sed -i "s|^0g_validator=.*$|0g_validator=$shg_validator|" ~/.bashrc
        echo "验证者地址为: $shg_validator"
    else
        shg_validator=$(0gchaind keys show $wallet_name --bech val -a)
        echo "0g_validator=$shg_validator" >> ~/.bashrc
        echo "验证者地址为: $shg_validator"
    fi

  echo "参数已设置成功，并写入到 ~/.bashrc 文件中"

  read -p "按回车键返回主菜单"

  # 返回主菜单
  main_menu
}

# 查询钱包列表功能
function walletlist() {
    echo "正在查询中，请稍等"
    initiad keys list

    read -p "按回车键返回主菜单"

     # 返回主菜单
    main_menu
}
# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0
    else
        echo "Go 环境未安装，正在安装..."
        return 1
    fi
}

# 节点安装功能
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # 安装 Go
    if ! check_go_installation; then
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
    fi

    # 安装所有二进制文件
    git clone https://github.com/initia-labs/initia
    cd initia
    git checkout v0.2.14
    make install
    initiad version

    # 配置initiad
    initiad init "Moniker" --chain-id initiation-1
    initiad config set client chain-id initiation-1

    # 获取初始文件和地址簿
    wget -O $HOME/.initia/config/genesis.json https://initia.s3.ap-southeast-1.amazonaws.com/initiation-1/genesis.json
    wget -O $HOME/.initia/config/addrbook.json https://rpc-initia-testnet.trusted-point.com/addrbook.json
    sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.15uinit,0.01uusdc\"|" $HOME/.initia/config/app.toml

    # 配置节点
    PEERS="e634bbdc8a1fee53b9c2abc779c653c21adb7496@168.119.10.134:26995,d6875c002ff3dacacbb1c971169f1e2c1193119b@65.109.139.2:26656,bc64e8794465dd46399bf6f49a564098e09b0843@164.92.96.212:26656,058e9cc6d252a5070c13815e7cd5f30cf493c52f@5.161.227.226:26656,cdedfbed5139d32412858fa2aa2cee9566a91dd8@89.117.58.234:26656,aed2c793c683e555cff07bc44d084b1e4b76d42e@171.250.165.103:10256,68f0ada2c2c120371037a2e65fbf2f9337f68918@75.119.141.44:15656,2129f6296413e134d94c5a0b98905cc4108860f8@194.5.157.3:26656,da60b9e1d8f8618307de3ef0d9a61eac6bf7d634@45.144.29.157:26656,a1b7fbda148b4a437b63584018a2a88ebe45f25f@86.48.3.66:26656,703edda35d84e48b7b0d9158dee9826180b4d122@37.27.80.245:26656,7292af244f9c87937a01d8e5bcd090449d4404f0@62.171.176.118:11856,268da5b10276ea13c4d839fe387249428b407f3d@148.113.8.196:24056,3a6e62cd90f6575bbcbd508a177b66aa478bfc69@45.76.176.66:26656,095f952cde7cc7991a877837ed84a009bb3b098e@84.46.247.107:12656,ede11cab565486fb268a5b28a22da604b2e455d3@95.216.155.52:26656,a6b0dea0d790beb9c9127323fc191beed2c6ccaa@185.137.122.227:11856,c7c80f0f5b6dfe4837abd6a7eab4c8342e5c2a95@65.109.115.56:11856,c363b364f61ff8d4a2e063e0223bdfcb8c4d0831@213.199.48.49:27656,b9e22f6799c5867879a4ff5d9f290722085ad199@84.247.189.90:26656,f5d973568fec14272c8b3ced0cb74277ff5866fa@62.171.131.124:26656,81437ded1cfe775274ec44dc7a822a7be5dc406f@118.71.116.24:26656,6cec2868ca6b7fa0991267cc91789bfc32a7ca7a@65.109.93.124:26856,70f7dc74d3b6afa12b988d61707229e8e191d9a2@213.246.45.16:55656,3a3a0bdec8de5993ddb3a7c3e7185d06c62d8a99@62.171.166.114:26656,7717ea3ed671e0da76ba35a05a9c7c24c8176f83@89.58.36.209:2656,cf56d4b46349a9bc0bd88eb3b67590a124a3d092@139.180.130.182:26656,9878d322ad5f18696a92a620b3451426134f46e6@62.169.25.68:11856,cd023377468374e7482dd762db2977c6db44e10f@84.247.166.63:26656,d1d43cc7c7aef715957289fd96a114ecaa7ba756@65.21.198.100:24010,e01e82e12beeb44b7ff3e98b1e62f9b976356e84@206.221.176.90:29656,ade303649081d98ab8ab0287530afee607d5b95b@104.248.195.112:26656,3c3c586ea54307a6b8dca556c1a1eda5d8fe04f6@136.243.104.103:24056,182b7f7ec60961b365808aece3837b6f1786a2b3@95.217.13.48:26656,4faecd8b45561ed0bbab9e5362045b4e7edaaa11@128.140.89.194:11856,0b7dbbbf7ae007daafe3c49c142fce5dcc9a1c55@94.72.125.122:26656,de7f52f477fd8953db29f0f8aae09f717ed590fb@94.72.101.240:26656,9b81767b5d1bec4a50fbe24984c1958ac6b2a4cb@158.220.108.166:12656,54380248083ddcb8b0907cc6607a10bacce2c32f@118.71.116.24:26656,7517e2df33c5356aad057e6c3033cdb2e3e4b544@94.72.108.222:26656,93165d63303c5632b060a8dcfc8a440fd001c0c8@68.183.183.234:26656,553929612a342dcc988d98ad2934f52cc47a51e4@58.187.137.210:32656,e94719f60d03fd1864551ad07746284083dd1bb9@161.97.131.194:26656,0c9fa03479edf7093241305be1f6b5a361039c28@45.85.147.82:11856,153f0d20405f7343b7b0c93cbed8c3957379416f@57.128.63.126:26656,b922ce9a6945df4198211eabd8b047dacc5de81e@65.108.238.215:29056,eab329a812987efda7b6b015b06554390194634f@109.205.178.231:27656,a848ebed4c4a2e235e838640abd849d58eafd2e3@75.119.154.225:11856,666ed0538062095efe09c9447c4fc700d275ff95@65.21.105.12:11856,289626099b5ee210bbb5b4141697c98f726b2293@207.180.196.56:26656,fd944910711f27415fd308ec8d19ec624a5fa4a0@159.69.112.49:26656,2c6ae886df41b08b6361de953ad44c6f574afb05@51.178.92.69:12656,b5d5226ac957b8b384644e0aa2736be4b40f806c@46.38.232.86:14656,84868ec9449ca2a9942b3af1b2ff01bed071a45b@95.216.136.240:26656,f5bd4b6fdbcc0d9fbf83b067e362123dd8cf1dcd@152.42.191.106:26556,d7a743ecacaadf9be29d3da733d5c90cff7cf3f5@154.12.227.137:26656,1967e0c2e99401c49fbed2c7f1aa224a675e09a2@142.132.156.99:31056,2850a114bcaf0d388bf5b62165fe945e57fd44a5@167.86.80.169:26656,40d3f977d97d3c02bd5835070cc139f289e774da@168.119.10.134:26313,841c6a4b2a3d5d59bb116cc549565c8a16b7fae1@23.88.49.233:26656,e6a35b95ec73e511ef352085cb300e257536e075@37.252.186.213:26656,2a574706e4a1eba0e5e46733c232849778faf93b@84.247.137.184:53456,ff9dbc6bb53227ef94dc75ab1ddcaeb2404e1b0b@178.170.47.171:26656,edcc2c7098c42ee348e50ac2242ff897f51405e9@65.109.34.205:36656,07632ab562028c3394ee8e78823069bfc8de7b4c@37.27.52.25:19656,028999a1696b45863ff84df12ebf2aebc5d40c2d@37.27.48.77:26656,140c332230ac19f118e5882deaf00906a1dba467@185.219.142.119:53456,1f6633bc18eb06b6c0cab97d72c585a6d7a207bc@65.109.59.22:25756,065f64fab28cb0d06a7841887d5b469ec58a0116@84.247.137.200:53456,767fdcfdb0998209834b929c59a2b57d474cc496@207.148.114.112:26656,093e1b89a498b6a8760ad2188fbda30a05e4f300@35.240.207.217:26656,12526b1e95e7ef07a3eb874465662885a586e095@95.216.78.111:26656"
    sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.initia/config/config.toml

        # 配置端口
        node_address="tcp://localhost:53457"
        sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:53458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:53457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:53460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:53456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":53466\"%" $HOME/.initia/config/config.toml
        sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:53417\"%; s%^address = \":8080\"%address = \":53480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:53490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:53491\"%; s%:8545%:53445%; s%:8546%:53446%; s%:6065%:53465%" $HOME/.initia/config/app.toml
        echo "export initiad_RPC_PORT=$node_address" >> $HOME/.bash_profile
        source $HOME/.bash_profile

    # 配置预言机
    git clone https://github.com/skip-mev/slinky.git
    cd slinky

    # checkout proper version
    git checkout v0.4.3

    make build

    # 配置预言机启用
    sed -i -e 's/^enabled = "false"/enabled = "true"/' \
       -e 's/^oracle_address = ""/oracle_address = "127.0.0.1:8080"/' \
       -e 's/^client_timeout = "2s"/client_timeout = "500ms"/' \
       -e 's/^metrics_enabled = "false"/metrics_enabled = "false"/' $HOME/.initia/config/app.toml

    pm2 start initiad -- start && pm2 save && pm2 startup

    pm2 stop initiad

    # 配置快照
    sudo apt install lz4 -y
    wget -O initia_150902.tar.lz4 https://snapshots.polkachu.com/testnet-snapshots/initia/initia_150902.tar.lz4 --inet4-only
    initiad tendermint unsafe-reset-all --home $HOME/.initia --keep-addr-book
    lz4 -c -d initia_150902.tar.lz4  | tar -x -C $HOME/.initia
    
    pm2 start ./build/slinky -- --oracle-config-path ./config/core/oracle.json --market-map-endpoint 0.0.0.0:53490
    pm2 restart initiad

    source $HOME/.bash_profile
    echo '====================== 安装完成 ==========================='

}

# 查看initia 服务状态
function check_service_status() {
    pm2 list
}

# initia 节点日志查询
function view_logs() {
    pm2 logs initiad
}

function restart() {
    pm2 restart initiad
}

# 卸载节点功能
function uninstall_node() {
            echo "开始卸载Initia节点..."
            pm2 stop initiad && pm2 delete initiad
            rm -rf $HOME/.initiad && rm -rf $HOME/initia $(which initiad) && rm -rf $HOME/.initia
            echo "Initia节点卸载完成"
}

# 创建钱包
function add_wallet() {
    initiad keys add wallet
}

# 导入钱包
function import_wallet() {
    initiad keys add wallet --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    initiad query bank balances "$wallet_address" --node $initiad_RPC_PORT
}

# 查看节点同步状态
function check_sync_status() {
    initiad status --node $initiad_RPC_PORT | jq .sync_info
}

# 创建验证者
function add_validator() {
    read -p "请输入您的钱包名称: " wallet_name
    read -p "请输入您想设置的验证者的名字: " validator_name


    initiad tx mstaking create-validator   --amount=1000000uinit   --pubkey=$(initiad tendermint show-validator)   --moniker=$validator_name   --chain-id=initiation-1   --commission-rate=0.05   --commission-max-rate=0.10   --commission-max-change-rate=0.01   --from=$wallet_name   --identity=""   --website=""   --details=""   --gas=2000000 --fees=300000uinit --node $initiad_RPC_PORT -y

}

# 给自己地址验证者质押
function delegate2() {
    read -p "请输入质押代币数量,比如你有1个init,请输入1000000(6个0)，以此类推: " math
    read -p "请输入钱包名称: " wallet_name
    initiad tx mstaking delegate $(initiad keys show wallet --bech val -a) ${math}uinit --from $wallet_name --chain-id initiation-1 --gas=2000000 --fees=300000uinit --node $initiad_RPC_PORT -y
}

function unjail() {
    read -p "请输入钱包名称: " wallet_name
    initiad tx slashing unjail --from $wallet_name --fees=10000amf --chain-id=initiation-1 --node $initiad_RPC_PORT
}

# 导出验证者key
function export_priv_validator_key() {
    echo "====================请将下方所有内容备份到自己的记事本或者excel表格中记录==========================================="
    cat ~/.initia/config/priv_validator_key.json

}


# 主菜单
function main_menu() {
    while true; do
        clear
        echo "========================自用脚本 盗者必究========================="
        echo "需要测试网节点部署托管 技术指导 部署领水质押脚本 请联系Telegram :https://t.me/linzeusasa"
        echo "需要测试网节点部署托管 技术指导 部署领水质押脚本 请联系Wechat :llkkxx001"
        echo "===================Initia最新测试网节点一键部署===================="
        echo "创建验证者后请前往 https://forms.gle/LtxqGcJPNYXwwkxP9 填写表单"
        echo "每日网页交互任务请前往 https://app.testnet.initia.xyz/xp "
        echo "请选择要执行的功能:"
        echo "1. 安装节点"
        echo "2. 钱包管理"
        echo "3. 查询信息"
        echo "4. 创建验证者(请确保同步状态为false并且钱包有1init再执行)"
        echo "5. 重启节点"
        echo "6. 卸载节点"
        echo "7. 自动质押(暂未启用)"
        echo "8. 手动质押"
        echo "9. 解除jail"
        echo "10. 备份验证者私钥"
        read -p "请输入选项（1-10）: " OPTION

        case $OPTION in
        1) install_node ;;
        2)
            echo "=========================钱包管理菜单============================"
            echo "请选择要执行的操作:"
            echo "1. 创建钱包"
            echo "2. 导入钱包"
            echo "3. 钱包列表"
            read -p "请输入选项（1-2）: " WALLET_OPTION
            case $WALLET_OPTION in
            1) add_wallet ;;
            2) import_wallet ;;
            3) walletlist ;;
            *) echo "无效选项。" ;;
            esac
            ;;
        3)
            echo "=========================查询信息菜单============================"
            echo "请选择要执行的操作:"
            echo "1. 查看钱包地址余额(请先前往https://faucet.testnet.initia.xyz/领水)"
            echo "2. 查看节点同步状态"
            echo "3. 查看节点运行状态"
            echo "4. 查看节点运行日志"
            read -p "请输入选项（1-4）: " INFO_OPTION
            case $INFO_OPTION in
            1) check_balances ;;
            2) check_sync_status ;;
            3) check_service_status ;;
            4) view_logs ;;
            *) echo "无效选项。" ;;
            esac
            ;;
        4) add_validator ;;
        5) restart ;;
        6) uninstall_node ;;
        7) Delegate ;;
        8) delegate2 ;;
        9) unjail ;;
        10) export_priv_validator_key ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done

}

# 显示主菜单
main_menu
