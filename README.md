# ssh-dev

This is a docker dev container that exposes SS port (2222).

Image is based on Ubuntu and includes following tools by default:

- SSH server
- VSCode server
- JDK (Java Development Kit)
- Maven
- Gradle
- Rust
- C/C++
- Python
- uv
- Node.js
- npm
- git
- curl
- wget
- jq (for JSON parsing in shell scripts/terminal)
- zsh (as default shell)
- oh-my-zsh (with plugins for git, zsh-autosuggestions, zsh-syntax-highlighting)
- tmux (terminal multiplexer)
- vim (text editor)
- nano (for who can't escape vim)
- htop (interactive process viewer)

## Usage

1. Build the Docker image:

   ```bash
   docker build -t ssh-dev .
   ```

   or pull from ghcr.io:

   ```bash
    docker pull ghcr.io/ensaremirerol/ssh-dev:latest
   ```

2. Set up the environment variables in a `.env` file. In most cases, you can
   just set `SSH_USER_PUBKEY` variable to your public SSH key. For example:

   ```bash
    SSH_USER_PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3..."
    HTTP_PROXY="" # Optional: Set HTTP proxy if needed
    HTTPS_PROXY="" # Optional: Set HTTPS proxy if needed
    NO_PROXY="" # Optional: Set no proxy if needed ex: "127.0.0.1,localhost"
   ```

   > **Note**: Password authentication is disabled for security reasons. You
   > must use SSH keys to access the container.

   > **Note**: Some programs may not honor the proxy settings. You may need to
   > set the proxy settings in the program's configuration files.

   > **Note**: Proxy settings are one time use only. If you want to change them,
   > you can do it by editing `~/.zshrc` and
   > `/etc/apt/apt.conf.d/01-vendor-ubuntu` files in the container.

3. Run the Docker container:

   ```bash
   docker run -d -p 2222:2222 --name --env-file .env ssh-dev-container ssh-dev
   ```

   alternatively, you can use `docker-compose` to run the container. Bellow you
   can find a example compose file:

   ```yml
   services:
     ssh-dev:
       image: ghcr.io/ensaremirerol/ssh-dev:latest
       container_name: ssh-dev-container
       ports:
         - '2222:2222'
       env_file: .env
   ```

## Accessing the Container

You can access the container using SSH. For example, if you are using VSCode,
you can add the following configuration to your `~/.ssh/config` file:

```bash
Host ssh-dev
    HostName localhost # If container is running on localhost
    Port 2222
    User dev
    IdentityFile ~/.ssh/id_rsa # Path to your private SSH key
```

Then, you can SSH into the container using:

```bash
ssh ssh-dev
```

## Persistent Storage

By default, the container uses a volume to persist data. There are two volumes
created:

- For the home directory of the user
- `/etc/ssh` directory for SSH server configuration

You can't mount these directories with `-v` option, because they are overridden
by the Dockerfile. If you want to mount a directory, you can do it by mounting
another volume or path to the container. For example, you can mount a directory
to `/home/dev/workspace`:

```bash
docker run -d -p 2222:2222 --name ssh-dev-container \
    -v /path/to/your/workspace:/home/dev/workspace \
    --env-file .env ssh-dev
```

If you need to access these volumes outside of the container, you can use
`docker cp` command. For example, to copy the home directory of the user to your
local machine, you can use:

```bash
docker cp ssh-dev-container:/home/dev /path/to/local/directory
```

or for linux you can directly navigate to the volume directory:

```bash
cd /var/lib/docker/volumes/<volume_id>/_data
```

Replace `<volume_id>` with the actual volume ID. You can find the volume ID by
running the following command:

```bash
docker inspect <container_id/name> --format '{{ .Mounts }}'
```

You can also use `docker volume ls` to list all volumes and find the one you
need.
