FROM amazoncorretto:17

VOLUME ["/data"]
WORKDIR /data

RUN yum -y install wget \
    screen
RUN yum clean all
RUN rm -rf /var/cache/yum

# 1.19
# RUN cd / && wget https://launcher.mojang.com/v1/objects/e00c4052dac1d59a1188b2aa9d5a87113aaf1122/server.jar

# 1.19.2
RUN cd / && wget https://piston-data.mojang.com/v1/objects/f69c284232d7c7580bd89a5a4931c3581eae1378/server.jar
# RUN chmod +x /server.jar

COPY eula.txt /eula.txt
COPY start.sh /start.sh
RUN chmod +x /start.sh


CMD [ "screen", "/start.sh" ]
