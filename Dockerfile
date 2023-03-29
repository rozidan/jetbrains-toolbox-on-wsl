FROM fedora:37
ARG USER_NAME="wsl"
RUN dnf update -y && \
    dnf group install -y "Minimal Install" "base-x" && \
    dnf install -y vim nano man man-pages bash-completion glibc-langpack-en xorg-x11-fonts* gnome-terminal gedit fuse zip python python2 python-pip dos2unix git dnf-plugins-core
COPY --chmod=0755 adoptium.repo /etc/yum.repos.d/adoptium.repo
RUN dnf update -y
RUN echo "LANG=en_US.UTF-8" | tee -a /etc/default/locale
RUN dnf clean all
RUN printf "\n[boot]\nsystemd = true\n" | tee -a /etc/wsl.conf
RUN useradd -m -s /bin/bash -G wheel ${USER_NAME} && \
    echo ${USER_NAME} | passwd ${USER_NAME} --stdin
RUN printf "\n[user]\ndefault = ${USER_NAME}\n" | tee -a /etc/wsl.conf
USER "${USER_NAME}"
WORKDIR "/home/${USER_NAME}"
RUN curl -L -o "jetbrains-toolbox.tar.gz" $(curl -s 'https://data.services.jetbrains.com//products/releases?code=TBA&latest=true&type=release' |jq -r '.TBA[0].downloads.linux.link') && \
    mkdir -p ~/.local/bin && \
    tar -C  ~/.local/bin --strip-components=1 --extract --file "jetbrains-toolbox.tar.gz" && \
    rm "jetbrains-toolbox.tar.gz"
RUN echo "cd \$HOME" >> ~/.bashrc && \
    touch ~/.profile
