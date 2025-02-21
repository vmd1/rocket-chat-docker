FROM arm64v8/node:12.22.1-stretch as builder

# crafted and tuned by pierre@ozoux.net and sing.li@rocket.chat
MAINTAINER buildmaster@rocket.chat

RUN groupadd -r rocketchat \
&&  useradd -r -g rocketchat rocketchat \
&&  mkdir -p /app/uploads \
&&  chown rocketchat.rocketchat /app/uploads \
# `RUN mkdir ~/.gnupg
&& echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

VOLUME /app/uploads

# gpg: key 4FD08014: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
RUN gpg --batch --keyserver keyserver.ubuntu.com --recv-keys  0E163286C20D07B9787EBE9FD7F9D0414FD08104

 

ENV RC_VERSION 4.1.2

WORKDIR /app

RUN apt-get update && apt-get -y install g++ build-essential
RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y curl ca-certificates imagemagick --no-install-recommends 
RUN apt-get install libstdc++6
RUN apt-get -y install python
RUN curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz \
&&  curl -fSL "https://releases.rocket.chat/${RC_VERSION}/asc" -o rocket.chat.tgz.asc \
&&  gpg --batch --verify rocket.chat.tgz.asc rocket.chat.tgz \
&&  tar zxvf rocket.chat.tgz \
&&  rm rocket.chat.tgz rocket.chat.tgz.asc
ADD . /app


RUN set -x \
 && cd /app/bundle/programs/server \
 && npm install \
 # Start hack for sharp...
 && rm -rf npm/node_modules/sharp \
# && rm -rf npm/node_modules/grpc \
 && npm install sharp@0.22.1 \
# && npm install grpc@1.12.2 \
 && mv node_modules/sharp npm/node_modules/sharp \
# && mv node_modules/grpc npm/node_modules/grpc \
 # End hack for sharp
 && cd npm \
 && npm rebuild bcrypt --build-from-source \
 && npm cache clear --force

FROM arm64v8/node:12.22.1-stretch

RUN groupadd -r rocketchat \
&&  useradd -r -g rocketchat rocketchat \
&&  mkdir -p /app 

COPY --from=builder /app /app

RUN  mkdir -p /app/uploads \
&&   chown rocketchat.rocketchat /app/uploads 

VOLUME /app/uploads

USER rocketchat

WORKDIR /app/bundle


# needs a mongo instance - defaults to container linking with alias 'mongo'
ENV DEPLOY_METHOD=docker-arm64 \
    NODE_ENV=production \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    MONGO_OPLOG_URL=mongodb://mongo:27017/local \
    HOME=/tmp \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    Accounts_AvatarStorePath=/app/uploads


EXPOSE 3000

CMD ["node", "main.js"]
