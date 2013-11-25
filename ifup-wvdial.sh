remote_ip=$1
path_log=$2
wvdial_conf="/etc/wvdial.conf"
[ -z ${remote_ip} ] && remote_ip=8.8.8.8
[ -z ${path_log} ] && path_log="/var/log"
datal=`date +%Y%m%d`
datat=`date +%T`
define_clearos=`cat /etc/issue | grep 'ClearOS'`
number_cycles_eth=3; cycle_eth=0
ping_eth="no"; ping_ppp="no"

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
  if ! [ -f ${wvdial_conf} ]; then
     echo "${datat} - File not found "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
     echo "${datat} - Create a new file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
     touch "${wvdial_conf}"
     error_code=$?
     if [ "${error_code}" != "0" ]; then
        echo "Error code ${error_code}"
        exit 1
     fi
  fi
  numrows=`wc -l "${wvdial_conf}" | awk '{print $1}'`
  if [ "${numrows}" = "0" ]; then
    echo "${datat} - Generation of the configuration file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    wvdialconf
    error_code=$?
    if [ "${error_code}" != "0" ]; then
       echo "Error code ${error_code}"
       exit 1
    fi
  fi
  checkconf=`awk -F "=" '/; Phone =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Target Phone Number>" ]; then
    echo "${datat} - Complete the 'Phone' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/; Username =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Your Login Name>" ]; then
    echo "${datat} - Complete the 'Username' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/; Password =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ "${checkconf}" = "<Your Password>" ]; then
    echo "${datat} - Complete the 'Password' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
    exit 1
  fi
  checkconf=`awk -F "=" '/Auto dns =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Auto dns = 1' ${wvdial_conf}
    echo "${datat} - Added option 'Auto dns' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
  checkconf=`awk -F "=" '/Dial Command =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Dial Command = ATDT' ${wvdial_conf}
    echo "${datat} - Added option 'Dial Command' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
  checkconf=`awk -F "=" '/Stupid Mode =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [ -z "${checkconf}" ]; then
    sed -i '/Password/ i\Stupid Mode = 1' ${wvdial_conf}
    echo "${datat} - Added option 'Stupid Mode' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
  checkconf=`awk -F "=" '/Baud =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
  if [[ "${checkconf}" -ne "921600" ]]; then
    sed -i 's|Baud.*|Baud = 921600|g' ${wvdial_conf}
    echo "${datat} - Fixed option 'Baud' in file "${wvdial_conf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi

}

create_ifcfg_ppp0(){
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
      sed -i "s|MODEMPORT=|MODEMPORT="${usb_dev}"|g" "${ifcfgppp0}"
      echo "${datat} - Create a file ${ifcfgppp0}" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  fi
}

del_default_route(){
  echo "${datat} - Remove the default route" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  DEFRT=$(ip route list match 0.0.0.0/0)
  echo "$DEFRT" | \
  while read spec; do
    if [ -n "${spec}" ]; then
       ip route del $spec;
    fi
  done
}

change_default_route(){
  echo "${datat} - Change default route" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  gateway_def=`ip route list | awk '/^default / { print $3 }'`
  gateway_dev=`ip route list | awk '/^default / { print $5 }'`
  if [ -f /var/run/ppp0.pid ] ; then
     if [ "${gateway_dev}" != "ppp0" ]; then
        wvdial_found="no"
        ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
        echo "${datat} - Found running WvDial ${wvdial_found}" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
        if [ "${wvdial_found}" = "no" ]; then
           echo "${datat} - del /var/run/ppp0.pid"
           rm -f /var/run/ppp0.pid
        fi
        del_default_route
        gateway=`ip route list | grep "ppp0  proto kernel" | awk '{ print $1 }'`
        if [ "${gateway}" != "${gateway_def}" ]; then
           echo "${datat} - Adding a default route gateway=${gateway} for ppp0" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
           ip route add default via "${gateway}" dev ppp0
           sleep 1
           echo "${datat} - Restart firewall " 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
           /etc/init.d/firewall restart
        fi
     fi
  else
    eth0_raised=`ip link show eth0 | grep "UP" | awk '{print $3}' | cut -d ',' -f 4 | cut -d '>' -f 1`
    if [ "${eth0_raised}" != "LOWER_UP" ]; then
      return
    fi
    if [ "${gateway_dev}" != "eth0" ]; then
       del_default_route
      . /etc/sysconfig/network-scripts/ifcfg-eth0
      if [ ${BOOTPROTO} = "dhcp" ]; then
         if [ -f /var/lib/dhclient/eth0.routers ]; then
            gateway=`head -n1 /var/lib/dhclient/eth0.routers`
        else
           echo "${datat} - File not found /var/lib/dhclient/eth0.routers" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
           return
        fi
      else
         gateway=`echo $GATEWAY | awk '{ print $1 }'`
         if [ -z ${gateway}]; then
            echo "${datat} - Empty parameter GATEWAY for file /etc/sysconfig/network-scripts/ifcfg-eth0" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
            return
         fi
      fi
      if [ "${gateway}" != "${gateway_def}" ]; then
         echo "${datat} - Adding a default route gateway=${gateway} for eth0" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
         ip route add default via "${gateway}" dev eth0
         sleep 1
         echo "${datat} - Restart firewall " 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
         /etc/init.d/firewall restart
      fi
    fi
 fi
}

killall_wvdial(){
  echo "${datat} - Kill wvdial" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  killall wvdial 2>/dev/null
  while true; do
    sleep 2
    wvdial_found="no"
    ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
    if [ ${wvdial_found} = "no" ]; then
      return
    fi
  done
  if [ -f /var/run/ppp0.pid ]; then
     echo "${datat} - del /var/run/ppp0.pid" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
     rm -f /var/run/ppp0.pid
  fi
}

start_wvdial(){
  echo "${datat} - Start wvdial" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  wvdial &
  while true; do
    sleep 2
    wvdial_found="no"
    ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
    if [ ${wvdial_found} = "no" ]; then
      return 1
    fi
    if [ -f /var/run/ppp0.pid ]; then
     break
    fi
  done
  sleep 2
  return 0
}

checking_internet() {
  gateway_dev=`ip route list | awk '/^default / { print $5 }'`
  if [ -z "${gateway_dev}" ]; then
     change_default_route
     gateway_dev=`ip route list | awk '/^default / { print $5 }'`
  fi
  if [ "${gateway_dev}" = "ppp0" ]; then
     ping_ppp="no"
     /bin/ping -q -I ppp0 ${remote_ip} -c 2 > /dev/null 2>&1 && ping_ppp="yes"
     echo "${datat} - Ping server via ppp0 " ${ping_ppp}
     if [ ${ping_ppp} = "no" ]; then
        usb_found="no"
        ls -l ${usb_dev} > /dev/null 2>&1 && usb_found="yes"
        echo "${datat} - Modem was found " ${usb_found}
        if [ ${usb_found} = "yes" ]; then
           wvdial_found="no"
           ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
           echo "${datat} - Found running WvDial ${wvdial_found}"
           if [ "${wvdial_found}" = "yes" ]; then
              killall_wvdial
           fi
           start_wvdial
           change_default_route
        fi
     else
        if [ ${number_cycles_eth} = ${cycle_eth} ]; then
           echo "Check appears on the interface eth0 ( cycle - ${cycle_eth})"
           cycle_eth=0;
           eth0_raised=`ip link show eth0 | grep "UP" | awk '{print $3}' | cut -d ',' -f 4 | cut -d '>' -f 1`
           if [ "${eth0_raised}" = "LOWER_UP" ]; then
              del_default_route
              . /etc/sysconfig/network-scripts/ifcfg-eth0
              if [ ${BOOTPROTO} = "dhcp" ]; then
                 if [ -f /var/lib/dhclient/eth0.routers ]; then
                    gateway=`head -n1 /var/lib/dhclient/eth0.routers`
                 else
                    echo "${datat} - File not found /var/lib/dhclient/eth0.routers" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
                    return
                 fi
              else
                 gateway=`echo $GATEWAY | awk '{ print $1 }'`
                 if [ -z ${gateway}]; then
                    echo "${datat} - Empty parameter GATEWAY for file /etc/sysconfig/network-scripts/ifcfg-eth0" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
                    return
                 fi
              fi
              if [ "${gateway}" != "${gateway_def}" ]; then
                 echo "${datat} - Adding a default route gateway=${gateway} for eth0" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
                 ip route add default via "${gateway}" dev eth0
              fi
              sleep 1
              ping_eth="no"
              /bin/ping -q -I eth0 ${remote_ip} -c 2 > /dev/null 2>&1 && ping_eth="yes"
              echo "${datat} - Ping server via eth0 " ${ping_eth}
              if [ ${ping_eth} = "no" ]; then
                 del_default_route
                 change_default_route
              else
                 killall_wvdial
              fi
           fi
        fi
        let "cycle_eth = ${cycle_eth} + 1";
     fi
  else
     ping_eth="no"
     /bin/ping -q -I eth0 ${remote_ip} -c 2 > /dev/null 2>&1 && ping_eth="yes"
     echo "${datat} - Ping server via eth0 " ${ping_eth}
     if [ ${ping_eth} = "no" ]; then
        usb_found="no"
        ls -l ${usb_dev} > /dev/null 2>&1 && usb_found="yes"
        echo "${datat} - Modem was found " ${usb_found}
        if [ ${usb_found} = "yes" ]; then
           wvdial_found="no"
           ps -A | grep 'wvdial' > /dev/null 2>&1 && wvdial_found="yes"
           echo "${datat} - Found running WvDial ${wvdial_found}" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
           if [ "${wvdial_found}" = "yes" ]; then
              change_default_route
              sleep 1
              ping_ppp="no"
              /bin/ping -q -I ppp0 ${remote_ip} -c 1 > /dev/null 2>&1 && ping_ppp="yes"
              if [ ${ping_ppp} = "no" ]; then
                 killall_wvdial
              else
                return
              fi
           fi
           start_wvdial
           change_default_route
        fi
     fi
  fi
}


if [ -z "${define_clearos}" ]; then
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

usb_dev=`awk -F "=" '/^Modem =/{print $2}' ${wvdial_conf} | sed 's/^[ \t]*//'`
[ -z "${usb_dev}" ] && usb_dev=`awk -F "=" '/^Modem=/{print $2}' ${wvdial_conf}`
if [ -z "${usb_dev}" ]; then
  echo "${datat} - Not found option 'Modem'" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
  exit 1
fi

while true; do
  fix_network_conf "ppp0"
  sleep 3
  datat=`date +%T`
  checking_internet
done