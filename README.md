ifup-wvdial
===========

Script to use USB 3G UMTS modems ClearOS 6.x.
To raise the PPP connection using command line utility wvdial.
Automatic reconnect on loss of connection or ping failure.

Developer site: http://khv.at.ua

`$ cp ifup-wvdial.sh /etc/ppp/`

`$ nano /etc/network/interfaces`
```
auto ppp0
    iface ppp0 inet wvdial
       provider Vinanphone
       pre-up /bin/bash /etc/ppp/ifup-wvdial.sh &> /dev/null 2>&1 &
       post-up echo "3G (ppp0) deamon is online"
```
