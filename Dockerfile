ARG BASE_IMAGE=harborrmz./apim-mule-repo/rhel95-base

# Default base image can be overridden with --build-arg
FROM ${BASE_IMAGE}

# ------------------------------------------------------------------
# Import necessary packages (assumed available in base image)
# ------------------------------------------------------------------
RUN yum -y install \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    yum install -y \
        nodejs \
        unzip \
        gettext \
        procps \
        openssl \
        curl \
        jq \
        vim-minimal \
        hostname && \
    yum clean all

# ------------------------------------------------------------------
# Set Environment Variables
# ------------------------------------------------------------------
ENV JAVA_HOME=/opt/jre
ENV MULE_HOME=/opt/mule
ENV SCRIPTS_HOME=/opt/scripts
ENV PATH="${PATH}:${JAVA_HOME}/bin"

# ------------------------------------------------------------------
# JAVA and MULE runtime
# ------------------------------------------------------------------
COPY ./README.md \
     ./source/seed.sh \
     ./source/jre*.tar.gz \
     ./source/mule-*.zip \
     /tmp/

RUN cd /tmp && \
    # Check if JRE exists
    if ! ls jre* 1>/dev/null 2>&1; then \
        echo "ERROR: JRE file not found in ./source directory"; \
        echo "Expected file: jre-11-linux-x64.tar.gz or similar"; \
        exit 1; \
    fi && \
    mkdir -p /opt/jre && \
    tar xzf jre*.tar.gz --strip-components=1 --directory /opt/jre && \
    \
    # Check Mule runtime
    if ! ls mule* 1>/dev/null 2>&1; then \
        echo "ERROR: Mule runtime file not found in ./source directory"; \
        echo "Expected file: mule-ee-distribution-standalone-*.zip or *.tar.gz"; \
        exit 1; \
    fi && \
    mkdir -p /tmp/muleunzip && \
    \
    if ls mule*.zip 1>/dev/null 2>&1; then \
        unzip -q mule*.zip -d /tmp/muleunzip; \
    elif ls mule*.tar.gz 1>/dev/null 2>&1; then \
        tar -C /tmp/muleunzip -xzf mule*.tar.gz; \
    else \
        echo "ERROR: No valid Mule runtime file found (expected .zip or .tar.gz)"; \
        exit 1; \
    fi && \
    \
    if ls /tmp/muleunzip/mule* 1>/dev/null 2>&1; then \
        mv /tmp/muleunzip/mule* ${MULE_HOME}; \
    else \
        echo "ERROR: No extracted Mule directory found"; \
        exit 1; \
    fi && \
    mkdir -p ${MULE_HOME}/conf_bkp && \
    cp -rp ${MULE_HOME}/conf ${MULE_HOME}/conf_bkp

# ------------------------------------------------------------------
# License
# (README.md added so build does not fail if license.lic is missing)
# ------------------------------------------------------------------
COPY ./README.md ./source/license.lic ${MULE_HOME}/

# ------------------------------------------------------------------
# Add Apps and Config
# ------------------------------------------------------------------
COPY ./apps/* ${MULE_HOME}/apps/
COPY ./domains/* ${MULE_HOME}/domains/
COPY ./conf/* ${MULE_HOME}/conf/
COPY ./stow/* /opt/stow/

# ------------------------------------------------------------------
# Add Scripts
# ------------------------------------------------------------------
COPY run.sh ${SCRIPTS_HOME}/
COPY registerMule.sh ${SCRIPTS_HOME}/
COPY containerShutdown.sh ${SCRIPTS_HOME}/
COPY apFunctions.sh ${SCRIPTS_HOME}/
COPY appDeploy.sh ${SCRIPTS_HOME}/
COPY enableFIPS.sh ${SCRIPTS_HOME}/
COPY pre-scripts ${SCRIPTS_HOME}/pre-scripts
COPY post-scripts ${SCRIPTS_HOME}/post-scripts

# ------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------
RUN rm -rf /tmp/*

# ------------------------------------------------------------------
# Expose Port
# ------------------------------------------------------------------
ENV PORT 8081
EXPOSE 8081

# ------------------------------------------------------------------
# Set Mule User
# ------------------------------------------------------------------
RUN adduser --system --user-group mule && \
    chown -R mule: ${MULE_HOME} ${SCRIPTS_HOME}

USER mule

# ------------------------------------------------------------------
# Entrypoint
# Must use shell-style CMD to properly trap SIGTERM
# ------------------------------------------------------------------
CMD ["/opt/scripts/run.sh"]
