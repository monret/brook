#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#   System Required: CentOS/Debian/Ubuntu
#   Description: Brook
#   Version: 1.0.1
#   Author: Toyo, yulewang(DDNS features), monret(CNAME, iptables)
#   Blog: https://doub.io/wlzy-jc37/
#=================================================

sh_ver="1.0.1"
filepath=$(cd "$(dirname "$0")"; pwd)
file_1=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
file="/usr/local/brook-pf"
brook_file="/usr/local/brook-pf/brook"
brook_conf="/usr/local/brook-pf/brook.conf"
brook_log="/usr/local/brook-pf/brook.log"
Crontab_file="/usr/bin/crontab"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_root(){
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
#检查系统
check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    bit=`uname -m`
}
Install_Tools(){
        echo "正在安装依赖...."
        if [[ ${release} == "centos" ]]; then
            yum install bind-utils -y  &> /dev/null
        else
            apt-get install dnsutils -y &> /dev/null
        fi
        echo "安装完成"
}
check_installed_status(){
    [[ ! -e ${brook_file} ]] && echo -e "${Error} Brook 没有安装，请检查 !" && exit 1
}
check_crontab_installed_status(){
    if [[ ! -e ${Crontab_file} ]]; then
        echo -e "${Error} Crontab 没有安装，开始安装..."
        if [[ ${release} == "centos" ]]; then
            yum install crond -y
        else
            apt-get install cron -y
        fi
        if [[ ! -e ${Crontab_file} ]]; then
            echo -e "${Error} Crontab 安装失败，请检查！" && exit 1
        else
            echo -e "${Info} Crontab 安装成功！"
        fi
    fi
}
check_pid(){
    PID=$(ps -ef| grep "brook relays"| grep -v grep| grep -v ".sh"| grep -v "init.d"| grep -v "service"| awk '{print $2}')
}
check_new_ver(){
    echo -e "请输入要下载安装的 Brook 版本号 ${Green_font_prefix}[ 格式是日期，例如: v20180909 ]${Font_color_suffix}
版本列表请去这里获取：${Green_font_prefix}[ https://github.com/txthinking/brook/releases ]${Font_color_suffix}"
    read -e -p "直接回车即自动获取:" brook_new_ver
    if [[ -z ${brook_new_ver} ]]; then
        brook_new_ver=$(wget -qO- https://api.github.com/repos/txthinking/brook/releases| grep "tag_name"| head -n 1| awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g')
        [[ -z ${brook_new_ver} ]] && echo -e "${Error} Brook 最新版本获取失败！" && exit 1
        echo -e "${Info} 检测到 Brook 最新版本为 [ ${brook_new_ver} ]"
    else
        echo -e "${Info} 开始下载 Brook [ ${brook_new_ver} ] 版本！"
    fi
}
check_domain_ip_change(){
    Modify_success="0"
    user_all=$(cat ${brook_conf}|sed '/^\s*$/d')
    user_num=$(echo -e "${user_all}"|wc -l)
    for((integer = 1; integer <= ${user_num}; integer++))
    do
        user_port=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $1}')
        user_ip_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $2}')
        user_port_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $3}')
        user_Enabled_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $4}')
        user_domain_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $5}')
        if [ ! -z "$user_domain_pf" ]; then
            ip=$(host -t a  $user_domain_pf|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"|head -1)
            if [ -n "$ip" ]; then
                echo -e "Check domain IP: $ip"
            else
                echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Could not resolve hostname [${user_domain_pf}] !" | tee -a ${brook_log}
                continue
            fi

            if [[ ${user_ip_pf} != ${ip} ]]; then
                echo -e "${user_domain_pf}的IP发生变化, ${user_ip_pf} ===> ${ip}"
                echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] ${user_domain_pf}的IP发生变化, ${user_ip_pf} ===> ${ip}" | tee -a ${brook_log}
                sed -i -e "s/${user_port} ${user_ip_pf} ${user_port_pf} ${user_Enabled_pf} ${user_domain_pf}/${user_port} ${ip} ${user_port_pf} ${user_Enabled_pf} ${user_domain_pf}/g" ${brook_conf}
                Modify_success="1"
            else
                echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] ${user_domain_pf} 的IP未发生变化: ${ip}" | tee -a ${brook_log}
            fi
        fi
    done
    if [[ ${Modify_success} = "1" ]]; then
        echo -e "有IP发生了变化，正在重启Brook"
        Restart_brook
    fi
}
Download_brook(){
    [[ ! -e ${file} ]] && mkdir ${file}
    cd ${file}
    if [[ ${bit} == "x86_64" ]]; then
        wget --no-check-certificate -N "https://github.com/txthinking/brook/releases/download/${brook_new_ver}/brook"
    else
        wget --no-check-certificate -N "https://github.com/txthinking/brook/releases/download/${brook_new_ver}/brook_linux_386"
        mv brook_linux_386 brook
    fi
    [[ ! -e "brook" ]] && echo -e "${Error} Brook 下载失败 !" && exit 1
    chmod +x brook
}
Service_brook(){
    if [[ ${release} = "centos" ]]; then
        if ! wget --no-check-certificate https://raw.githubusercontent.com/monret/brook/master/brook-pf_centos -O /etc/init.d/brook-pf; then
            echo -e "${Error} Brook服务 管理脚本下载失败 !" && exit 1
        fi
        chmod +x /etc/init.d/brook-pf
        chkconfig --add brook-pf
        chkconfig brook-pf on
    else
        if ! wget --no-check-certificate https://raw.githubusercontent.com/monret/brook/master/brook-pf_debian -O /etc/init.d/brook-pf; then
            echo -e "${Error} Brook服务 管理脚本下载失败 !" && exit 1
        fi
        chmod +x /etc/init.d/brook-pf
        update-rc.d -f brook-pf defaults
    fi
    echo -e "${Info} Brook服务 管理脚本下载完成 !"
}
Installation_dependency(){
    \cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}
