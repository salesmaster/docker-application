FROM debian:wheezy

MAINTAINER salesmaster

ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_BASE_PACKAGES build-essential autoconf locales ca-certificates sudo \
      libyaml-dev  libxml2-dev libssl-dev libreadline6 libreadline6-dev zlib1g zlib1g-dev \
      libevent-dev libsqlite3-dev libxslt1-dev libxml2-dev libssl-dev libfontconfig1-dev \
      bison openssl python-software-properties software-properties-common lsb-release lsb-core \
      curl wget tmux vim git default-jre runit chrpath nginx xvfb iceweasel openssh-server daemontools \
      lzop pv python-setuptools python-all-dev

RUN apt-get update && apt-get upgrade --assume-yes && apt-get dist-upgrade --assume-yes && \
    (apt-get install --assume-yes $DEBIAN_BASE_PACKAGES || apt-get update --fix-missing) && \
    (apt-get install --assume-yes $DEBIAN_BASE_PACKAGES || echo "no need to install") &&\
    apt-get clean

# Set timezone + locale
RUN echo "en_GB.UTF-8 UTF-8\nen_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && dpkg-reconfigure -f noninteractive locales && \
    echo "LANG=en_GB.UTF-8" > /etc/default/locale && \
    echo "Europe/London" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata

# configure ssh server
ADD ./files/sshd_config /etc/ssh/sshd_config
RUN mkdir /var/run/sshd &&\
    chmod 0755 /var/run/sshd

# Base auth details.. should be overridden by sub-container
RUN echo 'root:lkJh98.443g8yFCHHcppic-9' | chpasswd
ADD ./files/docker-debian-wheezy-base_id_rsa /root/.ssh/docker-debian-wheezy-base_id_rsa
ADD ./files/docker-debian-wheezy-base_id_rsa.pub /root/.ssh/docker-debian-wheezy-base_id_rsa.pub
RUN cat /root/.ssh/docker-debian-wheezy-base_id_rsa.pub > /root/.ssh/authorized_keys

# memcache
ENV MEMCACHED_VERSION 1.4.20
RUN wget -O memcached.tar.gz http://memcached.org/files/memcached-$MEMCACHED_VERSION.tar.gz &&\
    tar -zxvf memcached.tar.gz &&\
    cd memcached-$MEMCACHED_VERSION/ &&\
    ./configure --prefix=/opt/memcached &&\
    make && make test && make install &&\
    cd / &&\
    rm -rf memcached.tar.gz memcached-$MEMCACHED_VERSION &&\
    adduser --system --no-create-home memcached &&\
    mkdir -p /var/run/memcached /var/log/memcached &&\
    chown -R memcached /opt/memcached /var/run/memcached /var/log/memcached
ENV PATH /opt/memcached/bin/:$PATH

# redis
ENV REDIS_VERSION 2.8.12
ADD files/redis.conf /etc/redis/redis.conf
RUN wget -O redis.tar.gz http://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz &&\
    tar -zxvf redis.tar.gz &&\
    cd redis-$REDIS_VERSION/ &&\
    make &&\
    mkdir -p /opt/redis/bin/ &&\
    cp src/redis-server /opt/redis/bin/ &&\
    cp src/redis-cli /opt/redis/bin/ &&\
    cd / &&\
    rm -rf redis.tar.gz redis-$REDIS_VERSION &&\
    adduser --system --no-create-home redis &&\
    mkdir -p /var/redis /etc/redis/ /var/run/redis /var/log/redis &&\
    chown -R redis /var/redis /etc/redis/ /var/run/redis /var/log/redis
ENV PATH /opt/redis/bin/:$PATH

# solr
ENV SOLR_VERSION 3.6.0
RUN wget -O solr.tar.gz http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/apache-solr-$SOLR_VERSION.tgz &&\
    tar -C /opt --extract --file solr.tar.gz &&\
    rm -rf solr.tar.gz &&\
    ln -s /opt/apache-solr-$SOLR_VERSION /opt/solr &&\
    cp -a /opt/solr/example/solr /etc/ &&\
    adduser --system --no-create-home solr &&\
    mkdir -p /var/lib/solr/data/index /var/lib/solr /var/run/solr /var/log/solr &&\
    chown -R solr /var/lib/solr /var/run/solr /var/log/solr /etc/solr

# postgres and repmgr
ENV POSTGRES_VERSION 9.3
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list &&\
    apt-get update &&\
    apt-get install -y --force-yes \
        postgresql-$POSTGRES_VERSION postgresql-client-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION libpq-dev \
        postgresql-$POSTGRES_VERSION-repmgr repmgr &&\
    /etc/init.d/postgresql stop

## install wal-e (pg to s3)
#RUN easy_install pip &&\
#    easy_install --upgrade pip &&\
#    pip install wal-e &&\
#    easy_install --upgrade wal-e &&\
#    easy_install boto

# chruby
ENV CHRUBY_VERSION 0.3.8
RUN wget -O chruby-$CHRUBY_VERSION.tar.gz https://github.com/postmodern/chruby/archive/v$CHRUBY_VERSION.tar.gz && tar -xzvf chruby-$CHRUBY_VERSION.tar.gz
RUN cd chruby-$CHRUBY_VERSION/ &&\
    make install &&\
    cd / &&\
    echo '[ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ] || return' >> /etc/profile.d/chruby.sh &&\
    echo 'source /usr/local/share/chruby/chruby.sh' >> /etc/profile.d/chruby.sh &&\
    chmod +x /etc/profile.d/chruby.sh

