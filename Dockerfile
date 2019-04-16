FROM debian:stretch-slim
LABEL  maintainer="af@counterflowai.com" domain="counterflow.ai"

RUN apt-get clean
RUN apt-get autoremove
RUN apt-get update --fix-missing
RUN apt-get install -y zlib1g-dev libluajit-5.1 liblua5.1-dev lua-socket libcurl4-openssl-dev libatlas-base-dev libhiredis-dev syslog-ng git make jq libmicrohttpd-dev procps bc python3

RUN git clone https://github.com/counterflow-ai/dragonfly-mle;
#RUN git clone -b devel https://github.com/counterflow-ai/dragonfly-mle; \

#COPY ./dragonfly-mle /dragonfly-mle
RUN cd dragonfly-mle/src; make clean; sh ./make-linux-target.sh ; make ;  make install
RUN rm -rf dragonfly-mle
#
# Build redis
#
RUN git clone https://github.com/antirez/redis.git; \
    cd redis/src; make ; make install
RUN rm -rf redis
#
# Build redis ML
#
RUN git clone https://github.com/RedisLabsModules/redis-ml.git; \
    cd redis-ml/src; \
    make ; \
    mkdir /usr/local/lib ; \
    cp redis-ml.so /usr/local/lib
RUN rm -rf redis-ml

#
# Build bats-core for testing
#
RUN git clone https://github.com/bats-core/bats-core.git; \
    cd bats-core; ./install.sh /usr/local; 

RUN apt-get purge -y build-essential git make; apt-get autoremove ; apt-get autoclean

RUN mkdir /usr/local/mle-data
RUN mkdir /var/log/dragonfly-mle
RUN /etc/init.d/syslog-ng restart

WORKDIR event-triage
COPY . /event-triage
RUN ls -la 
CMD bats -r test
