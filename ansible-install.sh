#!/bin/bash


# Check if executed with sudo privileges
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run with sudo privileges. Execute it as follows: sudo ./INSTALL.sh" 1>&2
   exit 1
fi

# External file reference
CONFIG_FILE="./group_vars/all/variables.yaml"

# Variables from an external file
#USER=$(/usr/local/bin/yq e '.USER' $CONFIG_FILE)
#HOST_IP=$(/usr/local/bin/yq e '.CONTROL_NODE_IP' $CONFIG_FILE)
#CON_IP=$(/usr/local/bin/yq e '.MASTER_NODE_IP' $CONFIG_FILE)
#WORKERS_IP=$(/usr/local/bin/yq e '.WORKER_NODE_IP' $CONFIG_FILE)
DIR_PATH=$(/usr/local/bin/yq e '.LOCAL_PATH.BASE' $CONFIG_FILE)

# Function to retrieve IP address
get_ips_by_role() {
  local role=$1
  # Use yq to retrieve IP addresses for a specific role
  yq eval ".ALL_Servers[] | select(.roles[] == \"$role\") | .ip" $CONFIG_FILE
}

# Variables as IP addresses by role
control_ips=$(get_ips_by_role "control")
control_plane_ips=$(get_ips_by_role "control-plane")
worker_ips=$(get_ips_by_role "worker")

# Function to convert to a array
convert_to_array() {
  local ips=$1
  # Function to convert by removing spaces and replacing newline characters with spaces, then transforming into a shell array
  ips="${ips//$'\n'/ }"
  echo "$ips"
}
# Convert IP addresses for each role into a shell array
control_ip_array=($(convert_to_array "$control_ips"))
control_plane_ip_array=($(convert_to_array "$control_plane_ips"))
worker_ip_array=($(convert_to_array "$worker_ips"))

# Function to retrieve names
get_names_by_role() {
  local role=$1
  # Use yq to retrieve name values for a specific role
  yq eval ".ALL_Servers[] | select(.roles[] == \"$role\") | .name" $CONFIG_FILE
}

# Retrieve name values by role
control_names=$(get_names_by_role "control")
control_plane_names=$(get_names_by_role "control-plane")
worker_names=$(get_names_by_role "worker")

# Function to convert to a shell array
convert_to_array() {
  local names=$1
  # Function to convert by removing spaces and replacing newline characters with spaces, then transforming into a shell array
  names="${names//$'\n'/ }"
  echo "$names"
}

# Convert name values by role into a shell array, replacing newline characters with spaces
control_name_array=($(convert_to_array "$control_names"))
control_plane_name_array=($(convert_to_array "$control_plane_names"))
worker_name_array=($(convert_to_array "$worker_names"))


mkdir -p "$DIR_PATH"/haproxy/
# HAProxy configuration file path
cat <<EOL > "$DIR_PATH"/haproxy/istio-haproxy.cfg
global
    daemon
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
frontend http-in-80
    mode tcp
    bind *:80
    default_backend k8s-masters-80

frontend https-in-443
    mode tcp
    bind *:443
    default_backend k8s-masters-443

frontend https-in-6443
    mode tcp
    bind *:6443
    default_backend k8s-masters-6443

frontend https-in-k8s-join-9345
    mode tcp
    bind *:9345
    default_backend rke2-join-masters-9345


backend k8s-masters-80
    mode tcp
    balance roundrobin
    option tcp-check
    option tcplog
EOL


# Add backend servers for port 80
n=0
for IP in "${control_plane_ip_array[@]}"; do
  echo "    server ${control_plane_name_array[n]} $IP:32080 check" >> "$DIR_PATH"/haproxy/istio-haproxy.cfg
  ((n+=1))
done

cat <<EOL >> "$DIR_PATH"/haproxy/istio-haproxy.cfg

backend k8s-masters-443
    mode tcp
    balance roundrobin
    option tcp-check
    option tcplog
EOL

# Add backend servers for port 443
n=0
for IP in "${control_plane_ip_array[@]}"; do
  echo "    server ${control_plane_name_array[n]} $IP:32443 check" >> "$DIR_PATH"/haproxy/istio-haproxy.cfg
  ((n+=1))
done


cat <<EOL >> "$DIR_PATH"/haproxy/istio-haproxy.cfg

backend k8s-masters-6443
    mode tcp
    balance roundrobin
    option tcp-check
    option tcplog

    #server rke2-master-node01 10.71.163.70:6443 check
    server ${control_plane_name_array[0]} ${control_plane_ip_array[0]}:6443 check

