# docker build -t elastic_ruby_server .
FROM ruby:3.0
LABEL maintainer="syright@gmail.com"

RUN apt-get update -y
RUN apt-get install -y openjdk-11-jre-headless wget curl git

WORKDIR /tmp/

ENV VERSION 7.9.3
ENV DOCKER true

ENV DOWNLOAD_URL "https://artifacts.elastic.co/downloads/elasticsearch"
ENV ES_TARBAL "${DOWNLOAD_URL}/elasticsearch-oss-${VERSION}-no-jdk-linux-x86_64.tar.gz"
ENV ES_TARBALL_ASC "${DOWNLOAD_URL}/elasticsearch-oss-${VERSION}-no-jdk-linux-x86_64.tar.gz.asc"
ENV EXPECTED_SHA_URL "${DOWNLOAD_URL}/elasticsearch-oss-${VERSION}-no-jdk-linux-x86_64.tar.gz.sha512"
ENV ES_TARBALL_SHA "679d02f2576aa04aefee6ab1b8922d20d9fc1606c2454b32b52e7377187435da50566c9000565df8496ae69d0882724fbf2877b8253bd6036c06367e854c55f6"
ENV GPG_KEY "46095ACC8548582C1A2699A9D27D666CD88E42B4"

RUN set -ex \
  && cd /tmp \
  && echo "===> Install Elasticsearch..." \
  && wget --progress=bar:force -O elasticsearch.tar.gz "$ES_TARBAL"; \
  if [ "$ES_TARBALL_SHA" ]; then \
  echo "$ES_TARBALL_SHA *elasticsearch.tar.gz" | sha512sum -c -; \
  fi; \
  if [ "$ES_TARBALL_ASC" ]; then \
  wget --progress=bar:force -O elasticsearch.tar.gz.asc "$ES_TARBALL_ASC"; \
  export GNUPGHOME="$(mktemp -d)"; \
  # ( gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
  # # || gpg --keyserver pgp.mit.edu --recv-keys "$GPG_KEY" \
  # || gpg --keyserver keyserver.pgp.com --recv-keys "$GPG_KEY" ); \
  # gpg --batch --verify elasticsearch.tar.gz.asc elasticsearch.tar.gz; \
  rm -rf "$GNUPGHOME" elasticsearch.tar.gz.asc || true; \
  fi; \
  tar -xf elasticsearch.tar.gz \
  && ls -lah

RUN mv elasticsearch-$VERSION /usr/share/elasticsearch \
  # && adduser -D -h /usr/share/elasticsearch elasticsearch \
  && useradd -m -d /usr/share/elasticsearch elasticsearch \
  && echo "===> Creating Elasticsearch Paths..." \
  && for path in \
  /usr/share/elasticsearch/data \
  /usr/share/elasticsearch/logs \
  /usr/share/elasticsearch/config \
  /usr/share/elasticsearch/config/scripts \
  /usr/share/elasticsearch/tmp \
  /usr/share/elasticsearch/plugins \
  ; do \
  mkdir -p "$path"; \
  chown -R elasticsearch "$path"; \
  done \
  && rm -rf /tmp/* /usr/share/elasticsearch/jdk

ENV JAVA_HOME /usr
ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV ES_TMPDIR /usr/share/elasticsearch/tmp

VOLUME ["/usr/share/elasticsearch/data"]

RUN useradd -m -s /bin/bash linuxbrew
RUN echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers
RUN su - linuxbrew -c 'mkdir ~/.linuxbrew'

run apt-get install -y build-essential procps curl file git

USER linuxbrew

RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
RUN /home/linuxbrew/.linuxbrew/bin/brew install watchman

USER root

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

################################################################
################################################################

RUN gem update bundler

RUN apt-get install -y git make g++ libcurl4 libcurl4-openssl-dev netcat

WORKDIR /app

ENV PROJECTS_ROOT /projects/
# ENV LOG_LEVEL DEBUG

COPY Gemfile* ./
COPY elastic_ruby_server.gemspec .
COPY lib/elastic_ruby_server/version.rb lib/elastic_ruby_server/version.rb

RUN bundle install -j 8

RUN curl https://gist.githubusercontent.com/pheen/3c660551afee8c88cd4d77d302f85d2a/raw/f30411da34a6f5e60cd0a2080517aa8ed35f8566/rubocop-daemon-wrapper -o /tmp/rubocop-daemon-wrapper
RUN mkdir -p /usr/local/bin/rubocop-daemon-wrapper
RUN mv /tmp/rubocop-daemon-wrapper /usr/local/bin/rubocop-daemon-wrapper/rubocop
RUN chmod +x /usr/local/bin/rubocop-daemon-wrapper/rubocop

ENV RUBOCOP_DAEMON_USE_BUNDLER true
ENV PATH /usr/local/bin/rubocop-daemon-wrapper:$PATH

COPY . ./

RUN bundle install

# RUN chown -R default:elasticsearch /usr/share/elasticsearch/
# RUN chown -R elasticsearch /usr/share/elasticsearch/

RUN chown -R elasticsearch /usr/share/elasticsearch/ \
    && chown -R elasticsearch /usr/share/elasticsearch/data \
    && chown -R elasticsearch /usr/share/elasticsearch/logs \
    && chown -R elasticsearch /usr/share/elasticsearch/config \
    && chown -R elasticsearch /usr/share/elasticsearch/config/scripts \
    && chown -R elasticsearch /usr/share/elasticsearch/tmp \
    && chown -R elasticsearch /usr/share/elasticsearch/plugins \
    && mkdir -p /usr/share/elasticsearch/data/ \
    && mkdir -p /usr/share/elasticsearch/data/nodes/ \
    && mkdir -p /usr/share/elasticsearch/data/nodes/0/ \
    && chown -R elasticsearch /usr/share/elasticsearch/data/nodes/0/ \
    && chown -R elasticsearch /usr/share/elasticsearch/data/nodes/0/ \
    && mkdir -p /usr/share/elasticsearch/data/watchman

COPY config/elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY config/override.conf /etc/systemd/system/elasticsearch.service.d/override.conf
COPY config/limits.conf /etc/security/limits.conf

CMD "/app/exe/entry.sh"
