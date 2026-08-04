FROM ubuntu:24.04

RUN apt update && apt install -y openssh-server python3 python3-pip sudo curl nginx &&     mkdir -p /var/run/sshd /root/.ssh &&     chmod 700 /root/.ssh &&     echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM6/s4eONHGl3B7suH/zztTr3kT4M03j4jvKTY1Xq0sR gmt@LAPTOP-JKNESN2I" > /root/.ssh/authorized_keys &&     chmod 600 /root/.ssh/authorized_keys &&     echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

EXPOSE 22 80 5000
CMD ["/usr/sbin/sshd", "-D"]
