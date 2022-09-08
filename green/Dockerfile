FROM centos/systemd


# Installing not required packages
RUN yum -y install \
    telnet \
    vim



# Adding root and gpadmin accounts
RUN echo 'root:root' | chpasswd
RUN groupadd gpadmin && \
    adduser gpadmin -r -m -g gpadmin && \
	echo 'gpadmin:gpadmin' | chpasswd && \
	usermod -aG wheel gpadmin



# Installing SSH required packages and configuring
RUN yum -y install \
    openssh-server \
    epel-release \
    openssl \
    sudo
# enable ssh service
RUN  systemctl enable sshd.service
# Configure SSHD
RUN mkdir -p /var/run/sshd ; chmod -rx /var/run/sshd
# http://stackoverflow.com/questions/2419412/ssh-connection-stop-at-debug1-ssh2-msg-kexinit-sent
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
# Bad security, add a user and sudo instead!
RUN sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
# http://stackoverflow.com/questions/18173889/cannot-access-centos-sshd-on-docker
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config
COPY ./conf/.ssh /home/gpadmin/.ssh
RUN ls -l /home/gpadmin/
RUN chmod 700 /home/gpadmin/.ssh && \
	chmod 600 /home/gpadmin/.ssh/authorized_keys && \
	chown -R gpadmin:gpadmin /home/gpadmin/.ssh/



# Installing GREENPLUM required packages and configuring
COPY ./conf/sysctl.conf /etc/sysctl.conf
COPY ./conf/limits.conf /etc/security/limits.conf
COPY ./conf/20-nproc.conf /etc/security/limits.d/20-nproc.conf
RUN chmod +x /etc/rc.d/rc.local
COPY ./conf/logind.conf /etc/systemd/logind.conf
RUN bash -c 'echo "%wheel ALL=(ALL)      NOPASSWD: ALL" | (EDITOR="tee -a" visudo)' && \
    bash -c 'echo "gpadmin ALL=(ALL:ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)' && \
    mkdir /home/gpadmin/gpconfigs && \
    touch /home/gpadmin/gpconfigs/hostfile_segments && \
    mkdir -p /data/master && \
    mkdir /data/primary && \
    mkdir /data/mirror && \
    chown -R gpadmin:gpadmin /data/*
COPY ./conf/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config
COPY ./open-source-greenplum-db-6.21.2-rhel7-x86_64.rpm /home/gpadmin/
RUN cd /home/gpadmin/ && \
    yum install -y open-source-greenplum-db-6.21.2-rhel7-x86_64.rpm
RUN chown -R gpadmin:gpadmin /usr/local/greenplum* && \
    chgrp -R gpadmin /usr/local/greenplum* && \
    echo 'source /usr/local/greenplum-db-6.21.2/greenplum_path.sh' >> /home/gpadmin/.bashrc



# Installing PXF required packages and configuring
RUN yum -y install \
    git \
    unzip \
    maven \
    go \
    libcurl-devel
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0-openjdk
ENV GOPATH /usr/lib/golang/go
ENV GPHOME /usr/local/greenplum-db-6.21.2
ENV PXF_HOME /usr/local/pxf
ENV PXF_BASE /data/pxf-base
ENV JAVA_TOOL_OPTIONS -Dfile.encoding=UTF8
ENV PATH /usr/local/pxf/bin:$PATH
RUN mkdir /root/pxf_workspace && \
    mkdir /data/pxf-base && \
    echo 'export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk' >> /home/gpadmin/.bashrc && \
    echo 'export GOPATH=/usr/lib/golang/go' >> /home/gpadmin/.bashrc && \
    echo 'export GPHOME=/usr/local/greenplum-db-6.21.2' >> /home/gpadmin/.bashrc && \
    echo 'export PXF_HOME=/usr/local/pxf' >> /home/gpadmin/.bashrc && \
    echo 'export PXF_BASE=/data/pxf-base' >> /home/gpadmin/.bashrc && \
    echo 'export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8' >> /home/gpadmin/.bashrc && \
    echo 'export PATH=/usr/local/pxf/bin:$PATH' >> /home/gpadmin/.bashrc
#https://github.com/greenplum-db/pxf
RUN cd /root/pxf_workspace && \
    git clone https://github.com/greenplum-db/pxf.git && \
    cd pxf && \
    git checkout tags/release-6.4.0
RUN source /usr/local/greenplum-db-6.21.2/greenplum_path.sh && \
    make -C /root/pxf_workspace/pxf install



# configuring STARTUP script
COPY ./conf/start_db.sh /home/gpadmin/start_db.sh
COPY ./conf/override_conf.sh /home/gpadmin/override_conf.sh
COPY ./conf/init_ssh.sh /home/gpadmin/init_ssh.sh
COPY ./conf/start_pxf.sh /home/gpadmin/start_pxf.sh
COPY ./conf/replace_pg_hba.sh /home/gpadmin/replace_pg_hba.sh
COPY ./conf/init_script.sh /init_script.sh
COPY ./conf/init_script.service  /lib/systemd/system/init_script.service
RUN chmod +x /init_script.sh && \
    chmod +x /home/gpadmin/start_db.sh && \
    chmod +x /home/gpadmin/override_conf.sh && \
    chmod +x /home/gpadmin/start_pxf.sh && \
    chmod +x /home/gpadmin/replace_pg_hba.sh && \
    chmod +x /home/gpadmin/init_ssh.sh && \
    chown -R gpadmin:gpadmin /home/gpadmin && \
    systemctl enable init_script.service



ENTRYPOINT ["/usr/sbin/init"]

# docker build -t keks51-green -f Dockerfile .
# docker compose stop && docker compose rm -f && docker build -t keks51-green -f Dockerfile .
