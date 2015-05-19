#!/bin/bash -xe

#sleep 6000m;

date "+%Y-%m-%d %H:%M:%S"
sysctl -w net.ipv6.conf.all.accept_ra=0
sysctl -w net.ipv6.conf.default.accept_ra=0
ip -6 a flush dev eth0
apt-get update
apt-get -y --force-yes install software-properties-common jq curl

add-apt-repository --yes ppa:juju/stable
apt-get -y --force-yes update
apt-get -y --force-yes install juju-core sudo #git-core #lxc #aufs-tools
useradd -G sudo -s /bin/bash -m -d /home/ubuntu ubuntu
mkdir -p /root/.ssh
test -f /root/.ssh/juju || ssh-keygen -t rsa -b 4096 -f /root/.ssh/juju -N ''
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-cloud-init-users"
#lxc-info -n trusty-base || lxc-create -t ubuntu-cloud -n trusty-base -- -r trusty -S /root/.ssh/juju.pub

#lxc-info -n juju || lxc-clone -s -B aufs trusty-base juju
#lxc-info -n mysql || lxc-clone -s -B aufs trusty-base mysql
#lxc-info -n wordpress || lxc-clone -s -B aufs trusty-base wordpress

#for d in juju; do # mysql wordpress; do
#  lxc-start -d -n $d;
#done

#for d in juju; do # mysql wordpress; do
#  while (true) ; do
#    if [ "$(lxc-info -n $d -i | awk '{print $2}')" != "" ]; then
#        break
#    fi
#   sleep 10s;
# done
#done

#delay=10

#for d in juju; do # mysql wordpress; do
#    lxc-attach -n $d -- /usr/bin/ssh-keygen -A
#    lxc-attach -n $d -- /usr/sbin/service ssh restart
#    lxc-attach -n $d -- mkdir -p /home/ubuntu/.ssh/
#    cat /root/.ssh/juju.pub > /var/lib/lxc/$d/delta0/home/ubuntu/.ssh/authorized_keys
#    grep -q "lxc.start.auto = 1" /var/lib/lxc/$d/config || echo "lxc.start.auto = 1" >> /var/lib/lxc/$d/config
#    grep -q "lxc.start.delay = $delay" /var/lib/lxc/$d/config || echo "lxc.start.delay = $delay" >> /var/lib/lxc/$d/config
#    delay=$((delay+10))
#done

mkdir -p /home/ubuntu/.ssh/
cat /root/.ssh/juju.pub >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu /home/ubuntu

juju generate-config
juju switch manual

#JUJU_IP=$(lxc-info -n juju -i | awk '{print $2}')
#WP_IP=$(lxc-info -n wordpress -i | awk '{print $2}')
#MYSQL_IP=$(lxc-info -n mysql -i | awk '{print $2}')

cat <<_EOF_ > /root/.juju/environments.yaml
default: manual

lxc-clone: true
lxc-clone-aufs: true

environments:
  manual:
    type: manual
    bootstrap-host: 127.0.0.1
    lxc-clone: true
    lxc-clone-aufs: true
  local:
    type: local
    default-series: trusty
    lxc-clone: true
    lxc-clone-aufs: true
_EOF_

mkdir -p /root/.juju/ssh/
cp /root/.ssh/juju /root/.juju/ssh/juju_id_rsa
cp /root/.ssh/juju.pub /root/.juju/ssh/juju_id_rsa.pub

juju bootstrap --debug

#juju add-machine ssh:ubuntu@127.0.0.1
#juju add-machine ssh:ubuntu@10.0.3.1 #1
#juju add-machine ssh:ubuntu@${WP_IP} #2
#juju add-machine ssh:ubuntu@${MYSQL_IP} #3

wget -c http://bb.selfip.ru/charms.tar.gz -O /root/charms.tar.gz
tar -C /root -zxf /root/charms.tar.gz
#git clone https://github.com/vtolstov/charms.git /root/charms/trusty
#test -d charms/trusty/mysql || git clone -b trusty https://github.com/vtolstov/charm-mysql charms/trusty/mysql
#test -d charms/trusty/wordpress || git clone -b trusty https://github.com/vtolstov/charm-wordpress charms/trusty/wordpress
#test -d charms/trusty/haproxy || git clone -b trusty https://github.com/vtolstov/charm-haproxy charms/trusty/haproxy
juju deploy --repository=/root/charms/ local:trusty/mysql --to 0 --debug
#juju set mysql dataset-size=50%
#juju set mysql query-cache-type=ON
#juju set mysql query-cache-size=-1
juju deploy --repository=/root/charms/ local:trusty/wordpress --to 0 --debug
juju add-relation wordpress mysql --debug

juju deploy --repository=/root/charms/ local:trusty/nginx --to 0 --debug
juju add-relation wordpress nginx --debug

juju expose wordpress --debug

#juju deploy --repository=charms/ local:trusty/haproxy --to 1
#juju add-relation haproxy wordpress

for s in mysql wordpress nginx; do
    while true; do
        juju status $s/0 --format=json | jq ".services.$s.units" | grep -q '"agent-state": "started"' && break
        echo "waiting 5s"
        sleep 5s
    done
done

while true; do
    curl -L -s http://127.0.0.1 2>&1 >/dev/null && break
    echo "waiting 5s"
    sleep 5s
done

date "+%Y-%m-%d %H:%M:%S"
