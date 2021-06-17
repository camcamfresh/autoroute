FROM nginx:alpine

# Configuration
EXPOSE 80
EXPOSE 443

ENV DOMAINS "example.com"

VOLUME /certs          /certs
VOLUME /nginx          /etc/nginx

# Copy Scripts & Default Files
COPY entrypoint.sh /entrypoint.sh
COPY defaults /usr/share/nginx/defaults
COPY scripts /usr/share/nginx/scripts

RUN cp /usr/share/nginx/defaults/default.conf /etc/nginx/conf.d/default.conf &&\
    chmod 111 /usr/share/nginx/scripts/* &&\
    apk update &&\
    apk upgrade &&\
    apk add py3-pip fcgiwrap &&\
    pip3 install -U docker

CMD ["sh", "/entrypoint.sh"]