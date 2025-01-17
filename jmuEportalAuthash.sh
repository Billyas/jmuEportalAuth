#!/bin/ash

# 判断输入参数是否跟登录进程有关
_do_nothing_with_login_=0
# 判断是否是自动重新登录
_is_auto_reauth_=0

# OpenWrt/LEDE
config_file="/etc/config/jmuEportalAuth"
# Padavan
# config_file="/etc/storage/jmuEportalAuth.conf"

# 执行参数变量声明
param_service=""
param_username=""
param_password=""

# eportal的基础url
eportal_base="http://10.8.2.2/eportal/"

# 返回204的url，用于判断是否认证成功和获取登录url
# url_generate_204="http://g.cn/generate_204"
url_generate_204="1.1.1.1"
# 使用桌面版UA，防止移动版页面被提供
user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36"

# 显示提示消息并以0终止
showHelp() {
    echo $'\n  JMU Eportal Authentication\n  集美大学Eportal认证\n\n    Usage (使用方法):\n        -h Get help information (获取帮助信息)\n        -k Kill process (结束进程，会下线)\n\n        -s Service Name (服务名称)\n           0(教育网接入) / 1(电信宽带接入) / 2(联通宽带接入) / 3(移动宽带接入)\n        -u Username (用户名) (工号/学号)\n        -p Password (密码)\n\n        -r Retry authentication with configured (已配置情况下重新认证)\n\n    Example (示例):\n        jmuEportalAuth -h\n        jmuEportalAuth -k\n        jmuEportalAuth -s 1 -u 学号 -p 密码\n        jmuEportalAuth -r\n\n    About (关于):\n        Based on https://github.com/LGiki/RuijiePortalLoginTool\n        Modified By alex@jmu.edu.cn\n'
    exit 0
}

# 判断是否已联网
isOnline() {
    # 已在线时以0结束
    #captiveReturnCode=`curl -s -I -m 10 -o /dev/null -s -w %{http_code} ${url_generate_204}`
    captiveReturnCode=`curl  -m 10 -s  1.1.1.1`
    result=`echo ${captiveReturnCode} | grep "<script>top.self.location.href='http://10.8.2.2/ep" `
    if [ "$result" == "" ]; then
        return 1
    else
        return 0
    fi
}

# 显示提示消息并以0终止
setCrontab() {
    touch /etc/crontabs/root
}

# 执行下线动作并以0终止
doLogout() {
    isOnline
    if [ $? == 0 ]; then
        echo " -- 已下线 "
    elif [ $? == 1 ]; then
        echo " -- 正在执行下线..."
        #userIndex=`curl -s -A ${user_agent} -I ${eportal_base}redirectortosuccess.jsp | grep -o 'userIndex=.*'`
        logoutResult=`curl -s ${eportal_base}InterFace.do?method=logout | awk -F , '{print $2}' | awk -F : '{print $2}' | awk -F \" '{print $2}'`
        echo " -- ${logoutResult}"
        exit 0
    fi
}

