ifup-wvdial
===========

Script to use USB 3G UMTS modems ClearOS 6.x.
To raise the PPP connection using command line utility wvdial.
Automatic reconnect on loss of connection or ping failure.

Developer site: http://khv.at.ua

`$ cp ifup-wvdial.sh /etc/ppp/`

`$ sudo nano /etc/wvdial.conf`
```
[Dialer Defaults]
Phone = *99#
Username = mms       
Auto dns = 1
Dial Command = ATDT
Password = mms     
; Username = 9180****** (If your provider use without Username)
Auto dns = 1
Dial Command = ATDT
; Password = 9180****** (If your provider use without Password)
Stupid Mode = 1
Modem = /dev/ttyUSB4
Baud = 921600
Init3 = AT+CGDCONT=1,"IP","m3-world"
```

`$ sudo nano /etc/network/interfaces`
append line:
```
auto ppp0
    iface ppp0 inet wvdial
       provider Vinanphone
       pre-up /bin/bash /etc/ppp/ifup-wvdial.sh &> /dev/null 2>&1 &
       post-up echo "3G (ppp0) deamon is online"
```
