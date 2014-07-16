FROM debian:wheezy

MAINTAINER bugthing

ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_BASE_PACKAGES build-essential autoconf locales ca-certificates \
      libyaml-dev  libxml2-dev libssl-dev libreadline6 libreadline6-dev zlib1g zlib1g-dev \
      libevent-dev libsqlite3-dev libxslt1-dev libxml2-dev libssl-dev libfontconfig1-dev \
      bison openssl python-software-properties software-properties-common lsb-release lsb-core \
      curl wget tmux vim git default-jre runit chrpath nginx xvfb iceweasel openssh-server daemontools \
      lzop pv python-setuptools python-all-dev

RUN apt-get update && apt-get upgrade --assume-yes && apt-get dist-upgrade --assume-yes
RUN apt-get install --assume-yes $DEBIAN_BASE_PACKAGES || apt-get update --fix-missing
# install same list of base packages (incase first failed)
RUN apt-get install --assume-yes $DEBIAN_BASE_PACKAGES || echo "no need to install"

# Set timezone + locale
RUN echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && dpkg-reconfigure -f noninteractive locales && \
    echo "LANG=en_GB.UTF-8" > /etc/default/locale && \
    echo "Europe/London" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata

# configure ssh server
ADD ./files/sshd_config /etc/ssh/sshd_config
RUN mkdir /var/run/sshd
RUN chmod 0755 /var/run/sshd

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
    adduser --system --no-create-home redis &&\
    mkdir -p /var/redis /etc/redis/ /var/run/redis /var/log/redis &&\
    chown -R redis /var/redis /etc/redis/ /var/run/redis /var/log/redis
ENV PATH /opt/redis/bin/:$PATH

# solr
ENV SOLR_VERSION 3.6.0
RUN wget -O solr.tar.gz http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/apache-solr-$SOLR_VERSION.tgz &&\
    tar -C /opt --extract --file solr.tar.gz &&\
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
        postgresql-$POSTGRES_VERSION-repmgr &&\
    /etc/init.d/postgresql stop

# install wal-e (pg to s3)
RUN easy_install pip &&\
    easy_install --upgrade pip &&\
    pip install wal-e &&\
    easy_install --upgrade wal-e &&\
    easy_install boto

# chruby
ENV CHRUBY_VERSION 0.3.8
RUN wget -O chruby-$CHRUBY_VERSION.tar.gz https://github.com/postmodern/chruby/archive/v$CHRUBY_VERSION.tar.gz && tar -xzvf chruby-$CHRUBY_VERSION.tar.gz
RUN cd chruby-$CHRUBY_VERSION/ &&\
    make install &&\
    cd / &&\
    echo '[ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ] || return' >> /etc/profile.d/chruby.sh &&\
    echo 'source /usr/local/share/chruby/chruby.sh' >> /etc/profile.d/chruby.sh

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
    mv phantomjs-$PHANTOMJS_VERSION-linux-x86_64 /opt/ &&\
    ln -s /opt/phantomjs-$PHANTOMJS_VERSION-linux-x86_64 /opt/phantomjs
ENV PATH /opt/phantomjs/bin/:$PATH

# nodejs
ENV NODEJS_VERSION 0.10.22
RUN wget -O nodejs.tar.gz http://nodejs.org/dist/v$NODEJS_VERSION/node-v$NODEJS_VERSION-linux-x64.tar.gz &&\
    tar C /opt --extract --file nodejs.tar.gz
ENV PATH /opt/node-v$NODEJS_VERSION-linux-x64/bin:$PATH