startAuth() {
    # 判断是否已在线
    isOnline
    if [ $? == 0 ]; then
        # 此处字符串进行了两次encodeURI（设计如此），需要两次decodeURI才可得到原字符串

        # 教育网接入
        service_ca="%25E6%2595%2599%25E8%2582%25B2%25E7%25BD%2591%25E6%258E%25A5%25E5%2585%25A5"
        service_name_ca="教育网接入"
        # 电信宽带接入
        service_ct="%25E7%2594%25B5%25E4%25BF%25A1%25E5%25AE%25BD%25E5%25B8%25A6%25E6%258E%25A5%25E5%2585%25A5"
        service_name_ct="电信宽带接入"
        # 联通宽带接入
        service_cu="%25E8%2581%2594%25E9%2580%259A%25E5%25AE%25BD%25E5%25B8%25A6%25E6%258E%25A5%25E5%2585%25A5"
        service_name_cu="联通宽带接入"
        # 移动宽带接入
        service_cm="%25E7%25A7%25BB%25E5%258A%25A8%25E5%25AE%25BD%25E5%25B8%25A6%25E6%258E%25A5%25E5%2585%25A5"
        service_name_cm="移动宽带接入"

        service=""
        service_name=""

        if [ ${param_service} == "0" ]; then
            service=${service_ca}
            service_name=${service_name_ca}
        elif [ ${param_service} == "1" ]; then
            service=${service_ct}
            service_name=${service_name_ct}
        elif [ ${param_service} == "2" ]; then
            service=${service_cu}
            service_name=${service_name_cu}
        elif [ ${param_service} == "3" ]; then
            service=${service_cm}
            service_name=${service_name_cm}
        fi

        echo " -- 用户名　　: ${param_username}"
        echo " -- 运营商服务: ${service_name}"

        # 访问页面，跳转认证页面
        loginPageURL=`curl -s ${url_generate_204} | awk -F \' '{print $2}'`
        # Structure loginURL
        loginURL=`echo $loginPageURL | awk -F \? '{print $1}'`
        loginURL="${loginURL/index.jsp/InterFace.do?method=login}"
        # Structure quertString
        queryString=`echo $loginPageURL | awk -F \? '{print $2}'`
        queryString="${queryString//&/%2526}"
        queryString="${queryString//=/%253D}"
        
        # 发起登录请求
        if [ -n "${loginURL}" ]; then
            authMessage=`curl -s -A "${user_agent}" -e "${loginPageURL}" -b "EPORTAL_COOKIE_USERNAME=; EPORTAL_COOKIE_PASSWORD=; EPORTAL_COOKIE_SERVER=; EPORTAL_COOKIE_SERVER_NAME=; EPORTAL_AUTO_LAND=; EPORTAL_USER_GROUP=%E5%AD%A6%E7%94%9F%E5%8C%85%E6%9C%88; EPORTAL_COOKIE_OPERATORPWD=;" -d "userId=${param_username}&password=${param_password}&service=${service}&queryString=${queryString}&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" "${loginURL}" | awk -F , '{print $3}' | awk -F : '{print $2}' | awk -F \" '{print $2}'`
            if [ "${authMessage}" == "" ]; then
                echo " -- 认证成功"
            else
                echo " -- ${authMessage}"
            fi
        fi
    elif [ $? == 1 ]; then
        echo " -- 已在线，无需认证 "
        exit 0
    fi
}

# 通过-r参数 读取config自动认证
retryAuth() {
    echo " -- 开始重新认证..."
    param_service=`sed -n "/option services/p" $config_file | awk -F \' '{print $2}'`
    param_username=`sed -n "/option username/p" $config_file | awk -F \' '{print $2}'`
    param_password=`sed -n "/option password/p" $config_file | awk -F \' '{print $2}'`

    if [ "${param_service}" != "" ] && [ "${param_username}" != "" ] && [ "${param_password}" != "" ] && [ "${_do_nothing_with_login_}" == 0 ]
    then
        startAuth
    else
        echo " -- 错误: 未配置认证参数 "
    fi
}

# 监听参数传入
while getopts "crkhs:u:p:" arg
do
    case $arg in
        c)
            _do_nothing_with_login_=1
            setCrontab
            ;;
        r)
            _is_auto_reauth_=1
            retryAuth
            ;;
        h)
            showHelp
            _do_nothing_with_login_=1
            ;;
        s)
            if [ "${OPTARG}" != "" ]; then
                param_service=${OPTARG}
            fi
            ;;
        u)
            if [ "${OPTARG}" != "" ]; then
                param_username=${OPTARG}
            fi
            ;;
        p)
            if [ "${OPTARG}" != "" ]; then
                param_password=${OPTARG}
            fi
            ;;
        k)
            doLogout
            _do_nothing_with_login_=1
            ;;
        ?)
            echo " -- 错误: 无效的参数 "
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

# 当所有参数齐全后，开始认证过程
if [ "${param_service}" != "" ] && [ "${param_username}" != "" ] && [ "${param_password}" != "" ] && [ "${_do_nothing_with_login_}" == 0 ]
then
    startAuth
elif [ "${_do_nothing_with_login_}" == 1 ]; then
    exit 0
elif [ "${_is_relogin_}" == 1 ]; then
    return
else
    showHelp
fi
