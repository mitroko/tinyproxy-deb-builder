#!/bin/bash -e
export NAME=tinyproxy
export VERSION=1.11.0-rc1
export ITER=0
export ARCH=amd64

echo "Preparing system"
apt update
apt-get -y install ruby ruby-dev rubygems build-essential python-pip git automake curl
gem install --no-document fpm

echo "Clonning sources"
git clone https://github.com/tinyproxy/tinyproxy.git ${NAME}
cd ${NAME}
git checkout ${VERSION}

echo "Configuring tinyproxy"
./autogen.sh

echo "Compiling tinyproxy bin"
make
./src/tinyproxy -v
cd ../

echo "Gathering artifacts"
mkdir -p usr/bin etc/default etc/tinyproxy lib/systemd/system usr/share/man/man5 usr/share/man/man8
cat ${NAME}/docs/man8/tinyproxy.8 | gzip -9 > usr/share/man/man8/tinyproxy.8.gz
cat ${NAME}/docs/man5/tinyproxy.conf.5 | gzip -9 > usr/share/man/man5/tinyproxy.conf.5.gz
cp ${NAME}/src/tinyproxy usr/bin/

echo 'FLAGS="-c /etc/tinyproxy/tinyproxy.conf"' > etc/default/tinyproxy

cat > etc/tinyproxy/tinyproxy.conf << _EOF
User nobody
Group nogroup
Port 3129
Timeout 600
DefaultErrorFile "/usr/share/tinyproxy/default.html"
Logfile "/var/log/tinyproxy/tinyproxy.log"
Syslog On
LogLevel Info
PidFile "/run/tinyproxy.pid"
XTinyproxy No

MaxClients 50
Allow 127.0.0.1
DisableViaHeader Yes
Anonymous "Host"
Anonymous "Authorization"
Anonymous "Cookie"
ConnectPort 443
_EOF

cat > lib/systemd/system/tinyproxy.service << _EOF
[Unit]
Description=Tinyproxy lightweight HTTP Proxy
After=network.target
Documentation=man:tinyproxy(8) man:tinyproxy.conf(5)

[Service]
EnvironmentFile=-/etc/default/tinyproxy
Type=forking
ExecStart=/usr/bin/tinyproxy $FLAGS
ExecStartPre=/bin/mkdir -p /var/log/tinyproxy /run/tinyproxy
ExecStartPre=/bin/chown nobody:nogroup /var/log/tinyproxy /run/tinyproxy
ExecStartPre=/bin/chmod 0750 /var/log/tinyproxy
ExecStartPre=/bin/chmod 0755 /run/tinyproxy
PIDFile=/run/tinyproxy/tinyproxy.pid
PrivateDevices=yes

[Install]
WantedBy=multi-user.target
_EOF

echo "Building deb package"
fpm -s dir -t deb --name ${NAME} -f -v ${VERSION} -a ${ARCH} --iteration ${ITER} \
  --description "A light-weight HTTP/HTTPS proxy daemon for POSIX operating systems." \
  --config-files /etc/tinyproxy/tinyproxy.conf \
  --config-files /etc/default/tinyproxy \
  --deb-systemd lib/systemd/system/tinyproxy.service \
  --deb-priority optional \
  --category "universe/net" \
  --license GPLv2 \
  --url "https://tinyproxy.github.io/" \
  --maintainer "Dzmitry Stremkouski <dstremkouski@mirantis.com>" \
  --vendor "Dzmitry Stremkouski <dstremkouski@mirantis.com>" \
  usr/bin/tinyproxy=/usr/bin/ \
  etc/tinyproxy/tinyproxy.conf=/etc/tinyproxy/ \
  etc/default/tinyproxy=/etc/default/ \
  usr/share/man/man8/tinyproxy.8.gz=usr/share/man/man8/ \
  usr/share/man/man5/tinyproxy.conf.5.gz=usr/share/man/man5/

echo "Metadata for the package:"
dpkg --info ${NAME}_${VERSION}-${ITER}_${ARCH}.deb

echo "Uploading deb file: ${NAME}_${VERSION}-${ITER}_${ARCH}.deb"
cat ${NAME}_${VERSION}-${ITER}_${ARCH}.deb | curl -s --upload-file - https://sbin.tk
