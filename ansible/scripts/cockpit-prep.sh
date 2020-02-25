#!/bin/bash

(

set -x

RHN_ACCOUNT=THEACCOUNT
RHN_PASSWORD=THEPASSWORD

#preps the first cockpit server
useradd rhel
echo "linux4winPass2020" | passwd rhel --stdin
usermod -aG wheel rhel
echo "rhel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/rhel
chmod 0440 /etc/sudoers.d/rhel

#install enable and open firewall for cockpit
dnf install tcpdump traceroute mtr firewalld cockpit-composer cockpit cockpit-dashboard bash-completion -y

#cockpit update / firewalld fix
dnf update dnf subscription-manager polkit -y

systemctl enable cockpit.socket
systemctl start cockpit.socket
systemctl enable firewalld
systemctl start firewalld
sleep 2
echo "adding cockpit rule to firewalld"
setenforce 0
firewall-cmd --add-service=cockpit
firewall-cmd --add-service=cockpit --permanent
setenforce 1

#prep for lab2
mkdir /mnt/myvol
chmod 0755 /mnt/myvol

#prep for lab 4
dnf install https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/p/python2-html2text-2019.8.11-1.el7.noarch.rpm -y

#prep for lab 5
dnf install realmd oddjob oddjob-mkhomedir sssd adcli samba-common-tools -y

#prep for assign3,4
sed -i  -e 's/PasswordAuthentication no/PasswordAuthentication yes/1' /etc/ssh/sshd_config
systemctl restart sshd

# Set dns=none for NetworkManager
sed -i -e "s/\[main\]/\[main\]\\ndns=none/" /etc/NetworkManager/NetworkManager.conf
systemctl restart NetworkManager

DNSIP=ADIPADDRESS
#sed -i -e "s/# Generated by NetworkManager/nameserver $DNSIP/g" /etc/resolv.conf
sed -i -e "s/nameserver/nameserver $DNSIP\\nnameserver/1" /etc/resolv.conf

#prep for lab 6
sed -i 's/iburst/ibarst/g' /etc/chrony.conf
systemctl restart chronyd  >/dev/null 2>&1

#protect ourselfs from network outages
LOOP=0
while true; do
        ping -c1 subscription.rhn.redhat.com >/dev/null
        if [ "$?" -eq 0 ]; then
                echo "We can reach Red Hat Network"
                break
        else
                LOOP=$(expr $LOOP +1)
                if [ "$LOOP" -eq 120 ]; then
                        echo "We've waited for 2 minutes... exiting."
                        exit 1
                fi
        fi
done

subscription-manager register --username=$RHN_ACCOUNT --password=$RHN_PASSWORD --force --auto-attach
if [ "$?" -ne 0 ]; then
        sleep 5
        subscription-manager register --username=$RHN_ACCOUNT --password=$RHN_PASSWORD --force --auto-attach
        if [ "$?" -ne 0 ]; then
                sleep 5
                subscription-manager register --username=$RHN_ACCOUNT --password=$RHN_PASSWORD --force --auto-attach
                if [ "$?" -eq 0 ]; then
                        rm -f /etc/yum.repos.d/*rhui*
                else
                        echo "I tried 3 times, I'm giving up."
                        exit 1
                fi
        else
                rm -f /etc/yum.repos.d/*rhui*
        fi
else
        rm -f /etc/yum.repos.d/*rhui*
fi

) >/tmp/user-data.log 2>&1
subscription-manager repos --enable ansible-2-for-rhel-8-x86_64-rpms
#comment out in case of debug
rm -rf /var/lib/cloud/instance
rm -f /tmp/user-data.log
