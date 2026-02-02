ARG DEBIAN_VERSION=bookworm-slim
ARG HELMFILE_VERSION=0.170.1
ARG HELM_VERSION=3.17.0
ARG KUBECTL_VERSION=1.32.1-*
ARG KUBECTX_VERSION=0.9.5


FROM docker.io/debian:${DEBIAN_VERSION}

WORKDIR /usr/src/app

RUN apt update -q \
 && apt install -y --no-install-recommends \
        ca-certificates \
        curl \
 && apt clean

# Add APT repos
ARG KUBECTL_VERSION

RUN mkdir -p /etc/apt/keyrings \
 && curl -fsSLo /etc/apt/keyrings/kubernetes.asc https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION%.*}/deb/Release.key \
 && echo "deb [signed-by=/etc/apt/keyrings/kubernetes.asc] https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION%.*}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Install APT dependencies
RUN apt update -q \
 && apt install -y --no-install-recommends \
        git \
        kubectl=${KUBECTL_VERSION} \
        zsh \
 && apt clean

# Install kubectx and kubens
ARG TARGETARCH
ARG KUBECTX_VERSION

RUN case "${TARGETARCH}" in \
        amd64) KUBECTX_ARCH='x86_64' ;; \
        *)     KUBECTX_ARCH=${TARGETARCH} ;; \
    esac \
 && curl -fsSL https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_linux_${KUBECTX_ARCH}.tar.gz | tar -xz -C /usr/local/bin \
 && curl -fsSL https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens_v${KUBECTX_VERSION}_linux_${KUBECTX_ARCH}.tar.gz | tar -xz -C /usr/local/bin

# Install Helm
ARG HELM_VERSION

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | DESIRED_VERSION="v${HELM_VERSION}" VERIFY_CHECKSUM=false bash

# Install Helmfile
ARG HELMFILE_VERSION

RUN curl -fsSL https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_${TARGETARCH}.tar.gz | tar -xz -C /usr/local/bin

# Create non-root user
ARG USER_ID=1000
ARG USER_NAME=default

RUN useradd --user-group --create-home --uid ${USER_ID} ${USER_NAME} \
 && usermod -a -G root ${USER_NAME}

USER ${USER_NAME}

ENV PROMPT="%B%F{cyan}%n%f@%m:%F{yellow}%~%f %F{%(?.green.red[%?] )}>%f %b"

RUN touch /home/${USER_NAME}/.zshrc

RUN for DIR in .cache .config .kube; do \
        mkdir ~/${DIR}; \
    done

RUN helmfile init --force
