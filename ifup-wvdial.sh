IP=$1
path_log=$2
wvdialconf="/etc/wvdial.conf"
[ -z ${IP} ] && IP=8.8.8.8
[ -z ${path_log} ] && path_log="/var/log"

if ! [ -f ${wvdialconf} ]; then
  echo "${datat} - File not found "${wvdialconf} 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
fi
usbdev=`awk -F "=" '/^Modem =/{print $2}' ${wvdialconf}`
[ -z "${usbdev}" ] && usbdev=`awk -F "=" '/^Modem=/{print $2}' ${wvdialconf}`

if [ -z "${usbdev}" ]; then
  echo "${datat} - Not found option <Modem>" 2>&1 | tee -a ${path_log}"/ifup-wvdial.log"
fi

while true; do
  ifconfig eth0 up
  sleep 3
  ping1="no"
  ping2="no"
  datal=`date +%Y%m%d`
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
        ifconfig eth0 down
        wvdial &
        sleep 14
    else
      if [ "${fiundwvdial}" = "yes" ]; then
        echo "${datat} - Kill wvdial"
        killall wvdial 2>/dev/null
        sleep 8
      fi
    fi
  fi
  if [ ${ping1} = "yes" -a ${ping2} = "no" ]; then
    if [ ${usbfound} = "yes" -a "${fiundwvdial}" = "yes" ]; then
       echo "${datat} - Kill wvdial"
       killall wvdial 2>/dev/null
       sleep 8
    fi
  fi
done