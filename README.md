# Hybrid Cloud Bursting Architecture

Automatically scale beyond on-premise capacity with secure AWS bursting during traffic spikes. This production-ready solution combines Terraform for cloud infrastructure and Ansible for configuration management.

 Features

- Auto-Scaling: Burst to AWS when on-prem CPU >70% for 5 minutes
- High Availability: <3s failover with HAProxy + Keepalived VIP
- Secure Connectivity: WireGuard VPN with PSK authentication
- Database Resilience: MySQL Galera multi-master cluster
- Cost Monitoring: Built-in AWS budget alerts

 Architecture Components

On-Premise
- HAProxy: Load balancing with dynamic backend updates
- Keepalived: Virtual IP (192.168.1.200) for failover
- MySQL Galera: Synchronous multi-master replication
- **WireGuard**: Secure tunnel to AWS (UDP 51820)

 AWS Cloud
- Auto Scaling Group: t3.medium spot instances
- VPC Networking: Isolated 10.0.0.0/16 with VPN peering
- CloudWatch Alarms: CPU/Memory monitoring

 Deployment

 Prerequisites
- 2+ Ubuntu 22.04 servers (4vCPU/8GB RAM each)
- AWS account with EC2/VPC permissions
- Terraform 1.5+ and Ansible 8+

 Installation Steps

1. Clone the repository:
```bash
git clone https://github.com/yourrepo/hybrid-cloud-bursting.git
cd hybrid-cloud-bursting
```

2. Initialize Terraform:
```bash
cd terraform
terraform init
```

3. Deploy AWS resources (edit terraform.tfvars first):
```bash
terraform apply -var-file=production.tfvars
```

4. Configure on-premise servers:
```bash
ansible-playbook -i ansible/inventory/on_prem.yml ansible/playbooks/setup.yml
```

 Configuration Files

| File | Purpose |
|------|---------|
| `terraform/modules/autoscaling/main.tf` | AWS scaling policies |
| `ansible/playbooks/haproxy.yml` | Dynamic load balancer config |
| `configs/haproxy/haproxy.cfg` | Load balancing rules |
| `scripts/wg-install.sh` | WireGuard VPN setup |

 Monitoring

Access these dashboards after deployment:

- Grafana: `http://<on-prem-ip>:3000`
  - Default credentials: admin/grafana-admin
- Prometheus: `http://<on-prem-ip>:9090`

Key metrics tracked:
- `haproxy_backend_http_requests_total`
- `mysql_global_status_threads_connected`
- `aws_ec2_cpuutilization_average`

Testing Procedures

 Load Testing
```bash
locust -f load_testing/burst_test.py --users 1000 --spawn-rate 50
```

 Failover Test
```bash
# On primary node:
sudo systemctl stop keepalived
# Verify VIP migrates to backup within 3 seconds
```

 Cost Management

| Resource | Estimated Cost |
|----------|---------------|
| AWS Burst Instances | $0.08/hr (spot) |
| VPN Data Transfer | $0.09/GB |
| Monitoring | $0.30/day |

Set budget alerts in AWS when monthly spend exceeds $500.

 Troubleshooting

Common Issues:

1. VIP Not Failing Over:
   - Check Keepalived logs: `journalctl -u keepalived`
   - Verify ARP tables on network switches

2. Database Split-Brain:
   ```sql
   SHOW STATUS LIKE 'wsrep%';
   # Re-bootstrap cluster if needed
   sudo galera_new_cluster
   ```

3. AWS Instances Not Scaling:
   - Verify CloudWatch alarms exist
   - Check Auto Scaling Group health checks

 License

Apache License 2.0 - See [LICENSE](LICENSE) for full text.
