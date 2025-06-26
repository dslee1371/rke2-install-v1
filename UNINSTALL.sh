#!/usr/bin/bash

# Kubernetes 리소스 삭제
echo "Deleting all DaemonSets, Deployments, and StatefulSets in all namespaces..."
kubectl delete daemonset --all --all-namespaces
kubectl delete deployments --all --all-namespaces
kubectl delete statefulset --all --all-namespaces

# 60초 대기
echo "Waiting for 120 seconds to allow resources to be deleted..."
sleep 120

# Ansible 플레이북 실행
echo "Running Ansible playbook to uninstall remaining components..."
ansible-playbook uninstall-playbook.yaml

echo "Uninstallation process completed."