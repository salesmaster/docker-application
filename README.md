docker-application
==================

Docker container for web a application

Base container built off Debian wheezy, featuring:

* base packages (for building)
 * build tools and dependancys
 * runit
 * nginx
 * vim
 * xvfb
* memcache
* redis
* solr
* postgres
 * repmgr
 * wal-e
* nodejs
* chruby
* ruby-install
* perlbrew
* phantomjs

Build
-----

    docker build -t bugthing/docker-application .