# ruby-install
ENV RUBYINSTALL_VERSION 0.4.3
RUN wget -O ruby-install-$RUBYINSTALL_VERSION.tar.gz https://github.com/postmodern/ruby-install/archive/v$RUBYINSTALL_VERSION.tar.gz &&\
    tar -xzvf ruby-install-$RUBYINSTALL_VERSION.tar.gz &&\
    cd ruby-install-$RUBYINSTALL_VERSION/ &&\
    make install &&\
    cd /

# perlbew
RUN mkdir -p /usr/local/perlbrew /root
ENV PERLBREW_ROOT /usr/local/perlbrew
ENV PERLBREW_HOME /root/.perlbrew
ENV PERLBREW_PATH /usr/local/perlbrew/bin
ENV PATH /usr/local/perlbrew/bin:$PATH
RUN curl -kL http://install.perlbrew.pl | bash &&\
    perlbrew install-cpanm &&\
    perlbrew info

# phantomjs
ENV PHANTOMJS_VERSION 1.9.7
RUN wget --no-check-certificate -O phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 &&\
    tar -xjf phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 &&\
    rm -rf phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 &&\
    mv phantomjs-$PHANTOMJS_VERSION-linux-x86_64 /opt/ &&\
    ln -s /opt/phantomjs-$PHANTOMJS_VERSION-linux-x86_64 /opt/phantomjs
ENV PATH /opt/phantomjs/bin/:$PATH

# nodejs
ENV NODEJS_VERSION 0.10.22
RUN wget -O nodejs.tar.gz http://nodejs.org/dist/v$NODEJS_VERSION/node-v$NODEJS_VERSION-linux-x64.tar.gz &&\
    tar C /opt --extract --file nodejs.tar.gz &&\
    rm -rf nodejs.tar.gz
ENV PATH /opt/node-v$NODEJS_VERSION-linux-x64/bin:$PATH

# generate postgres ssl and configure
RUN su - postgres -c "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=UK/ST=Denial/L=Springfield/O=Dis/CN=salesmaster.co.uk" -keyout /var/lib/postgresql/sm-pg.key  -out /var/lib/postgresql/sm-pg.crt" &&\
    echo "ssl_cert_file = '/var/lib/postgresql/sm-pg.crt' \n" \
      "ssl_key_file = '/var/lib/postgresql/sm-pg.key' \n" \
      "listen_addresses = '*' \n" \
      "\n" >> /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf &&\
    chmod og-rwx /var/lib/postgresql/sm-pg.key

# create runit services:
RUN \
    mkdir -p /etc/service/sshd &&\
    echo "#!/bin/sh \n" \
      "exec /usr/sbin/sshd -D" > /etc/service/sshd/run &&\
    \
    mkdir -p /etc/service/cron &&\
    echo "#!/bin/sh \n" \
      "exec /usr/sbin/cron -f" > /etc/service/cron/run &&\
    \
    mkdir -p /etc/service/postgres &&\
    echo "#!/bin/sh \n" \
      "exec chpst -u postgres -- /usr/lib/postgresql/$POSTGRES_VERSION/bin/postgres -c config_file=/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf \n" \
      "\n" > /etc/service/postgres/run &&\
    \
    mkdir -p /etc/service/memcached &&\
    echo "#!/bin/sh \n" \
      "exec chpst -u memcached -- /opt/memcached/bin/memcached -u memcached -P /var/run/memcached/memcached.pid -m 128 >> /var/log/memcached/memcached.log 2>&1 \n" \
      "\n" > /etc/service/memcached/run &&\
    \
    mkdir -p /etc/service/redis &&\
    echo "#!/bin/sh \n" \
      "exec chpst -u redis -- /opt/redis/bin/redis-server /etc/redis/redis.conf \n" \
      "\n" > /etc/service/redis/run &&\
    \
    sed -i '1s/^/daemon off; \n/' /etc/nginx/nginx.conf &&\
    mkdir -p /etc/service/nginx &&\
    echo "#!/bin/sh \n" \
      "exec chpst -u root -- /usr/sbin/nginx \n" \
      "\n" > /etc/service/nginx/run &&\
    \
    mkdir -p /etc/service/solr &&\
    echo "#!/bin/sh \n" \
      "cd /opt/solr/example \n" \
      "exec chpst -u solr -- /usr/bin/java -Dsolr.solr.home=/etc/solr/ -Djetty.logs=/var/log/solr/solr.log -Djetty.home=/etc/solr -Djava.io.tmpdir=/tmp  -Djetty.port=8080 -Xms2048m -Xmx2048m -jar /opt/solr/example/start.jar \n" \
      "\n" > /etc/service/solr/run &&\
    \
    chmod -R +x /etc/service

# Add example container prepare script..
RUN mkdir /opt/container_bin/
ADD files/container_prepare /opt/container_bin/container_prepare
RUN chmod -R +x /opt/container_bin
ENV PATH /opt/container_bin/:$PATH

# prepare and run all services
CMD container_prepare && runsvdir-start
