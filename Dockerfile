FROM nginx:alpine

# Configuration
ENV      DOMAINS                example.com
ENV      EMAIL                  email@example.com
EXPOSE   80
EXPOSE   443
VOLUME   /certs                 /certs
VOLUME   /nginx                 /etc/nginx

# This shell is used to execute both fcgiwrap & nginx
COPY init.sh       /init.sh

# These are used to respond to 404 request & to start a daemon for searching.
COPY scripts       /usr/share/nginx/scripts

# This points the unmatched nginx request to default.sh
COPY default.conf  /etc/nginx/conf.d/default.conf

RUN chmod +x /init.sh &&\
	apk update &&\
	apk upgrade &&\
	apk add fcgiwrap py3-pip gcc python3-dev musl-dev libffi-dev cargo py-cryptography &&\
	mkdir -p /var/log/fcgiwrap &&\
	apk add py3-pip &&\
	pip3 install -U pip docker certbot certbot-dns-luadns dns-lexicon==3.5

CMD ["/init.sh"]