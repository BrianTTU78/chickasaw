FROM ubuntu:24.04
ENV TARGETARCH="linux-x64"
# Also can be "linux-arm", "linux-arm64".

RUN apt update && \
  apt install -y --no-install-recommends

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    sudo \
    git \
    unzip \
    jq \
    tar \
    libicu74 \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Copy your internal CA certificate into the container
COPY files/chickasaw-root-ca.crt /usr/local/share/ca-certificates/chickasaw-root-ca.crt

# Update the container's trusted CAs
RUN update-ca-certificates

# INSTALL YQ
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version

# INSTALL MINIO MC
RUN curl -L https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

# INSTALL K8S CLI
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# INSTALL HELM
RUN curl -fsSL https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz -o helm.tar.gz \
    && tar -zxvf helm.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64 helm.tar.gz

# INSTALL AROGCD CLI
RUN curl -sSL -o /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
    && chmod +x /usr/local/bin/argocd

# Docker CLI
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli

# Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform
    
# Terraform Lint
RUN  curl -L https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64.zip -o tflint.zip \
 && unzip tflint.zip \
 && mv tflint /usr/local/bin/ \
 && rm tflint.zip

# Ansible (can usually be installed from Ubuntu repo)
RUN apt-get install -y ansible

# Clean apt Cache
RUN rm -rf /var/lib/apt/lists/*

# Create _work and _update folders
RUN mkdir -p /opt/azure/agent/_work/_update

# Disable Auto Update
ENV AZP_DISABLE_AUTOUPDATE=true

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

WORKDIR /opt/azure/agent/

# copy pre-downloaded agent
COPY files/vsts-agent-linux-x64-3.238.0.tar.gz .

RUN tar zxvf vsts-agent-linux-x64-3.238.0.tar.gz \
 && rm vsts-agent-linux-x64-3.238.0.tar.gz

COPY ./initalize_ado_agent.sh ./
RUN chmod +x ./initalize_ado_agent.sh

# Create agent user and set up home directory
RUN useradd -m -d /home/agent agent
RUN chown -R agent:agent /opt/azure/agent/ /home/agent
RUN chmod -R 775 /opt/azure/agent/

USER agent
# Another option is to run the agent as root.
# ENV AGENT_ALLOW_RUNASROOT="true"

CMD ["/bin/bash"]

ENTRYPOINT [ "./initalize_ado_agent.sh" ]
