FROM ghcr.io/ksiig/utility-images:ansible-latest

# Setup vscoder user
RUN useradd -m -u 1000 vscode && \
    usermod -aG sudo vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/vscode

# Setup locale
RUN apt update && apt install -y locales && \
    locale-gen en_US.UTF-8