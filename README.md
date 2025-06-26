## Readme.md

### Requirements

- Compatible with Rocky 8.8 (Not tested on 8.9)

### Running Ansible Playbooks

#### Install

To install everything, run:
```bash
./INSTALL.SH
```

#### Single Cluster Installation

To install a single cluster, run:
```bash
./INSTALL.SH single-cluster
```

### Multi-Cluster Installation

To add nodes, use the following Ansible playbook:
```bash
./INSTALL.SH multi-cluster
```

### Add nodes

To add nodes, use the following Ansible playbook:
```bash
ansible-playbook playbook-addnode.yaml
```

### Clean Install
To uninstall, run:
```bash
./UNINSTALL.SH
```	