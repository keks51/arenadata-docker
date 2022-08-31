FROM centos/systemd

# Install packages
RUN yum -y install \
    telnet \
    bind-utils \
    nc \
    vim \
    iproute \
    libselinux-utils \
    openssh-server \
    openssh-clients \
    sudo \
    nano \
    epel-release \
    openssl \
    cronie \
    certmonger; \
    systemctl enable sshd.service

# Enable root and pos accounts
RUN echo 'root:root' | chpasswd
RUN adduser pos && \
	echo 'pos:pos' | chpasswd && \
	usermod -aG wheel pos

# Configure SSHD
RUN mkdir -p /var/run/sshd ; chmod -rx /var/run/sshd
# http://stackoverflow.com/questions/2419412/ssh-connection-stop-at-debug1-ssh2-msg-kexinit-sent
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
# Bad security, add a user and sudo instead!
RUN sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
# http://stackoverflow.com/questions/18173889/cannot-access-centos-sshd-on-docker
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config

# Deploy ssh keys
RUN mkdir /root/.ssh/ && \
	echo "ssh-rsa AAAAB3Nz4........l9Ns5p989oHLcSGJ" > ~/.ssh/authorized_keys && \
	chmod 700 ~/.ssh && \
	chmod 600 ~/.ssh/authorized_keys

RUN mkdir /home/pos/.ssh/ && \
	echo "ssh-rsa AAAAB3NzaC........9Ns5p989oHLcSGJ" > /home/pos/.ssh/authorized_keys && \
	chmod 700 /home/pos/.ssh && \
	chmod 600 /home/pos/.ssh/authorized_keys && \
	chown -R pos:pos /home/pos/.ssh/

# Configure pos
RUN bash -c 'echo "pos ALL=(ALL:ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)'

CMD ["/usr/sbin/init"]

# docker build -t keks51-centos7 -f Dockerfile .