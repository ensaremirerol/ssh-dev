set -e

SSH_USER_GID=${SSH_USER_GID:-1000}
SSH_USER_UID=${SSH_USER_UID:-1000}
SSH_USER=${SSH_USER:-"dev"}
SSH_USER_PUBKEY=${SSH_USER_PUBKEY:-""}
SSH_USER_HOME="/home/${SSH_USER}"
SSH_PORT=${SSH_PORT:-22}
SSH_AUTHORIZED_KEYS_FILE="${SSH_USER_HOME}/.ssh/authorized_keys"
SSH_CONFIG_FILE="${SSH_USER_HOME}/.ssh/config"
DEBUG=${DEBUG:-"false"}
HTTP_PROXY=${HTTP_PROXY:-""}
HTTPS_PROXY=${HTTPS_PROXY:-""}
NO_PROXY=${NO_PROXY:-""}

# Functions
log () {
    if [ "$DEBUG" = "true" ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
    fi
}

validate_pubkey () {
    local pubkey="$1"
    # If empty, return false
    if [ -z "$pubkey" ]; then
        log "Public key is empty"
        return 1
    fi
    # Check if the public key is valid
    if ! echo "$pubkey" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)'; then
        log "Invalid public key format"
        return 1
    fi
    return 0
}

set_proxies_for_user () {
    # If proxy variables are already set in zshrc, skip
    if grep -q "export http_proxy=" "${SSH_USER_HOME}/.zshrc" || \
       grep -q "export https_proxy=" "${SSH_USER_HOME}/.zshrc" || \
       grep -q "export no_proxy=" "${SSH_USER_HOME}/.zshrc"; then
        log "Proxy variables already set in zshrc, skipping"
        return
    fi

    local user="$1"
    local http_proxy="$2"
    local https_proxy="$3"
    local no_proxy="$4"

    # Check if http_proxy is set
    if [ -n "$http_proxy" ]; then
        log "Setting HTTP proxy for user $user"
        echo "export http_proxy=$http_proxy" >> "${SSH_USER_HOME}/.zshrc"
        echo "export HTTP_PROXY=$http_proxy" >> "${SSH_USER_HOME}/.zshrc"
        # Apt
        echo "Acquire::http::Proxy \"$http_proxy\";" >> /etc/apt/apt.conf.d/01-vendor-ubuntu
    fi

    # Check if https_proxy is set
    if [ -n "$https_proxy" ]; then
        log "Setting HTTPS proxy for user $user"
        echo "export https_proxy=$https_proxy" >> "${SSH_USER_HOME}/.zshrc"
        echo "export HTTPS_PROXY=$https_proxy" >> "${SSH_USER_HOME}/.zshrc"
        # Apt
        echo "Acquire::https::Proxy \"$https_proxy\";" >> /etc/apt/apt.conf.d/01-vendor-ubuntu
    fi
    # Check if no_proxy is set
    if [ -n "$no_proxy" ]; then
        log "Setting NO proxy for user $user"
        echo "export no_proxy=$no_proxy" >> "${SSH_USER_HOME}/.zshrc"
        echo "export NO_PROXY=$no_proxy" >> "${SSH_USER_HOME}/.zshrc"
    fi
}

write_sshd_config () {
    local user="$1"
    local port="$2"
    log "Writing SSHD config"
    mkdir -p /etc/ssh/sshd_config.d
    # Create custom SSHD config
    touch /etc/ssh/sshd_config.d/custom.conf

    # Port
    log Port: $port
    echo "Port $port" >> /etc/ssh/sshd_config.d/custom.conf
    # Disable root login
    log "Disabling root login"
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config.d/custom.conf
    # Login grace time
    log "Setting login grace time to 30 seconds"
    echo "LoginGraceTime 30" >> /etc/ssh/sshd_config.d/custom.conf
    # Disable kerberos
    log "Disabling kerberos"
    echo "KerberosAuthentication no" >> /etc/ssh/sshd_config.d/custom.conf
    # Disable GSSAPI
    log "Disabling GSSAPI"
    echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config.d/custom.conf
    # Disable X11 forwarding
    log "Enabling X11 forwarding"
    echo "X11Forwarding yes" >> /etc/ssh/sshd_config.d/custom.conf
    # Authentication methods
    echo "AuthenticationMethods publickey" >> /etc/ssh/sshd_config.d/custom.conf
    # Allow users to connect
    log "Allowing users to connect"
    echo "AllowUsers $user" >> /etc/ssh/sshd_config.d/custom.conf
    # Log level
    log "Setting log level to VERBOSE"
    echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config.d/custom.conf
    # Syslog facility
    log "Setting syslog facility to AUTH"
    echo "SyslogFacility AUTH" >> /etc/ssh/sshd_config.d/custom.conf

    chmod 600 /etc/ssh/sshd_config.d/custom.conf
    chmod 755 /etc/ssh/sshd_config.d
}

write_authorized_keys () {
    local pubkey="$1"
    log "Writing authorized keys"
    mkdir -p "${SSH_USER_HOME}/.ssh"
    chmod 700 "${SSH_USER_HOME}/.ssh"
    echo "$pubkey" > "$SSH_AUTHORIZED_KEYS_FILE"
    chmod 600 "$SSH_AUTHORIZED_KEYS_FILE"
    chown -R "${SSH_USER}:${SSH_USER}" "${SSH_USER_HOME}/.ssh"
}

if [ "$DEBUG" = "true" ]; then
    log "Debug mode is enabled"
    set -x
fi

# Check validate_pubkey returns 0 then set authorized keys
if validate_pubkey "$SSH_USER_PUBKEY"; then
    log "Public key is valid"
    write_authorized_keys "$SSH_USER_PUBKEY"
else
    log "Public key is invalid, skipping"
fi

write_sshd_config "$SSH_USER" "$SSH_PORT"

set_proxies_for_user "$SSH_USER" "$HTTP_PROXY" "$HTTPS_PROXY" "$NO_PROXY"

exec "$@"