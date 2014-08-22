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
* nodejs
* chruby
* ruby-install
* perlbrew
* phantomjs

Build
-----

    docker build -t bugthing/docker-application .

Run
---

To start the container with all the services (ssh,nginx,postgres,solr,redis,memcached) exposed

    docker run -i --rm=true -p 22:22 -p 80:80 -p 5432:5432 -p 8080:8080 -p 6379:6379 -p 11211:11211 -t bugthing/docker-application
