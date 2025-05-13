FROM ubuntu:25.04

LABEL maintainer="Ensar Emir EROL <ensar.erol@maastrichtuniversity.nl>,<me@ensaremirerol.com>"

ENV ALLOWED_USERS="AllowUsers dev" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    SSH_PORT="2222" \
    SSH_USER_GID="1001" \
    SSH_USER_UID="1001" \
    SSH_USER="dev" \
    SSH_USER_PUBKEY=""

ARG DEPS="openssh-server sudo curl git vim nano htop wget jq zsh tmux \
    python3 python3-pip python3-venv python3-dev build-essential \
    libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev \
    libjpeg-dev libpq-dev libmysqlclient-dev libldap2-dev libsasl2-dev \
    openjdk-11-jdk maven gradle rustc cargo g++ make nodejs npm tini rsyslog"

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends $DEPS && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Create SSH user and set permissions/groups and add to sudo group
    groupadd -g $SSH_USER_GID $SSH_USER && \
    useradd -m -u $SSH_USER_UID -g $SSH_USER_GID -s /bin/bash $SSH_USER && \
    usermod -aG sudo $SSH_USER && \
    echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/$SSH_USER/.ssh && \
    chown -R $SSH_USER_UID:$SSH_USER_GID /home/$SSH_USER/.ssh && \
    passwd -l $SSH_USER && \
    # Set up ZSH and Oh My Zsh for the SSH user
    chsh -s $(which zsh) $SSH_USER && \
    cd /home/$SSH_USER && \
    sudo -u $SSH_USER sh -c " \
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O && \
    sh install.sh --unattended && \
    rm install.sh && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc" && \
    # Install uv
    sudo -u $SSH_USER sh -c "curl -LsSf https://astral.sh/uv/install.sh | sh"

COPY entrypoint.sh /entrypoint.sh

# Persistent Volume for SSH user home directory
VOLUME "/home/$SSH_USER"

# Persistent Volume for SSH server keys - to avoid generating new keys host keys
VOLUME "/etc/ssh"

EXPOSE $SSH_PORT

ENTRYPOINT [ "tini", "--", "/entrypoint.sh" ]

RUN mkdir -p /run/sshd && chmod 0755 /run/sshd

CMD [ "/usr/sbin/sshd", "-D", "-e" ]