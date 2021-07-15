remote_ip=$1
path_log=$2
wvdial_conf="/etc/wvdial.conf"
[ -z ${remote_ip} ] && remote_ip=8.8.8.8
[ -z ${path_log} ] && path_log="/var/log"
datal=`date +%Y%m%d`
datat=`date +%T`
define_clearos=`cat /etc/issue | grep 'ClearOS'`
cycles_start_wvdial=5
ping_ppp="no"; usb_dev="/dev/ttyUSB4"; cur_ping_ppp=""; run_program_ppp=$4

fix_network_conf() {
  interface=$1
  networkconf=/etc/clearos/network.conf
  extif=`awk -F "=" '/^EXTIF/{print $2}' ${networkconf} | sed 's/^[ \t]*//'`
  extif=`expr "${extif}" : ".*\(${interface}\)"`
  if [ -z "${extif}" ]; then
     sed -i 's|EXTIF=".*|EXTIF="'${interface}'"|' "${networkconf}"
     echo "${datat} - Fixed option 'EXTIF=' in file ${networkconf}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
}

fix_wvdial_conf() {
  pkg_wvdial="no"
  which wvdial > /dev/null 2>&1 && pkg_wvdial="yes"
  if [ "${pkg_wvdial}" = "no" ]; then
     echo "Package is not installed 'wvdial'"
     echo "To install, run in the console: yum install wvdial"
     exit 1
  fi
  if ! [ -f ${wvdial_conf} ]; then
     echo "${datat} - File not found "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
     echo "${datat} - Create a new file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
     touch "${wvdial_conf}"
     error_code=$?
     if [ "${error_code}" != "0" ]; then
        echo "Error code ${error_code}"
        exit 1
     fi
  fi
  numrows=`wc -l "${wvdial_conf}" | awk '{print $1}'`
  if [ "${numrows}" = "0" ]; then
    echo "${datat} - Generation of the configuration file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
    wvdialconf
    error_code=$?
    if [ "${error_code}" != "0" ]; then
       echo "Error code ${error_code}"
       exit 1
    fi
  fi
  checkconf=`awk -F "=" '/; Phone =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Target Phone Number>" ]; then
    echo "${datat} - Complete the 'Phone' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/; Username =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Your Login Name>" ]; then
    echo "${datat} - Complete the 'Username' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/; Password =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Your Password>" ]; then
    echo "${datat} - Complete the 'Password' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/Auto dns =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Auto dns = 1' ${wvdial_conf}
    echo "${datat} - Added option 'Auto dns' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
  checkconf=`awk -F "=" '/Dial Command =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Dial Command = ATDT' ${wvdial_conf}
    echo "${datat} - Added option 'Dial Command' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
  checkconf=`awk -F "=" '/Stupid Mode =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Stupid Mode = 1' ${wvdial_conf}
    echo "${datat} - Added option 'Stupid Mode' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
  checkconf=`awk -F "=" '/Baud =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [[ "${checkconf}" -ne "921600" ]]; then
    sed -i 's|Baud.*|Baud = 921600|g' ${wvdial_conf}
    echo "${datat} - Fixed option 'Baud' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
  usb_dev=`awk -F "=" '/^Modem =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  [ -z "${usb_dev}" ] && usb_dev=`awk -F "=" '/^Modem=/{print $2}' ${wvdial_conf}`
  if [ -z "${usb_dev}" ]; then
     echo "${datat} - Not found option 'Modem'" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
     exit 1
  fi
}

create_ifcfg_ppp0(){
  ifcfg_ppp0=/etc/network/interfaces.d/ifcfg-ppp0
  if ! [ -f "${ifcfg_ppp0}" ]; then
      echo 'DEVICE=ppp0
            TYPE="xDSL"
            USERCTL="no"
            BOOTPROTO="dialup"
            NAME="DSLppp0"
            ONBOOT="no"
            PIDFILE="/var/run/ppp0.pid"
            FIREWALL="NONE"
            PING="."
            PPPOE_TIMEOUT="80"
            LCP_FAILURE="5"
            LCP_INTERVAL="20"
            CLAMPMSS="1412"
            CONNECT_POLL="6"
            CONNECT_TIMEOUT="80"
            DEFROUTE="yes"
            SYNCHRONOUS="no"
            ETH="eth3"
            PROVIDER="intertelecom"
            USER=""' >> "${ifcfg_ppp0}"
      sed -i 's/^[ \t]*//' "${ifcfg_ppp0}"
      echo "${datat} - Create a file ${ifcfg_ppp0}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
}

create_ifcfg_eth3(){
  ifcfg_eth3=/etc/sysconfig/network-scripts/ifcfg-eth3
  if ! [ -f "${ifcfg_eth3}" ]; then
      echo 'DEVICE=ppp0
            DEVICE=eth3
            BOOTPROTO="none"
            ONBOOT="no"' >> "${ifcfg_eth3}"
      sed -i 's/^[ \t]*//' "${ifcfg_eth3}"
      echo "${datat} - Create a file ${ifcfg_eth3}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  fi
}

del_default_route(){
  DEFRT=$(ip route list match 0.0.0.0/0)
  echo "$DEFRT" | \
  while read spec; do
    if [ -n "${spec}" ]; then
       echo "${datat} - Remove the default route: ${spec}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
       ip route del $spec;
    fi
  done
}

change_default_route(){
#  echo "${datat} - Change default route" > 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  gateway_def=`ip route list | awk '/^default / { print $3 }'`
  gateway_dev=`ip route list | awk '/^default / { print $5 }'`
  if [ -f /var/run/ppp0.pid ] ; then
     if [ "${gateway_dev}" != "ppp0" ]; then
        wvdial_found="no"
        ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
        echo "${datat} - USB device ${usb_dev} found " ${usb_found}  2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
        if [ "${wvdial_found}" = "no" ]; then
           echo "${datat} - del /var/run/ppp0.pid" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
           rm -f /var/run/ppp0.pid
        fi
        gateway=`ip route list | grep "ppp0  proto kernel" | awk '{ print $1 }'`
        if [ -z "${gateway}" ]; then
          return
        fi
        if [ "${gateway}" != "${gateway_def}" ]; then
           del_default_route
           echo "${datat} - Adding a default route gateway=${gateway} for ppp0" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
           ip route add default via "${gateway}" dev ppp0
        fi
     fi
 fi
}

killall_wvdial(){
  echo "${datat} - Kill wvdial" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  killall wvdial 2>/dev/null
  while true; do
    sleep 3
    wvdial_found="no"
    ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
    if [ ${wvdial_found} = "no" ]; then
      break
    fi
  done
  sleep 5
  if [ -f /var/run/ppp0.pid ]; then
     echo "${datat} - del /var/run/ppp0.pid" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
     rm -f /var/run/ppp0.pid
  fi
}

start_wvdial(){
  cycl_start=0
  # fix_network_conf "ppp0"
  echo "${datat} - Start wvdial affter 60s" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
  #cho 40s truoc khi start tranh loi urb -19 usbresubmit
  sleep 60
  wvdial &
  while true; do
    sleep 3
    wvdial_found="no"
    ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
    if [ "${wvdial_found}" = "no" ]; then
       return 1
    fi
    gateway_dev=`ip route list | awk '/^default / { print $5 }'`
    if [ "${gateway_dev}" = "ppp0" ]; then
       break
    fi
    if [ ${cycl_start} = ${cycles_start_wvdial} ]; then
       echo "${datat} - Break to cycles start wvdial ${cycles_start_wvdial}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
       break
    fi
    let "cycl_start = ${cycl_start} + 1";
  done
  sleep 5
  echo "nameserver 8.8.8.8\nnameserver 1.1.1.1">/etc/resolv.conf
  # change_default_route
  # /etc/init.d/firewall restart
  return 0
}

checking_internet() {
  change_default_route
  gateway_dev=`ip route list | awk '/^default / { print $5 }'`
  ping_ppp="no"
  /bin/ping -q -I ppp0 ${remote_ip} -c 3 > /dev/null 2>&1 && ping_ppp="yes"
  if [ "${cur_ping_ppp}" != "${ping_ppp}" ]; then
     echo "${datat} - 0 Ping server via ppp0 " ${ping_ppp} 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
     cur_ping_ppp=${ping_ppp};
  fi
  if [ "${ping_ppp}" = "no" ]; then
     usb_found="no"
     ls -l ${usb_dev} > /dev/null 2>&1 && usb_found="yes"
     echo "${datat} - USB device ${usb_dev} found " ${usb_found}  2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
     if [ "${usb_found}" = "yes" ]; then
        wvdial_found="no"
        ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
        echo "${datat} - Found running process wvdial ${wvdial_found}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
        if [ "${wvdial_found}" = "yes" ]; then
           killall_wvdial
        fi
           start_wvdial
        fi
  fi
}

# if [ -z "${define_clearos}" ]; then
#   echo "Script is designed to ClearOS"
#   exit
# fi
echo "${datat} - Run script" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
create_ifcfg_ppp0
# create_ifcfg_eth3
# fix_network_conf "ppp0"
fix_wvdial_conf
error_code=$?
if [ "${error_code}" != "0" ]; then
   echo "${datat} - Error code ${error_code}" 2>&1 | tee -a ${path_log}"/ifup-wvdial-${datal}.log"
   exit 1
fi

while true; do
  datal=`date +%Y%m%d`
  datat=`date +%T`
  checking_internet
  sleep 5
done