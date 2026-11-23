# WeatherOps infrastructure

## AWS network

Terraform defines one `10.0.0.0/16` VPC in AWS Israel (Tel Aviv), region
`il-central-1`. Subnet CIDRs and Availability Zones are configurable and
paired by their position in the input lists.

| Availability Zone | Public subnet | Private subnet |
| --- | --- | --- |
| `il-central-1a` | `10.0.1.0/24` | `10.0.11.0/24` |
| `il-central-1b` | `10.0.2.0/24` | `10.0.12.0/24` |

Both public subnets share a route table that sends IPv4 internet traffic
(`0.0.0.0/0`) to the internet gateway. Both private subnets share a route
table that sends the same destination to one NAT gateway with an Elastic IP in
the first public subnet. Private subnets disable automatic public IP
assignment. Sharing one NAT gateway reduces cost and makes internet egress
for both private subnets dependent on the first Availability Zone.

## AWS security

| Security group | Inbound | Outbound |
| --- | --- | --- |
| ALB | TCP 443 from the IPv4 internet | TCP NodePort to the EC2 security group |
| EC2 | TCP NodePort from the ALB security group | TCP 443 for K3s downloads, Docker Hub, Systems Manager, and the weather API. TCP 80 for Ubuntu package mirrors. |

The ALB instance target group, its health checks, and the K3s Service
must use the same `application_node_port` (default `30080`). The EC2 group has
no inbound SSH or Kubernetes API rules. Security groups are stateful, so
replies to allowed connections need no separate rules. EC2 web egress goes
through the NAT gateway and permits any IPv4 destination on the allowed ports.
Security groups cannot filter by hostname or block the Amazon-provided
VPC DNS resolver.

The EC2 instance profile carries a role trusted only by the EC2 service.
Its sole policy attachment is `AmazonSSMManagedInstanceCore`. Session Manager
also requires a running SSM Agent, outbound connectivity to Systems Manager,
and separate IAM authorization for the operator starting the session.

## EC2 and Session Manager

Terraform defines one Ubuntu Server 24.04 LTS x86_64 instance in Private
Subnet A (the first configured Availability Zone, `il-central-1a` by default).
It uses the existing EC2 security group and SSM instance profile, requires
IMDSv2, and has no public IP or SSH key pair. The encrypted 30 GiB gp3 root
volume is deleted when the instance is terminated. The instance type defaults
to `t3.medium`. Choose an x86_64 type available in the subnet's Availability
Zone when overriding `ec2_instance_type`.

The AMI lookup selects the latest official Canonical Ubuntu 24.04 Server
image matching the architecture in the configured region. A newer matching
AMI can cause a future plan to propose replacing the instance. First-boot
user data enables and starts the SSM Agent snap, installing it if absent.

Once the instance exists and registers as an online managed node, use an
authorized AWS CLI profile and the Session Manager plugin. Run this from the
repository root, adjusting the region if you changed `aws_region`.

```sh
aws ssm start-session --region il-central-1 \
  --target "$(terraform -chdir=infrastructure/terraform output -raw ec2_instance_id)"
```

## Application Load Balancer

The internet-facing IPv4 ALB spans both public subnets and uses the existing
ALB security group. It terminates client TLS on port 443 and forwards HTTP
to the EC2 instance's private IP on `application_node_port` (default `30080`).
ALB deletion protection defaults to off for the lab and can be enabled with
`alb_enable_deletion_protection`.

Set `acm_certificate_arn` to an existing, issued ACM certificate in the ALB's
region that covers the application's public hostname. Point that hostname
at the ALB using the `alb_dns_name` output. With the ARN unset, the ALB has
no listeners. Port 80 is never configured as a listener.

The target is unused until the HTTPS listener references the target group.
Once health checks start, the target remains unhealthy until K3s and Traefik
serve HTTP 200 from `/healthcheck` on the NodePort.

## K3s configuration with Ansible

The role runs locally on the Ubuntu 24.04 instance. It loads the `overlay`
and `vxlan` modules, enables IPv4 forwarding, and installs the version pinned
in `ansible/roles/k3s/defaults/main.yml`. Set `k3s_version` there to select a
different K3s release compatible with the bundled Traefik chart. Set
`k3s_node_port` to match Terraform's `application_node_port` if it differs
from `30080`. K3s uses its bundled containerd. The existing EC2 security group
keeps port 6443 private, and the administrative kubeconfig is root-only.

A `HelmChartConfig` keeps the bundled Traefik installation and exposes only
its HTTP entry point through the NodePort. K3s ServiceLB is disabled. An exact
path route serves `/healthcheck` using Traefik's internal ping responder.
The route accepts any Host header, including the private IP and port sent by
the ALB, and works before WeatherOps is deployed. It checks Traefik availability.

### Run the playbook through Systems Manager

After the instance is online in Systems Manager and remote execution is
approved, run the following from the repository root with an AWS CLI identity
authorized to send `AWS-RunShellScript` to this instance and read its result.
The command transfers a compressed copy of the playbook, inventory, and role
inline. The instance needs outbound access to Ubuntu package repositories and
the K3s and container image download endpoints.

```bash
region=il-central-1
instance_id=$(terraform -chdir=infrastructure/terraform output -raw ec2_instance_id)
params_file=$(mktemp)
python3 - "$params_file" <<'PY'
import base64
import json
import subprocess
import sys

archive = subprocess.check_output([
    "tar", "-czf", "-", "-C", "infrastructure/ansible", "site.yml", "inventory", "roles"
])
bundle = base64.b64encode(archive).decode("ascii")
commands = [
    "set -eu",
    'workdir=$(mktemp -d /var/tmp/weatherops-ansible.XXXXXX)',
    'trap \'rm -rf -- "$workdir"\' EXIT',
    'cd "$workdir"',
    f"printf '%s' '{bundle}' | base64 -d > playbook.tar.gz",
    "tar -xzf playbook.tar.gz",
    "if ! command -v ansible-playbook >/dev/null 2>&1; then",
    "  apt-get update",
    "  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ansible-core",
    "fi",
    "ansible-playbook -i inventory/hosts.yml site.yml",
]
with open(sys.argv[1], "w", encoding="utf-8") as output:
    json.dump({"commands": commands}, output)
PY

if [ -n "$instance_id" ] && [ -s "$params_file" ]; then
  command_id=$(aws ssm send-command --region "$region" \
    --instance-ids "$instance_id" --document-name AWS-RunShellScript \
    --parameters "file://$params_file" --query 'Command.CommandId' --output text)
  printf '%s\n' "$command_id"
fi
rm -f -- "$params_file"
```

Use the command ID to check status and retrieve output. If the invocation
is still pending or in progress, check again after it has had time to finish.

```sh
aws ssm get-command-invocation --region "$region" \
  --command-id "$command_id" --instance-id "$instance_id"
```

The playbook checks that K3s is active, the node is Ready, Traefik has rolled
out, and the private IP and NodePort return HTTP 200 for `/healthcheck`.
After the HTTPS listener is configured, verify the ALB's own view with
`aws elbv2 describe-target-health --region "$region" --target-group-arn
"$(terraform -chdir=infrastructure/terraform output -raw alb_target_group_arn)"`.

## Responsibilities

- `terraform/` defines the AWS network, security resources, private EC2
  instance, and public ALB. Administration uses AWS Systems Manager
  Session Manager.
- `ansible/` configures the Ubuntu host, K3s, and Traefik using a local
  playbook delivered by Systems Manager.

Helm will package the WeatherOps application, and Argo CD will manage its
deployment in a later stage.
