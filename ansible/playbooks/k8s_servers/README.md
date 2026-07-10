# Kubernetes Servers (RKE2) Playbook

Installs [RKE2](https://docs.rke2.io/) server nodes on Rocky Linux or RHEL using the **k8s** role. Supports **local** (Molecule), **dev**, **test**, and **prod** environments.

- **Role:** [roles/k8s](../../roles/k8s/) — RKE2 server only (prereqs, install, config, service, optional firewalld).
- **Inventory:** Define a `kubernetes` group in your inventory; set RKE2 variables in `group_vars/<env>.yml` or `group_vars/all.yml` as needed.

## Environments

| Environment | How to run |
|-------------|------------|
| **Local** | Test with [Molecule](https://ansible.readthedocs.io/projects/molecule/) (no real servers): `cd roles/k8s && molecule test -s default` |
| **Dev** | `ansible-playbook -i inventories/dev/hosts.yml playbooks/k8s_servers/playbook.yml -b` |
| **Test** | `ansible-playbook -i inventories/test/hosts.yml playbooks/k8s_servers/playbook.yml -b` |
| **Prod** | `ansible-playbook -i inventories/prod/hosts.yml playbooks/k8s_servers/playbook.yml -b` |

## RKE2 variables (k8s role)

Variables are defined in **roles/k8s/defaults/main.yml**. Override per environment in group_vars:

- **group_vars/all.yml** — shared defaults
- **group_vars/dev.yml**, **test.yml**, **prod.yml** — per-environment overrides

Common overrides: `rke2_version`, `rke2_channel`, `rke2_config` (e.g. `tls-san`, `write-kubeconfig-mode`), `rke2_configure_firewall`, `rke2_firewall_cni`. See the [k8s role README](../../roles/k8s/README.md) for the full variable table.

## Local testing with Molecule

From the repo root:

```bash
cd roles/k8s && molecule test -s default
```

This spins up a Rocky Linux container, applies the **k8s** role (with `rke2_start_service: true` and `rke2_config: { snapshotter: native }` for container compatibility), and verifies the RKE2 binary, config, and systemd unit. First run can take several minutes due to the RKE2 download.

## Verifying firewall (deployed environments)

When `rke2_configure_firewall` is true, the k8s role opens RKE2 and CNI ports with firewalld. Firewall tasks are skipped in containers (e.g. Molecule), so to confirm firewall configuration run the verify playbook against real deployed hosts.

Use the same inventory and group_vars as deploy (so `rke2_firewall_cni` matches):

```bash
# Dev
ansible-playbook -i inventories/dev/hosts.yml playbooks/k8s_servers/verify_firewall.yml -b

# Test
ansible-playbook -i inventories/test/hosts.yml playbooks/k8s_servers/verify_firewall.yml -b

# Prod
ansible-playbook -i inventories/prod/hosts.yml playbooks/k8s_servers/verify_firewall.yml -b
```

The playbook checks that firewalld is active and enabled, and that all required ports (common RKE2 + CNI-specific) are open.

**Manual checks** on a host (optional):

```bash
ssh your-k8s-host
sudo systemctl is-active firewalld    # expect: active
sudo systemctl is-enabled firewalld   # expect: enabled
sudo firewall-cmd --list-ports        # expect: 6443/tcp 9345/tcp ... (and CNI ports)
sudo firewall-cmd --query-port=6443/tcp && echo "open" || echo "closed"
```

## Server-only

This playbook and the **k8s** role install RKE2 **server** nodes only. To add agent (worker) nodes to an existing cluster, use the **rke2** role (`rke2_install_type: agent`, `rke2_server_url`, `rke2_token`) with a separate playbook or host group.

## Scenarios to be created and tested

| Scenario | Status |
|----------|--------|
| 1. Initial server | Done |
| 2. Adding additional servers | Not done |
| 3. Adding additional agents | Not done |
