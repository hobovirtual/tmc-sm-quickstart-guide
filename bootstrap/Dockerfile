FROM ubuntu
WORKDIR /work
COPY harbor.crt /etc/ssl/certs/

# install requirements
RUN apt-get update
RUN apt-get install -y ca-certificates curl gpg libdigest-sha-perl software-properties-common

# install kubectl
RUN curl -k -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update
RUN apt-get install -y kubectl

# install carvel tools
RUN curl -k -s -L https://github.com/carvel-dev/imgpkg/releases/download/v0.37.1/imgpkg-linux-amd64 > /tmp/imgpkg && mv /tmp/imgpkg /usr/local/bin/imgpkg && chmod +x /usr/local/bin/imgpkg
RUN curl -k -s -L https://github.com/carvel-dev/ytt/releases/download/v0.45.3/ytt-linux-amd64 > /tmp/ytt && mv /tmp/ytt /usr/local/bin/ytt && chmod +x /usr/local/bin/ytt

# install yq
RUN add-apt-repository ppa:rmescandon/yq && apt update && apt install yq -y

# scripts
ENTRYPOINT [ "/work/scripts/tanzumc-sm.sh" ]
CMD [ "help" ]
