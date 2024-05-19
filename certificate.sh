#!/bin/bash

# Variables
CERT_DIR="/etc/prometheus/certs"
CA_KEY="${CERT_DIR}/ca.key"
CA_CERT="${CERT_DIR}/ca.crt"
DAYS_VALID=3650
SERVERS=("prometheus1" "prometheus2" "thanos-querier" "thanos-store")

# Create directories
mkdir -p ${CERT_DIR}

# Step 1: Create a Certificate Authority (CA)

# Generate the CA private key
openssl genrsa -out ${CA_KEY} 4096

# Generate the CA certificate
openssl req -x509 -new -nodes -key ${CA_KEY} -sha256 -days ${DAYS_VALID} -out ${CA_CERT} -subj "/C=US/ST=California/L=San Francisco/O=YourCompany/OU=IT/CN=yourcompany.com"

# Step 2: Generate and Sign Server Certificates
for server in "${SERVERS[@]}"; do
    SERVER_KEY="${CERT_DIR}/${server}.key"
    SERVER_CSR="${CERT_DIR}/${server}.csr"
    SERVER_CERT="${CERT_DIR}/${server}.crt"
    SERVER_EXT="${CERT_DIR}/${server}.ext"

    # Generate the server private key
    openssl genrsa -out ${SERVER_KEY} 2048

    # Generate a certificate signing request (CSR)
    openssl req -new -key ${SERVER_KEY} -out ${SERVER_CSR} -subj "/C=US/ST=California/L=San Francisco/O=YourCompany/OU=IT/CN=${server}.yourcompany.com"

    # Create a configuration file for the extensions
    cat <<EOF > ${SERVER_EXT}
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${server}.yourcompany.com
IP.1 = 127.0.0.1
EOF

    # Create the server certificate using the CA
    openssl x509 -req -in ${SERVER_CSR} -CA ${CA_CERT} -CAkey ${CA_KEY} -CAcreateserial -out ${SERVER_CERT} -days ${DAYS_VALID} -sha256 -extfile ${SERVER_EXT}
done

echo "Certificates generated and stored in ${CERT_DIR}"
