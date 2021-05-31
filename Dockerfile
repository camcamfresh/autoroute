FROM nginx:alpine

EXPOSE 80
EXPOSE 443

# This shell is used to execute both fcgiwrap & nginx
COPY init.sh       /init.sh

# These are used to respond to 404 request & to start a daemon for searching.
COPY default/redirect.sh          /var/www/default/redirect.sh
COPY default/buildLocalConf.sh    /var/www/default/buildLocalConf.sh
COPY default/local.conf           /var/www/default/local.conf
COPY default/not_found.html       /var/www/default/not_found.html
COPY default/searching.html       /var/www/default/searching.html

# This points the unmatched nginx request to default.sh
COPY default.conf  /etc/nginx/conf.d/default.conf


RUN chmod +x /init.sh /var/www/default/redirect.sh /var/www/default/buildLocalConf.sh &&\
	apk update &&\
	apk upgrade &&\
	apk add fcgiwrap &&\
	mkdir -p /var/log/fcgiwrap &&\
	apk add py3-pip &&\
	pip3 install -U pip &&\
	pip3 install -U docker

CMD ["/init.sh"]