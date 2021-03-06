install
url --url="http://data01/centos/7/os/x86_64/"
text
keyboard es
lang en_US.UTF-8
eula --agreed
network --bootproto=dhcp --device=bootif --vlanid=101 --onboot=on --activate
rootpw password
timezone Europe/Madrid --isUtc
services --disabled auditd,avahi-daemon,NetworkManager,postfix,microcode,tuned
services --enabled network,sshd
selinux --disabled
firewall --disabled
repo --name="CentOS" --baseurl=http://data01/centos/7/os/x86_64/
repo --name="Updates" --baseurl=http://data01/centos/7/updates/
repo --name="Extras" --baseurl=http://data01/centos/7/extras/
repo --name="EPEL" --baseurl=http://data01/centos/7/epel/
repo --name="Booddies" --baseurl=http://data01/booddies/
repo --name="Puppet-products" --baseurl=http://data01/puppet/puppetlabs-products/
repo --name="Puppet-deps" --baseurl=http://data01/puppet/puppetlabs-deps/
bootloader --location=mbr
zerombr
clearpart --drives=sda --all --initlabel
ignoredisk --only-use=sda
part swap --asprimary --fstype="swap" --size=8192 --ondisk=sda
part /boot --fstype xfs --size=200 --ondisk=sda
part / --fstype xfs --size=1024 --grow --ondisk=sda
reboot

%packages --nobase --excludedocs
@Core
bridge-utils
rubygem-r10k
puppet
git
-*NetworkManager*
-*firmware*
-*firewalld*
%end

%post --nochroot --log=/mnt/sysimage/root/ks-post-nochroot.log
rm -f /mnt/sysimage/etc/yum.repos.d/* /tmp/yum.repos.d/anaconda.repo
cp /tmp/yum.repos.d/* /mnt/sysimage/etc/yum.repos.d/
%end

%post --log=/root/ks-post-chroot.log
rpm --import http://data01/centos/7/os/x86_64/RPM-GPG-KEY-CentOS-7
rpm --import http://data01/centos/7/epel/RPM-GPG-KEY-EPEL-7
rpm --import http://data01/puppet/RPM-GPG-KEY-puppetlabs
rpm --import http://data01/booddies/RPM-GPG-KEY-booddies

cat << EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-em1
DEVICE=em1
NAME=em1
TYPE=Ethernet
ONBOOT=yes
HWADDR=$(cat /sys/class/net/em1/address)
EOF

VLAN=$(basename /etc/sysconfig/network-scripts/ifcfg-em1.* | awk -F . '{print $2}')

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-em1.${VLAN}
DEVICE=em1.${VLAN}
NAME=em1.${VLAN}
TYPE=Vlan
VLAN=yes
ONBOOT=yes
HWADDR=$(cat /sys/class/net/em1/address)
PHYSDEV=em1
BRIDGE=core0
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-core0
DEVICE=core0
NAME=core0
TYPE=Bridge
ONBOOT=yes
STP=no
DELAY=0
BOOTPROTO=dhcp
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
IPV6INIT=no
MACADDR=$(cat /sys/class/net/em1/address)
EOF

mkdir -p /etc/puppetlabs/r10k
cat << EOF > /etc/puppetlabs/r10k/r10k.yaml
cachedir: /var/cache/r10k
sources:
 puppet:
  remote: 'http://gito01/cgit/r10k-kvm'
  basedir: /etc/puppet/environments
EOF

cat << EOF > /usr/local/sbin/pupply
#!/bin/bash
r10k deploy environment -p
puppet apply /etc/puppet/environments/production/manifests/site.pp
EOF

chmod a+x /usr/local/sbin/pupply
rm -rf /etc/puppet
git clone http://gito01/cgit/config-puppet /etc/puppet
mkdir /etc/puppet/environments
/usr/local/bin/r10k deploy environment -p
%end
