#!/bin/bash
#
# ejc-2022
# Samba Install
# RHEL (CentOS/Rocky/OEL - 8.6)
#

# Variables
ethinterface="USER_INPUT"
ethip="USER_INPUT"
netmask="USER_INPUT"
gateway="USER_INPUT"
host_name="USER_INPUT"

# Check for root
if [ "$EUID" -ne 0 ]
  then echo "Must be run with sudo or as root!"
  exit
fi

# Update the system
yum update -y
yum upgrade -y

# What's the config?
echo ""
echo "Current Inteface Config..."
ifconfig

# Prompt user for info
echo ""
read -p "What interface to use? " ethinterface
read -p "What IP to use? " ethip
read -p "What netmask to use? " netmask

# Change iface config
ifconfig $ethinterface $ethip netmask $netmask

# Check the routes
echo ""
echo "Current routes..."
route -n

# Prompt user for info
echo ""
read -p "What gateway to use? " gateway

# Change gateway
route add default gw $gateway $ethinterface

# What is SELINUX status?
echo ""
echo "SELINUX status..."
sestatus

# Disable SELINUX
echo ""
read -p "We need to disable SELINUX...is this okay? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
sed -i "s/SELINUX=.*/SELINUX=disabled/" /etc/selinux/config

# Hostname
echo ""
echo "Your current hostname..."
cat /etc/hostname

# Prompt user for info
echo ""
read -p "What hostname to use? " host_name

# Set hostname
hostnamectl set-hostname $host_name

# Install dependencies
echo ""
echo "Installing dependencies..."
sudo yum install epel-release -y
#set -xueo pipefail
yum update -y
yum install -y dnf-plugins-core
yum install -y epel-release
yum -v repolist all
yum config-manager --set-enabled PowerTools -y || \
    yum config-manager --set-enabled powertools -y
yum config-manager --set-enabled Devel -y || \
    yum config-manager --set-enabled devel -y
yum update -y
yum install -y \
    --setopt=install_weak_deps=False \
    "@Development Tools" \
    acl \
    attr \
    autoconf \
    avahi-devel \
    bind-utils \
    binutils \
    bison \
    ccache \
    chrpath \
    cups-devel \
    curl \
    dbus-devel \
    docbook-dtds \
    docbook-style-xsl \
    flex \
    gawk \
    gcc \
    gdb \
    git \
    glib2-devel \
    glibc-common \
    glibc-langpack-en \
    glusterfs-api-devel \
    glusterfs-devel \
    gnutls-devel \
    gpgme-devel \
    gzip \
    hostname \
    htop \
    jansson-devel \
    keyutils-libs-devel \
    krb5-devel \
    krb5-server \
    libacl-devel \
    libarchive-devel \
    libattr-devel \
    libblkid-devel \
    libbsd-devel \
    libcap-devel \
    libcephfs-devel \
    libicu-devel \
    libnsl2-devel \
    libpcap-devel \
    libtasn1-devel \
    libtasn1-tools \
    libtirpc-devel \
    libunwind-devel \
    libuuid-devel \
    libxslt \
    lmdb \
    lmdb-devel \
    make \
    mingw64-gcc \
    ncurses-devel \
    openldap-devel \
    pam-devel \
    patch \
    perl \
    perl-Archive-Tar \
    perl-ExtUtils-MakeMaker \
    perl-JSON \
    perl-Parse-Yapp \
    perl-Test-Simple \
    perl-generators \
    perl-interpreter \
    pkgconfig \
    popt-devel \
    procps-ng \
    psmisc \
    python3 \
    python3-cryptography \
    python3-devel \
    python3-dns \
    python3-gpg \
    python3-iso8601 \
    python3-libsemanage \
    python3-markdown \
    python3-policycoreutils \
    python3-pyasn1 \
    python3-setproctitle \
    quota-devel \
    readline-devel \
    redhat-lsb \
    rng-tools \
    rpcgen \
    rpcsvc-proto-devel \
    rsync \
    sed \
    sudo \
    systemd-devel \
    tar \
    tree \
    wget \
    which \
    xfsprogs-devel \
    yum-utils \
    zlib-devel

yum clean all

# Get SAMBA, untar, and configure
echo ""
echo "Getting SAMBA and configuring..."
cd /
wget https://download.samba.org/pub/samba/samba-latest.tar.gz
tar -zxvf samba-latest.tar.gz
cd samba-*/
./configure

# Compile SAMBA and install it
make
make install

# Provision the DC
echo "Lets provision the domain controller..."
echo "Be prepared with your domain information..."
/usr/local/samba/bin/samba-tool domain provision --use-rfc2307 --interactive

# Write the SAMBA config file
echo "Writing SAMBA config..."
cat > /etc/systemd/system/samba.service << EOF
	[Unit] 
	Description= Samba 4 Active Directory 
	After=syslog.target 
	After=network.target 

	[Service] 
	Type=forking 
	PIDFile=/usr/local/samba/var/run/samba.pid 
	ExecStart=/usr/local/samba/sbin/samba 

	[Install] 
	WantedBy=multi-user.target
EOF

# Did it write to samba.service?
echo ""
echo "Check the SAMBA service config..."
cat /etc/systemd/system/samba.service
read -p "How's everything look...Good? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Reload everything and setup
echo ""
echo "Reloading daemon, enabling SAMBA, and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable samba
sudo systemctl start samba
echo "Don't worry if SAMBA won't start it's because you need to reboot to disable SELINUX."

# Add firewall rules
echo ""
echo "Adding Firewall Rules..."
firewall-cmd --add-service={dns,ldap,ldaps,kerberos}
firewall-cmd --add-port={389/udp,135/tcp,135/udp,138/udp,138/tcp,137/tcp,137/udp,139/udp,139/tcp,445/tcp,445/udp,3268/udp,3268/tcp,3269/tcp,3269/udp,49152/tcp}

# Reboot the system
echo ""
echo "Need to reboot now"
read -p "Is that okay? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
reboot now