Read_config(){
    [[ ! -e ${brook_conf} ]] && echo -e "${Error} Brook 配置文件不存在 !" && exit 1
    user_all=$(cat ${brook_conf})
    user_all_num=$(echo "${user_all}"|wc -l)
    [[ -z ${user_all} ]] && echo -e "${Error} Brook 配置文件中用户配置为空 !" && exit 1
}
Set_pf_Enabled(){
    echo -e "立即启用该端口转发，还是禁用？ [Y/n]"
    read -e -p "(默认: Y 启用):" pf_Enabled_un
    [[ -z ${pf_Enabled_un} ]] && pf_Enabled_un="y"
    if [[ ${pf_Enabled_un} == [Yy] ]]; then
        bk_Enabled="1"
    else
        bk_Enabled="0"
    fi
}
Set_port_Modify(){
    while true
        do
        echo -e "请选择并输入要修改的 Brook 端口转发本地监听端口 [1-65535]"
        read -e -p "(默认取消):" bk_port_Modify
        [[ -z "${bk_port_Modify}" ]] && echo "取消..." && exit 1
        echo $((${bk_port_Modify}+0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${bk_port_Modify} -ge 1 ]] && [[ ${bk_port_Modify} -le 65535 ]]; then
                check_port "${bk_port_Modify}"
                if [[ $? == 0 ]]; then
                    break
                else
                    echo -e "${Error} 该本地监听端口不存在 [${bk_port_Modify}] !"
                fi
            else
                echo "输入错误, 请输入正确的端口。"
            fi
        else
            echo "输入错误, 请输入正确的端口。"
        fi
    done
}
Set_port(){
    while true
        do
        echo -e "请输入 Brook 本地监听端口 [1-65535]（端口不能重复，避免冲突）"
        read -e -p "(默认取消):" bk_port
        [[ -z "${bk_port}" ]] && echo "已取消..." && exit 1
        echo $((${bk_port}+0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${bk_port} -ge 1 ]] && [[ ${bk_port} -le 65535 ]]; then
                echo && echo "========================"
                echo -e "   本地监听端口 : ${Red_background_prefix} ${bk_port} ${Font_color_suffix}"
                echo "========================" && echo
                break
            else
                echo "输入错误, 请输入正确的端口。"
            fi
        else
            echo "输入错误, 请输入正确的端口。"
        fi
        done
}
Set_IP_pf(){
    echo "请输入被转发的 IP :"
    read -e -p "(默认取消):" bk_ip_pf
    [[ -z "${bk_ip_pf}" ]] && echo "已取消..." && exit 1
    echo && echo "========================"
    echo -e "   被转发IP : ${Red_background_prefix} ${bk_ip_pf} ${Font_color_suffix}"
    echo "========================" && echo
}
Set_DOMAIN_pf(){
    echo "请输入被转发的 域名 :"
    read -e -p "(默认取消):" bk_domain_pf
    [[ -z "${bk_domain_pf}" ]] && echo "已取消..." && exit 1
    echo && echo "========================"
    echo -e "   被转发域名 : ${Red_background_prefix} ${bk_domain_pf} ${Font_color_suffix}"
    echo "========================" && echo
}
Set_port_pf(){
    while true
        do
        echo -e "请输入 Brook 被转发的端口 [1-65535]"
        read -e -p "(默认取消):" bk_port_pf
        [[ -z "${bk_port_pf}" ]] && echo "已取消..." && exit 1
        echo $((${bk_port_pf}+0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${bk_port_pf} -ge 1 ]] && [[ ${bk_port_pf} -le 65535 ]]; then
                echo && echo "========================"
                echo -e "   被转发端口 : ${Red_background_prefix} ${bk_port_pf} ${Font_color_suffix}"
                echo "========================" && echo
                break
            else
                echo "输入错误, 请输入正确的端口。"
            fi
        else
            echo "输入错误, 请输入正确的端口。"
        fi
        done
}
Set_brook(){
    check_installed_status
    echo && echo -e "你要做什么？
 ${Green_font_prefix}0.${Font_color_suffix}  添加 端口转发(域名)
 ${Green_font_prefix}1.${Font_color_suffix}  添加 端口转发
 ${Green_font_prefix}2.${Font_color_suffix}  删除 端口转发
 ${Green_font_prefix}3.${Font_color_suffix}  修改 端口转发
 ${Green_font_prefix}4.${Font_color_suffix}  启用/禁用 端口转发
 
 ${Tip} 本地监听端口不能重复，被转发的IP或端口可重复!" && echo
    read -e -p "(默认: 取消):" bk_modify
    [[ -z "${bk_modify}" ]] && echo "已取消..." && exit 1
    if [[ ${bk_modify} == "1" ]]; then
        Add_pf
    elif [[ ${bk_modify} == "2" ]]; then
        Del_pf
    elif [[ ${bk_modify} == "3" ]]; then
        Modify_pf
    elif [[ ${bk_modify} == "4" ]]; then
        Modify_Enabled_pf
    elif [[ ${bk_modify} == "0" ]]; then
        Add_pf_with_domin
    else
        echo -e "${Error} 请输入正确的数字(0-4)" && exit 1
    fi
}
check_port(){
    check_port_1=$1
    user_all=$(cat ${brook_conf}|sed '1d;/^\s*$/d')
    #[[ -z "${user_all}" ]] && echo -e "${Error} Brook 配置文件中用户配置为空 !" && exit 1
    check_port_statu=$(echo "${user_all}"|awk '{print $1}'|grep -w "${check_port_1}")
    if [[ ! -z "${check_port_statu}" ]]; then
        return 0
    else
        return 1
    fi
}
list_port(){
    port_Type=$1
    user_all=$(cat ${brook_conf}|sed '/^\s*$/d')
    if [[ -z "${user_all}" ]]; then
        if [[ "${port_Type}" == "ADD" ]]; then
            echo -e "${Info} 目前 Brook 配置文件中用户配置为空。"
        else
            echo -e "${Info} 目前 Brook 配置文件中用户配置为空。" && exit 1
        fi
    else
        user_num=$(echo -e "${user_all}"|wc -l)
        for((integer = 1; integer <= ${user_num}; integer++))
        do
            user_port=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $1}')
            user_ip_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $2}')
            user_port_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $3}')
            user_Enabled_pf=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $4}')
            if [[ ${user_Enabled_pf} == "0" ]]; then
                user_Enabled_pf_1="${Red_font_prefix}禁用${Font_color_suffix}"
            else
                user_Enabled_pf_1="${Green_font_prefix}启用${Font_color_suffix}"
            fi
            user_list_all=${user_list_all}"本地监听端口: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t 被转发IP: ${Green_font_prefix}"${user_ip_pf}"${Font_color_suffix}\t 被转发端口: ${Green_font_prefix}"${user_port_pf}"${Font_color_suffix}\t 状态: ${user_Enabled_pf_1}\n"
            user_IP=""
        done
        ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
        if [[ -z "${ip}" ]]; then
            ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
            if [[ -z "${ip}" ]]; then
                ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
                if [[ -z "${ip}" ]]; then
                    ip="VPS_IP"
                fi
            fi
        fi
        echo -e "当前端口转发总数: ${Green_background_prefix} "${user_num}" ${Font_color_suffix} 当前服务器IP: ${Green_background_prefix} "${ip}" ${Font_color_suffix}"
        echo -e "${user_list_all}"
        echo -e "========================\n"
    fi
}
Add_pf_with_domin(){
    while true
    do
        list_port "ADD"
        Set_port
        check_port "${bk_port}"
        [[ $? == 0 ]] && echo -e "${Error} 该本地监听端口已使用 [${bk_port}] !" && exit 1
        Set_DOMAIN_pf
        Set_port_pf
        Set_pf_Enabled
        Resolve_Hostname_To_IP
        echo "${bk_port} ${ip} ${bk_port_pf} ${bk_Enabled} ${bk_domain_pf}" >> ${brook_conf}
        Add_success=$(cat ${brook_conf}| grep ${bk_port})
        if [[ -z "${Add_success}" ]]; then
            echo -e "${Error} 端口转发 添加失败 ${Green_font_prefix}[端口: ${bk_port} 被转发域名和端口: ${ip}:${bk_port_pf}]${Font_color_suffix} "
            break
        else
            echo -e "${Info} 端口转发 添加成功 ${Green_font_prefix}[端口: ${bk_port} 被转发域名和端口: ${ip}:${bk_port_pf}]${Font_color_suffix}\n"
            read -e -p "是否继续 添加端口转发配置？[Y/n]:" addyn
            [[ -z ${addyn} ]] && addyn="y"
            if [[ ${addyn} == [Nn] ]]; then
                Restart_brook
                break
            else
                echo -e "${Info} 继续 添加端口转发配置..."
                user_list_all=""
            fi
        fi
    done
}
Add_pf(){
    while true
    do
        list_port "ADD"
        Set_port
        check_port "${bk_port}"
        [[ $? == 0 ]] && echo -e "${Error} 该本地监听端口已使用 [${bk_port}] !" && exit 1
        Set_IP_pf
        Set_port_pf
        Set_pf_Enabled
        echo "${bk_port} ${bk_ip_pf} ${bk_port_pf} ${bk_Enabled}" >> ${brook_conf}
        Add_success=$(cat ${brook_conf}| grep ${bk_port})
        if [[ -z "${Add_success}" ]]; then
            echo -e "${Error} 端口转发 添加失败 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix} "
            break
        else
            echo -e "${Info} 端口转发 添加成功 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix}\n"
            read -e -p "是否继续 添加端口转发配置？[Y/n]:" addyn
            [[ -z ${addyn} ]] && addyn="y"
            if [[ ${addyn} == [Nn] ]]; then
                Restart_brook
                break
            else
                echo -e "${Info} 继续 添加端口转发配置..."
                user_list_all=""
            fi
        fi
    done
}
Del_pf(){
    while true
    do
        list_port
        Set_port
        check_port "${bk_port}"
        [[ $? == 1 ]] && echo -e "${Error} 该本地监听端口不存在 [${bk_port}] !" && exit 1
        sed -i "/^${bk_port} /d" ${brook_conf}
        Del_success=$(cat ${brook_conf}| grep ${bk_port})
        if [[ ! -z "${Del_success}" ]]; then
            echo -e "${Error} 端口转发 删除失败 ${Green_font_prefix}[端口: ${bk_port}]${Font_color_suffix} "
            break
        else
            port=${bk_port}
            echo -e "${Info} 端口转发 删除成功 ${Green_font_prefix}[端口: ${bk_port}]${Font_color_suffix}\n"
            port_num=$(cat ${brook_conf}|sed '/^\s*$/d'|wc -l)
            if [[ ${port_num} == 0 ]]; then
                echo -e "${Error} 已无任何端口 !"
                check_pid
                if [[ ! -z ${PID} ]]; then
                    Stop_brook
                fi
                break
            else
                read -e -p "是否继续 删除端口转发配置？[Y/n]:" delyn
                [[ -z ${delyn} ]] && delyn="y"
                if [[ ${delyn} == [Nn] ]]; then
                    Restart_brook
                    break
                else
                    echo -e "${Info} 继续 删除端口转发配置..."
                    user_list_all=""
                fi
            fi
        fi
    done
}
Modify_pf(){
    list_port
    Set_port_Modify
    echo -e "\n${Info} 开始输入新端口... \n"
    Set_port
    check_port "${bk_port}"
    [[ $? == 0 ]] && echo -e "${Error} 该端口已存在 [${bk_port}] !" && exit 1
    Set_IP_pf
    Set_port_pf
    sed -i "/^${bk_port_Modify} /d" ${brook_conf}
    Set_pf_Enabled
    echo "${bk_port} ${bk_ip_pf} ${bk_port_pf} ${bk_Enabled}" >> ${brook_conf}
    Modify_success=$(cat ${brook_conf}| grep "${bk_port} ${bk_ip_pf} ${bk_port_pf} ${bk_Enabled}")
    if [[ -z "${Modify_success}" ]]; then
        echo -e "${Error} 端口转发 修改失败 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix}"
        exit 1
    else
        port=${bk_port_Modify}
        Restart_brook
        echo -e "${Info} 端口转发 修改成功 ${Green_font_prefix}[端口: ${bk_port} 被转发IP和端口: ${bk_ip_pf}:${bk_port_pf}]${Font_color_suffix}\n"
    fi
}
Modify_Enabled_pf(){
    list_port
    Set_port_Modify
    user_pf_text=$(cat ${brook_conf}|sed '/^\s*$/d'|grep "${bk_port_Modify}")
    user_port_text=$(echo ${user_pf_text}|awk '{print $1}')
    user_ip_pf_text=$(echo ${user_pf_text}|awk '{print $2}')
    user_port_pf_text=$(echo ${user_pf_text}|awk '{print $3}')
    user_Enabled_pf_text=$(echo ${user_pf_text}|awk '{print $4}')
    if [[ ${user_Enabled_pf_text} == "0" ]]; then
        echo -e "该端口转发已${Red_font_prefix}禁用${Font_color_suffix}，是否${Green_font_prefix}启用${Font_color_suffix}？ [Y/n]"
        read -e -p "(默认: Y 启用):" user_Enabled_pf_text_un
        [[ -z ${user_Enabled_pf_text_un} ]] && user_Enabled_pf_text_un="y"
        if [[ ${user_Enabled_pf_text_un} == [Yy] ]]; then
            user_Enabled_pf_text_1="1"
            sed -i "/^${bk_port_Modify} /d" ${brook_conf}
            echo "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}" >> ${brook_conf}
            Modify_Enabled_success=$(cat ${brook_conf}| grep "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}")
            if [[ -z "${Modify_Enabled_success}" ]]; then
                echo -e "${Error} 端口转发 启用失败 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}"
                exit 1
            else
                echo -e "${Info} 端口转发 启用成功 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}\n"
                Restart_brook
            fi
        else
            echo "已取消..." && exit 0
        fi
    else
        echo -e "该端口转发已${Green_font_prefix}启用${Font_color_suffix}，是否${Red_font_prefix}禁用${Font_color_suffix}？ [Y/n]"
        read -e -p "(默认: Y 禁用):" user_Enabled_pf_text_un
        [[ -z ${user_Enabled_pf_text_un} ]] && user_Enabled_pf_text_un="y"
        if [[ ${user_Enabled_pf_text_un} == [Yy] ]]; then
            user_Enabled_pf_text_1="0"
            sed -i "/^${bk_port_Modify} /d" ${brook_conf}
            echo "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}" >> ${brook_conf}
            Modify_Enabled_success=$(cat ${brook_conf}| grep "${user_port_text} ${user_ip_pf_text} ${user_port_pf_text} ${user_Enabled_pf_text_1}")
            if [[ -z "${Modify_Enabled_success}" ]]; then
                echo -e "${Error} 端口转发 禁用失败 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}"
                exit 1
            else
                echo -e "${Info} 端口转发 禁用成功 ${Green_font_prefix}[端口: ${user_port_text} 被转发IP和端口: ${user_ip_pf_text}:${user_port_pf_text}]${Font_color_suffix}\n"
                Restart_brook
            fi
        else
            echo "已取消..." && exit 0
        fi
    fi
}
Install_brook(){
    check_root
    [[ -e ${brook_file} ]] && echo -e "${Error} 检测到 Brook 已安装 !" && exit 1
    echo -e "${Info} 开始安装/配置 依赖..."
    Installation_dependency
    Install_Tools
    echo -e "${Info} 开始检测最新版本..."
    check_new_ver
    echo -e "${Info} 开始下载/安装..."
    Download_brook
    echo -e "${Info} 开始下载/安装 服务脚本(init)..."
    Service_brook
    echo -e "${Info} 开始写入 配置文件..."
    echo "" > ${brook_conf}
    echo -e "${Info} 开始设置 iptables防火墙..."
    Set_iptables
    echo -e "${Info} Brook 安装完成！默认配置文件为空，请选择 [设置 Brook 端口转发 - 添加 端口转发] 来添加端口转发。"
}
Start_brook(){
    check_installed_status
    check_pid
    [[ ! -z ${PID} ]] && echo -e "${Error} Brook 正在运行，请检查 !" && exit 1
    /etc/init.d/brook-pf start
}
Stop_brook(){
    check_installed_status
    check_pid
    [[ -z ${PID} ]] && echo -e "${Error} Brook 没有运行，请检查 !" && exit 1
    /etc/init.d/brook-pf stop
}
Restart_brook(){
    check_installed_status
    check_pid
    [[ ! -z ${PID} ]] && /etc/init.d/brook-pf stop
    /etc/init.d/brook-pf start
}
Uninstall_brook(){
    check_installed_status
    echo -e "确定要卸载 Brook ? [y/N]\n"
    read -e -p "(默认: n):" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        check_pid
        [[ ! -z $PID ]] && kill -9 ${PID}
        if [[ -e ${brook_conf} ]]; then
            user_all=$(cat ${brook_conf}|sed '/^\s*$/d')
            user_all_num=$(echo "${user_all}"|wc -l)
            if [[ ! -z ${user_all} ]]; then
                for((integer = 1; integer <= ${user_all_num}; integer++))
                do
                    port=$(echo "${user_all}"|sed -n "${integer}p"|awk '{print $1}')
                done
            fi
        fi
        if [[ ! -z $(crontab -l | grep "brook-pf-mod.sh monitor") ]]; then
            crontab_monitor_brook_cron_stop
        fi
        rm -rf ${file}
        if [[ ${release} = "centos" ]]; then
            chkconfig --del brook-pf
        else
            update-rc.d -f brook-pf remove
        fi
        rm -rf /etc/init.d/brook-pf
        echo && echo "Brook 卸载完成 !" && echo
    else
        echo && echo "卸载已取消..." && echo
    fi
}
View_Log(){
    check_installed_status
    [[ ! -e ${brook_log} ]] && echo -e "${Error} Brook 日志文件不存在 !" && exit 1
    echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志(正常情况是没有使用日志记录的)" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${brook_log}${Font_color_suffix} 命令。" && echo
    tail -f ${brook_log}
}
Set_crontab_monitor_brook(){
    check_installed_status
    check_crontab_installed_status
    crontab_monitor_brook_status=$(crontab -l|grep "brook-pf-mod.sh monitor")
    if [[ -z "${crontab_monitor_brook_status}" ]]; then
        echo && echo -e "当前监控模式: ${Green_font_prefix}未开启${Font_color_suffix}" && echo
        echo -e "确定要开启 ${Green_font_prefix}Brook 服务端运行状态监控${Font_color_suffix} 功能吗？(当进程关闭则自动启动 Brook 服务端)[Y/n]"
        read -e -p "(默认: y):" crontab_monitor_brook_status_ny
        [[ -z "${crontab_monitor_brook_status_ny}" ]] && crontab_monitor_brook_status_ny="y"
        if [[ ${crontab_monitor_brook_status_ny} == [Yy] ]]; then
            crontab_monitor_brook_cron_start
        else
            echo && echo "  已取消..." && echo
        fi
    else
        echo && echo -e "当前监控模式: ${Green_font_prefix}已开启${Font_color_suffix}" && echo
        echo -e "确定要关闭 ${Green_font_prefix}Brook 服务端运行状态监控${Font_color_suffix} 功能吗？(当进程关闭则自动启动 Brook 服务端)[y/N]"
        read -e -p "(默认: n):" crontab_monitor_brook_status_ny
        [[ -z "${crontab_monitor_brook_status_ny}" ]] && crontab_monitor_brook_status_ny="n"
        if [[ ${crontab_monitor_brook_status_ny} == [Yy] ]]; then
            crontab_monitor_brook_cron_stop
        else
            echo && echo "  已取消..." && echo
        fi
    fi
}
crontab_monitor_brook_cron_start(){
    crontab -l > "$file_1/crontab.bak"
    sed -i "/brook-pf-mod.sh monitor/d" "$file_1/crontab.bak"
    echo -e "\n*/1 * * * *  /bin/bash $file_1/brook-pf-mod.sh monitor" >> "$file_1/crontab.bak"
    crontab "$file_1/crontab.bak"
    rm -r "$file_1/crontab.bak"
    cron_config=$(crontab -l | grep "brook-pf-mod.sh monitor")
    if [[ -z ${cron_config} ]]; then
        echo -e "${Error} Brook 服务端运行状态监控功能 启动失败 !" && exit 1
    else
        echo -e "${Info} Brook 服务端运行状态监控功能 启动成功 !"
    fi
}
crontab_monitor_brook_cron_stop(){
    crontab -l > "$file_1/crontab.bak"
    sed -i "/brook-pf-mod.sh monitor/d" "$file_1/crontab.bak"
    crontab "$file_1/crontab.bak"
    rm -r "$file_1/crontab.bak"
    cron_config=$(crontab -l | grep "brook-pf-mod.sh monitor")
    if [[ ! -z ${cron_config} ]]; then
        echo -e "${Error} Brook 服务端运行状态监控功能 停止失败 !" && exit 1
    else
        echo -e "${Info} Brook 服务端运行状态监控功能 停止成功 !"
    fi
}
crontab_monitor_brook(){
    check_domain_ip_change
    check_installed_status
    check_pid
    echo "${PID}"
    if [[ -z ${PID} ]]; then
        echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] 检测到 Brook服务端 未运行 , 开始启动..." | tee -a ${brook_log}
        /etc/init.d/brook-pf start
        sleep 1s
        check_pid
        if [[ -z ${PID} ]]; then
            echo -e "${Error} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Brook服务端 启动失败..." | tee -a ${brook_log}
        else
            echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Brook服务端 启动成功..." | tee -a ${brook_log}
        fi
    else
        echo -e "${Info} [$(date "+%Y-%m-%d %H:%M:%S %u %Z")] Brook服务端 进程运行正常..." | tee -a ${brook_log}
    fi
}
Set_iptables(){
    if [[ ${release} == "centos" ]]; then
		systemctl stop firewalld &> /dev/null
		systemctl mask firewalld &> /dev/null
        service iptables save
        chkconfig --level 2345 iptables on
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        service iptables save
    else
        iptables-save > /etc/iptables.up.rules
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables-save > /etc/iptables.up.rules
    fi
	 echo "iptables放行完成"
}
Resolve_Hostname_To_IP(){
    ip=$(host -t a  $bk_domain_pf|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"|head -1)
    if [ -n "$ip" ]; then
        echo -e " IP: $ip"
    else
        echo -e "${Error} Could not resolve hostname [${bk_domain_pf}] !" && exit 1
    fi
}
check_sys
action=$1
if [[ "${action}" == "monitor" ]]; then
    crontab_monitor_brook
else
    echo && echo -e "  Brook 端口转发 一键管理脚本修改版(DDNS支持) ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 Brook
 ${Green_font_prefix} 2.${Font_color_suffix} 卸载 Brook
————————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启动 Brook
 ${Green_font_prefix} 4.${Font_color_suffix} 停止 Brook
 ${Green_font_prefix} 5.${Font_color_suffix} 重启 Brook
————————————
 ${Green_font_prefix} 6.${Font_color_suffix} 设置 Brook 端口转发
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 Brook 端口转发
 ${Green_font_prefix} 8.${Font_color_suffix} 查看 Brook 日志
 ${Green_font_prefix} 9.${Font_color_suffix} 监控 Brook 运行状态(如果使用DDNS必须打开)
 ————————————
 ${Green_font_prefix}10.${Font_color_suffix} 安装CNAME依赖(若添加DDNS出现异常)
 ${Green_font_prefix}11.${Font_color_suffix} 安装服务脚本(执行安装Brook后请勿重复安装)
 ${Green_font_prefix}12.${Font_color_suffix} iptables一键放行
————————————" && echo
if [[ -e ${brook_file} ]]; then
    check_pid
    if [[ ! -z "${PID}" ]]; then
        echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
    else
        echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
    fi
else
    echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
read -e -p " 请输入数字 [0-12]:" num
case "$num" in
    1)
    Install_brook
    ;;
    2)
    Uninstall_brook
    ;;
    3)
    Start_brook
    ;;
    4)
    Stop_brook
    ;;
    5)
    Restart_brook
    ;;
    6)
    Set_brook
    ;;
    7)
    check_installed_status
    list_port
    ;;
    8)
    View_Log
    ;;
    9)
    Set_crontab_monitor_brook
    ;;
    10)
    Install_Tools
    ;;
	11)
	Service_brook
	;;
	12)
	Set_iptables
	;;
    *)
    echo "请输入正确数字 [0-12]"
    ;;
esac
fi