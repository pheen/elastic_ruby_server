# docker build -t elastic_ruby_server .
FROM elasticsearch:8.3.1
# FROM docker.elastic.co/elasticsearch/elasticsearch:8.3.1@sha256:82cc5809c92b49cb4ca6538b188167dc41c2538da176021122dee5ea9b1deddb
LABEL maintainer="syright@gmail.com"

ENV DOCKER true

VOLUME ["/usr/share/elasticsearch/data"]

USER root

RUN apt-get -y update
RUN apt-get -y install wget unzip

# install watchman
WORKDIR /tmp/

RUN wget https://github.com/facebook/watchman/releases/download/v2022.06.20.00/watchman-v2022.06.20.00-linux.zip
RUN unzip watchman-*-linux.zip

WORKDIR /tmp/watchman-v2022.06.20.00-linux

RUN mkdir -p /usr/local/{bin,lib} /usr/local/var/run/watchman
RUN cp bin/* /usr/local/bin
RUN cp lib/* /usr/local/lib
RUN chmod 755 /usr/local/bin/watchman
RUN chmod 2777 /usr/local/var/run/watchman

# install ruby
WORKDIR /tmp/

RUN wget -O ruby-install-0.8.3.tar.gz https://github.com/postmodern/ruby-install/archive/v0.8.3.tar.gz
RUN tar -xzvf ruby-install-0.8.3.tar.gz

WORKDIR /tmp/ruby-install-0.8.3/

RUN apt-get -y install make
RUN make install
RUN ruby-install --system ruby 3.1.0

# install rubygems
WORKDIR /tmp/

RUN wget https://rubygems.org/rubygems/rubygems-3.3.17.zip
RUN unzip rubygems-3.3.17.zip

WORKDIR /tmp/rubygems-3.3.17

RUN ruby setup.rb

# install rubocop
WORKDIR /tmp/

RUN apt-get -y install g++ libcurl4 libcurl4-openssl-dev
RUN curl https://gist.githubusercontent.com/pheen/3c660551afee8c88cd4d77d302f85d2a/raw/f30411da34a6f5e60cd0a2080517aa8ed35f8566/rubocop-daemon-wrapper -o /tmp/rubocop-daemon-wrapper
RUN mkdir -p /usr/local/bin/rubocop-daemon-wrapper
RUN mv /tmp/rubocop-daemon-wrapper /usr/local/bin/rubocop-daemon-wrapper/rubocop
RUN chmod +x /usr/local/bin/rubocop-daemon-wrapper/rubocop

ENV RUBOCOP_DAEMON_USE_BUNDLER true
ENV PATH /usr/local/bin/rubocop-daemon-wrapper:$PATH

# setup project
WORKDIR /app

ENV PROJECTS_ROOT /projects/

RUN gem update bundler
# ENV LOG_LEVEL DEBUG

COPY . ./

RUN bundle install

COPY config/elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY config/override.conf /etc/systemd/system/elasticsearch.service.d/override.conf
COPY config/limits.conf /etc/security/limits.conf

RUN rm -rf /tmp/

USER elasticsearch

CMD "/app/exe/entry.sh"
