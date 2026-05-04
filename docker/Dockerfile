# workshop-nexus-intro-sandbox
# Base image for the Introduction to Temporal Nexus workshop (Instruqt sandbox).
#
# Contains:
#   - Python 3.13 (via deadsnakes PPA)
#   - uv (Python package manager)
#   - Eclipse Temurin JDK 21 (LTS)
#   - Maven 3.9
#   - Temporal CLI
#   - The full workshop-nexus-intro-code repo at /opt/workshop
#   - Pre-warmed uv venv at /opt/workshop/.venv
#   - Pre-built Java polyglot worker at /opt/workshop/polyglot/java-legacy/target/
#
# The Temporal dev server runs as a background process inside this same
# container, started by track_scripts/setup-workshop. This matches the
# pattern used by the temporal-versioning-workshop and avoids any reliance
# on undocumented Instruqt config.yml fields.

FROM eclipse-temurin:21-jdk-jammy

# --- System packages ----------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      wget \
      git \
      vim \
      nano \
      less \
      unzip \
      ca-certificates \
      bash-completion \
      software-properties-common \
      jq \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      python3.13 \
      python3.13-venv \
      python3.13-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Maven 3.9 ----------------------------------------------------------------
ARG MAVEN_VERSION=3.9.9
RUN wget -q "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      -O /tmp/maven.tar.gz \
    && tar -xzf /tmp/maven.tar.gz -C /opt \
    && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven \
    && ln -s /opt/maven/bin/mvn /usr/local/bin/mvn \
    && rm /tmp/maven.tar.gz
ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# --- uv (Python package manager) ----------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# --- Temporal CLI -------------------------------------------------------------
ARG TEMPORAL_CLI_VERSION=1.3.0
RUN curl -sSL \
      "https://github.com/temporalio/cli/releases/download/v${TEMPORAL_CLI_VERSION}/temporal_cli_${TEMPORAL_CLI_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin temporal \
    && chmod +x /usr/local/bin/temporal

# --- Bake in the workshop source ---------------------------------------------
# The build context must include the workshop-nexus-intro-code repo at
# ./workshop-nexus-intro-code/ (the GHA workflow checks it out alongside this
# repo, see .github/workflows/build-image.yml).
COPY workshop-nexus-intro-code/ /opt/workshop/

# --- Pre-warm Python venv -----------------------------------------------------
WORKDIR /opt/workshop
RUN uv sync

# --- Pre-build Java polyglot worker ------------------------------------------
WORKDIR /opt/workshop/polyglot/java-legacy
RUN mvn -q -DskipTests package

# --- Shell environment --------------------------------------------------------
RUN echo 'export TEMPORAL_ADDRESS="${TEMPORAL_ADDRESS:-127.0.0.1:7233}"' >> /root/.bashrc \
    && echo 'export WORKSHOP_REPO=/root/workshop' >> /root/.bashrc \
    && echo 'export PATH="/usr/local/bin:${PATH}"' >> /root/.bashrc

WORKDIR /root
CMD ["/bin/bash"]