backend rke2-join-masters-9345
    mode tcp
    balance roundrobin
    option tcp-check
    option tcplog

    #server rke2-master-node01 10.71.163.70:9345 check
    server ${control_plane_name_array[0]} ${control_plane_ip_array[0]}:9345 check

frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
EOL
cp "$DIR_PATH"/haproxy/istio-haproxy.cfg "$DIR_PATH"/haproxy/haproxy.cfg
sed -i 's/32080/80/g' "$DIR_PATH"/haproxy/haproxy.cfg
sed -i 's/32443/443/g' "$DIR_PATH"/haproxy/haproxy.cfg
cp "$DIR_PATH"/haproxy/haproxy.cfg "$DIR_PATH"/haproxy/ingress-haproxy.cfg


# Install Ansible packages
ANSIBLE_PACKAGES=("sshpass-1.09-4.el8.x86_64" "python3.11-pip-wheel-22.3.1-4.el8_9.1.noarch.rpm" \
"python3.11-pip-wheel-22.3.1-4.el8.noarch" "python3-jmespath-0.9.0-11.el8.noarch" \
"mpdecimal-2.5.1-3.el8.x86_64" "python3.11-libs-3.11.5-1.el8_9.x86_64" \
"python3.11-3.11.5-1.el8_9.x86_64" "python3.11-ply-3.11-1.el8.noarch" \
"python3.11-pycparser-2.20-1.el8.noarch" "python3.11-cffi-1.15.1-1.el8.x86_64" \
"python3.11-cryptography-37.0.2-5.el8.x86_64" "python3.11-pyyaml-6.0-1.el8.x86_64" \
"git-core-2.39.3-1.el8_8.x86_64" "ansible-core-2.15.3-1.el8.x86_64" "ansible-8.3.0-1.el8.noarch")

for PACKAGE in "${ANSIBLE_PACKAGES[@]}"; do
  rpm -Uvh "$DIR_PATH/packages/ansible/${PACKAGE}.rpm"
done

# Initial edit: Update the /etc/hosts file
echo -e "127.0.0.1       localhost\n$HOST_IP ${control_name_array[0]}" > /etc/hosts

# 기본 Ansible 인벤토리 파일 초기화
cat <<EOL > /etc/ansible/hosts
all:
  children:
    control:
      hosts:
        rke2-control-node01:
    k8s-cluster:
      children:
        masters:
          children:
            master-init:
EOL

# write wording as master-init to hosts to ansible hosts
if [[ "${#control_plane_ip_array[@]}" == "1" ]]; then
  echo -e "              hosts:\n                ${control_plane_name_array[0]}:" >> /etc/ansible/hosts
else
  echo -e "              hosts:" >> /etc/ansible/hosts
  echo -e "                rke2-master-node01:" >> /etc/ansible/hosts
fi

#
#
## masters-connect 섹션 추가 (IP가 3개일 경우에만 포함)
#if [[ "${#control_plane_ip_array[@]}" == "3" ]]; then
#  echo -e "            masters-connect:\n              hosts:\n                ${control_plane_name_array[1]}:\n                ${control_plane_name_array[2]}:" >> /etc/ansible/hosts
#fi
#

# masters-connect 섹션 추가 (IP가 3개 이상일 경우에만 포함)
if [[ "${#control_plane_ip_array[@]}" -ge 3 ]]; then
  echo "            masters-connect:" >> /etc/ansible/hosts
  echo "              hosts:" >> /etc/ansible/hosts
  for i in $(seq 1 $((${#control_plane_name_array[@]} - 1))); do
    echo "                ${control_plane_name_array[$i]}:" >> /etc/ansible/hosts
  done
fi


# 기본 인벤토리 파일 계속 작성
cat <<EOL >> /etc/ansible/hosts
        workers:
          children:
            workers-group1:
              hosts:
EOL

# 입력된 IP 주소를 /etc/hosts에 추가
n=0
for IP in "${control_plane_ip_array[@]}"; do
  echo -e "$IP ${control_plane_name_array[n]}" >> /etc/hosts
  ((n+=1))
done

n=0
for IP in "${worker_ip_array[@]}";
  do echo -e "$IP ${worker_name_array[n]}" >> /etc/hosts;
  echo -e "                ${worker_name_array[n]}:" >> /etc/ansible/hosts;
  ((n+=1))
done

# playbooks USER 의 설정
sed -i "s/remote_user: \"ssm-user\"/remote_user: \"$USER\"/g" "playbook.yaml"





