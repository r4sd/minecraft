FROM amazoncorretto:17

RUN yum -y install wget \
    screen

WORKDIR /root

RUN mkdir data
# 1.18.1
RUN wget https://launcher.mojang.com/v1/objects/125e5adf40c659fd3bce3e66e67a16bb49ecc1b9/server.jar

COPY eula.txt /root/eula.txt
COPY start.sh /root/start.sh

RUN chmod +x /root/start.sh
RUN yum clean all
RUN rm -rf /var/cache/yum

CMD [ "screen", "sh", "-c", "/root/start.sh"]
