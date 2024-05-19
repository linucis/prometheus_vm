# Prometheus and Thanos Setup

This repository contains scripts to set up Prometheus and Thanos across three virtual machines (VMs) with secure TLS communication.

## VM 1: Prometheus and Thanos Sidecar

### Prerequisites
- Bash shell
- sudo privileges

### Steps
1. Copy the `certificate.sh` script to VM 1 and run it to generate TLS certificates:
    ```bash
    ./certificate.sh
    ```

2. Copy the `setup_prometheus_thanos_vm1.sh` script to VM 1 and run it:
    ```bash
    ./setup_prometheus_thanos_vm1.sh
    ```

## VM 2: Prometheus and Thanos Sidecar

### Prerequisites
- Bash shell
- sudo privileges

### Steps
1. Copy the TLS certificates generated in VM 1 to VM 2.
2. Copy the `setup_prometheus_thanos_vm2.sh` script to VM 2 and run it:
    ```bash
    ./setup_prometheus_thanos_vm2.sh
    ```

## VM 3: Thanos Store, Thanos Querier, and NGINX

### Prerequisites
- Bash shell
- sudo privileges

### Steps
1. Copy the TLS certificates generated in VM 1 to VM 3.
2. Copy the `setup_thanos_nginx_vm3.sh` script to VM 3 and run it:
    ```bash
    ./setup_thanos_nginx_vm3.sh
    ```

## Note
- Replace `<PROMETHEUS1_VM_IP>` and `<PROMETHEUS2_VM_IP>` with the actual IP addresses of VM 1 and VM 2 in the scripts.
- Replace `<username>` and `<password>` in the `setup_thanos_nginx_vm3.sh` script with the desired credentials for basic authentication.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
