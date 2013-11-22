IP=$1
path_log=$2
wvdialconf="/etc/wvdial.conf"
[ -z ${IP} ] && IP=8.8.8.8
[ -z ${path_log} ] && path_log="/var/log"
datal=`date +%Y%m%d`
datat=`date +%T`
defineOS=`cat /etc/issue | grep 'ClearOS'`

fix_network_conf() {
  interface=$1
  networkconf=/etc/clearos/network.conf
  extif=`awk -F "=" '/^EXTIF/{print $2}' ${networkconf} | sed 's/^[ \t]*//'`
  extif=`expr "${extif}" : ".*\(${interface}\)"`
  if [ -z "${extif}" ]; then
     sed -i 's|EXTIF=".*|EXTIF="'${interface}'"|g' "${networkconf}"
     echo "${datat} - Fixed option 'EXTIF=' in file ${networkconf}" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
}

fix_wvdial_conf() {
  if ! [ -f ${wvdialconf} ]; then
     echo "${datat} - File not found "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
     echo "${datat} - Create a new file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
     touch "${wvdialconf}"
     error_code=$?
     if [ "${error_code}" != "0" ]; then
        echo "Error code ${error_code}"
        exit 1
     fi
  fi
  numrows=`wc -l "${wvdialconf}" | awk '{print $1}'`
  if [ "${numrows}" = "0" ]; then
    echo "${datat} - Generation of the configuration file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    wvdialconf
    error_code=$?
    if [ "${error_code}" != "0" ]; then
       echo "Error code ${error_code}"
       exit 1
    fi
  fi
  checkconf=`awk -F "=" '/; Phone =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Target Phone Number>" ]; then
    echo "${datat} - Complete the 'Phone' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/; Username =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Your Login Name>" ]; then
    echo "${datat} - Complete the 'Username' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/; Password =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Your Password>" ]; then
    echo "${datat} - Complete the 'Password' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/Auto dns =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Auto dns = 1' ${wvdialconf}
    echo "${datat} - Added option 'Auto dns' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
  checkconf=`awk -F "=" '/Dial Command =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Dial Command = ATDT' ${wvdialconf}
    echo "${datat} - Added option 'Dial Command' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
  checkconf=`awk -F "=" '/Stupid Mode =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Stupid Mode = 1' ${wvdialconf}
    echo "${datat} - Added option 'Stupid Mode' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
  checkconf=`awk -F "=" '/Baud =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
  if [[ "${checkconf}" -ne "921600" ]]; then
    sed -i 's|Baud.*|Baud = 921600|g' ${wvdialconf}
    echo "${datat} - Fixed option 'Baud' in file "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi

}

create_ifcfg_ppp0(){
 if [ -n "${defineOS}" ]; then
   ifcfgppp0=/etc/sysconfig/network-scripts/ifcfg-ppp0
   if ! [ -f "${ifcfgppp0}" ]; then
      echo 'DEVICE=ppp0
           NAME=DSLppp0
           TYPE="dialup"
           BOOTPROTO="dialup"
           WVDIALSECT=Default
           MODEMPORT=
           LINESPEED=921600
           PAPNAME=test
           USERCTL=true
           ONBOOT=yes
           PERSIST=no
           DEFROUTE=yes
           PEERDNS=no
           DEMAND=no
           IDLETIMEOUT=600' >> "${ifcfgppp0}"
      sed -i 's/^[ \t]*//' "${ifcfgppp0}"
      sed -i "s|MODEMPORT=|MODEMPORT="${usbdev}"|g" "${ifcfgppp0}"
      echo "${datat} - Create a file ${ifcfgppp0}" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
   fi
 fi
}

add_default_route(){
 echo "!!!!!!"
 gateway_dev=`ip route list | awk '/^default / { print $3 }'`
 if [ -f /var/run/ppp0.pid ] ; then
    if [ "${gateway_dev}" != "ppp0" ]; then
         DEFRT=$(ip route list match 0.0.0.0/0)
         echo "$DEFRT" | while read spec; do
           ip route del $spec;
         done
     gateway=`ip route list | grep "ppp0  proto kernel" | awk '{ print $1 }'`
     ip route add default via "${gateway}" dev ppp0
   fi
 else
    if [ "${gateway_dev}" != "eth0" ]; then
      DEFRT=$(ip route list match 0.0.0.0/0)
      echo "$DEFRT" | while read spec; do
        ip route del $spec;
      done
      . /etc/sysconfig/network-scripts/ifcfg-eth0
      gateway=`echo $GATEWAY | awk '{ print $1 }'`
      ip route add default via "${gateway}" dev eth0
    fi
 fi
}

if [ -z "${defineOS}" ]; then
  echo "Script is designed to ClearOS"
  exit
fi
create_ifcfg_ppp0
fix_wvdial_conf
error_code=$?
if [ "${error_code}" != "0" ]; then
   echo "Error code ${error_code}"
   exit 1
fi

usbdev=`awk -F "=" '/^Modem =/{print $2}' ${wvdialconf} | sed 's/^[ \t]*//'`
[ -z "${usbdev}" ] && usbdev=`awk -F "=" '/^Modem=/{print $2}' ${wvdialconf}`
if [ -z "${usbdev}" ]; then
  echo "${datat} - Not found option 'Modem'" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  exit 1
fi

while true; do
  fix_network_conf "ppp0"
  sleep 3
  ping1="no"
  ping2="no"
  datat=`date +%T`
  /bin/ping -I eth0 ${IP} -c 2 > /dev/null 2>&1 && ping1="yes"
  /bin/ping -I ppp0 ${IP} -c 2 > /dev/null 2>&1 && ping2="yes"
  echo "${datat} - Ping server via eth0 " ${ping1}
  echo "${datat} - Ping server via ppp0 " ${ping2}
  usbfound="no"
  ls -l ${usbdev} > /dev/null 2>&1 && usbfound="yes"
  echo "${datat} - Modem was found " ${usbfound}
  fiundwvdial="no"
  ps -A | grep 'wvdial' > /dev/null 2>&1 && fiundwvdial="yes"
  echo "${datat} - Fiund was wvdial ${fiundwvdial}"
  if [ ${ping1} = "no" -a ${ping2} = "no" ]; then
    if [ ${usbfound} = "yes" -a "${fiundwvdial}" = "no" ]; then
        echo "${datat} - Start wvdial"
        wvdial &
        error_code=$?
        if [ "${error_code}" != "0" ]; then
            echo "Error code ${error_code}"
        fi
        sleep 10
        add_default_route
    else
      if [ "${fiundwvdial}" = "yes" ]; then
        echo "${datat} - Kill wvdial"
        killall wvdial 2>/dev/null
        sleep 5
        add_default_route
      fi
    fi
  fi
  if [ ${ping1} = "yes" -a ${ping2} = "no" ]; then
    if [ ${usbfound} = "yes" -a "${fiundwvdial}" = "yes" ]; then
       echo "${datat} - Kill wvdial"
       killall wvdial 2>/dev/null
       sleep 5
       add_default_route
    fi
  fi
done