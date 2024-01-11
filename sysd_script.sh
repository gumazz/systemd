#!/bin/bash

#Watchlog part

#Watchlog configuration file
cat >> /etc/sysconfig/watchlog << EOF
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF

#Wathlog log file to parse
cat >> /var/log/watchlog.log << EOF
1
2
3
4
5
ALERT
6
7
8
9
10
EOF

#Watchlog script
cat >> /opt/watchlog.sh << EOF
#!/bin/bash
WORD=\$1
LOG=\$2
DATE=\`date\`

if grep \$WORD \$LOG &> /dev/null
then
	logger "\$DATE: I found word, Master!"
else
	exit 0
fi
EOF

#adding executable rights for the script
chmod +x /opt/watchlog.sh

#Watchlog systemd service configuration
cat >> /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF

#Watchlog systemd timer configuration
cat >> /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second

[Timer]
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF

#Reload systemd configuration
systemctl daemon-reload

systemctl start watchlog.timer
systemctl start watchlog.service
systemctl status watchlog.timer
systemctl status watchlog.service

#Spawn-fcgi part


yum install epel-release -y
yum install spawn-fcgi httpd php php-cli mod_fcgid -y

#Spawn-fcgi configuration
cat >>/etc/sysconfig/spawn-fcgi << EOF
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
EOF

#Spawn-fcgi systemd service configuration
cat >> /etc/systemd/system/spawn-fcgi.service << EOF
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

#Start spawn-fcgi service
systemctl start spawn-fcgi

systemctl status spawn-fcgi

#httpd instances part

cat >> /etc/systemd/system/httpd@.service << EOF
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd \$OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd \$OPTIONS -k graceful
ExecStop=/bin/kill -WINCH \${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

echo "OPTIONS=-f conf/first.conf" >> /etc/sysconfig/httpd-first
echo "OPTIONS=-f conf/second.conf" > /etc/sysconfig/httpd-second

cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
echo "PidFile /var/run/httpd-first.pid" >> /etc/httpd/conf/first.conf
sed -i "s/Listen 80/Listen 8080/g" /etc/httpd/conf/first.conf


cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
echo "PidFile /var/run/httpd-second.pid" >> /etc/httpd/conf/second.conf
sed -i "s/Listen 80/Listen 8081/g" /etc/httpd/conf/second.conf

setenforce 0
systemctl daemon-reload
systemctl start httpd@first
systemctl start httpd@second
systemctl status httpd@first
systemctl status httpd@second
