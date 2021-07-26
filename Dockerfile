FROM nginx:alpine

# Configuration
EXPOSE 80
EXPOSE 443

ENV TLDS "example.com"

VOLUME /cert        /cert
VOLUME /nginx       /etc/nginx

# Copy Scripts & Default Files
COPY entrypoint.sh /entrypoint.sh
COPY defaults /usr/share/nginx/defaults
COPY scripts /usr/share/nginx/scripts

RUN cp /usr/share/nginx/defaults/default.conf /etc/nginx/conf.d/default.conf &&\
    chmod 111 /usr/share/nginx/scripts/* &&\
    apk update &&\
    apk upgrade &&\
    apk add py3-pip fcgiwrap socat inotify-tools &&\
    pip3 install -U docker

CMD ["sh", "/entrypoint.sh"]