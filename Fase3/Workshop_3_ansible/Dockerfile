FROM ubuntu:24.04

RUN apt update && apt install -y openssh-server python3 python3-pip sudo curl nginx &&     mkdir -p /var/run/sshd /root/.ssh &&     chmod 700 /root/.ssh &&     echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEtW1HY6REFqXvS5UQz6HYfQPxXJM0Y/VYw0DlzhLcJe gmt@MSI" > /root/.ssh/authorized_keys &&     chmod 600 /root/.ssh/authorized_keys &&     echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

EXPOSE 22 80 5000
CMD ["/usr/sbin/sshd", "-D"]
