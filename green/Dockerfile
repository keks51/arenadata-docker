FROM centos/systemd

# Install packages
RUN yum -y install \
    telnet \
    bind-utils \
    nc \
    vim \
    sudo \
    iproute \
    openssh-server \
    openssh-clients \
    epel-release \
    openssl \
    git \
    systemctl enable sshd.service

# Enable root and gpadmin accounts
RUN echo 'root:root' | chpasswd
RUN groupadd gpadmin && \
    adduser gpadmin -r -m -g gpadmin && \
	echo 'gpadmin:gpadmin' | chpasswd && \
	usermod -aG wheel gpadmin

# Configure SSHD
RUN mkdir -p /var/run/sshd ; chmod -rx /var/run/sshd
# http://stackoverflow.com/questions/2419412/ssh-connection-stop-at-debug1-ssh2-msg-kexinit-sent
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
# Bad security, add a user and sudo instead!
RUN sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
# http://stackoverflow.com/questions/18173889/cannot-access-centos-sshd-on-docker
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config

#USER gpadmin
COPY ./conf/.ssh /home/gpadmin/.ssh
RUN ls -l /home/gpadmin/
RUN chmod 700 /home/gpadmin/.ssh && \
	chmod 600 /home/gpadmin/.ssh/authorized_keys && \
	chown -R gpadmin:gpadmin /home/gpadmin/.ssh/

USER root
COPY ./conf/sysctl.conf /etc/sysctl.conf
COPY ./conf/limits.conf /etc/security/limits.conf
COPY ./conf/20-nproc.conf /etc/security/limits.d/20-nproc.conf

RUN chmod +x /etc/rc.d/rc.local

COPY ./conf/logind.conf /etc/systemd/logind.conf


RUN bash -c 'echo "%wheel ALL=(ALL)      NOPASSWD: ALL" | (EDITOR="tee -a" visudo)'
RUN bash -c 'echo "gpadmin ALL=(ALL:ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)'

COPY ./open-source-greenplum-db-6.21.2-rhel7-x86_64.rpm /home/gpadmin/
RUN cd /home/gpadmin/ && \
    yum install -y open-source-greenplum-db-6.21.2-rhel7-x86_64.rpm

# for pxf
RUN yum -y install \
    unzip \
    maven \
    go \
    libcurl-devel


RUN chown -R gpadmin:gpadmin /usr/local/greenplum* && \
    chgrp -R gpadmin /usr/local/greenplum*

RUN mkdir -p /data/master && \
    chown -R gpadmin:gpadmin /data/master && \
    mkdir /home/gpadmin/gpconfigs/

COPY ./conf/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config
COPY ./conf/init_ssh.sh /home/gpadmin/init_ssh.sh
COPY ./conf/start_db.sh /home/gpadmin/start_db.sh
COPY ./conf/override_conf.sh /home/gpadmin/override_conf.sh
COPY ./conf/init_script.sh /init_script.sh
COPY ./conf/init_script.service  /lib/systemd/system/init_script.service

ENV JAVA_HOME /usr/lib/jvm/java-1.8.0-openjdk
ENV GOPATH /usr/lib/golang/go
ENV GPHOME /usr/local/greenplum-db-6.21.2
ENV PXF_HOME /usr/local/pxf
# required for pxf installation
ENV JAVA_TOOL_OPTIONS -Dfile.encoding=UTF8 -Dskip.tests=true


RUN touch /home/gpadmin/gpconfigs/hostfile_gpinitsystem && \
    chown -R gpadmin:gpadmin /home/gpadmin/ && \
    source /usr/local/greenplum-db-6.21.2/greenplum_path.sh && \
    chmod +x /home/gpadmin/init_ssh.sh && \
    chmod +x /home/gpadmin/start_db.sh && \
    chmod +x /home/gpadmin/override_conf.sh && \
    chmod +x /init_script.sh && \
    echo 'source /usr/local/greenplum-db-6.21.2/greenplum_path.sh' >> /home/gpadmin/.bashrc && \
    echo 'export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk' >> /home/gpadmin/.bashrc \
    systemctl enable init_script.service

RUN mkdir -p /data/primary && \
    mkdir -p /data/mirror && \
    mkdir /root/pxf_workspace/ && \
    cd /root/pxf_workspace/ && \
    git clone https://github.com/greenplum-db/pxf.git && \
    chown -R gpadmin:gpadmin /data/*




#CMD ["/usr/sbin/init","systemctl start sshd", "systemctl start crond", "systemctl restart systemd-logind", "sysctl -p", "su gpadmin -s /home/gpadmin/init_ssh.sh"]
#CMD ["/usr/sbin/init && systemctl start sshd && systemctl start crond && systemctl restart systemd-logind && sysctl -p && su gpadmin -s /home/gpadmin/init_ssh.sh"]
ENTRYPOINT ["/usr/sbin/init"]

# docker build -t keks51-green -f Dockerfile .
# docker compose stop && docker compose rm -f && docker build -t keks51-green -f Dockerfile .

# make -C /root/pxf_workspace/pxf install
# export GOPATH=/usr/lib/golang/go
# export GPHOME=/usr/local/greenplum-db-6.21.2
# export PXF_HOME=/usr/local/pxf
# source /usr/local/greenplum-db-6.21.2/greenplum_path.sh
# export JAVA_TOOL_OPTIONS="-DskipTests=true -Dfile.encoding=UTF8"
# cd /usr/lib/python2.7/