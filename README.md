# Autocert
This container is designed to dynamically generate configuration files & certificates for unknown request from recognized domains.
Certificate generation is currently not supported.

## About
Nginx will handle all request included in the configuration directory. Unmatched request (i.e., with a status of 404) will trigger a shell script via fcgiwrap that further analyzes the request. Recognized domains invoke the Docker Engine API and search by the URL path (or subdomain if path is not present). If a container is found, a processing page is returned to the user which automatically reloads the page via JavaScript.

There are 4 environment variables that must be set in order to execute properly.

```dockerfile
ENV DOMAINS="example.com example.org"
ENV EMAIL="email@example.com"
ENV CERTS_DIR="/certbot"
ENV NGINX_DIR="/nginx"
```

- DOMAINS - a string of recognized domains
  - Space-delineated domains create separate certificates.
- EMAIL - a single email for certbot to use when requesting each certificate.
- CERTS_DIR - the container, folder path for certbot configuration.
  - `luadns.ini` must have the domain's luadns email & api token.
  - `certs/` contains the SSL certificate files. (Note: These are not symbolic links and should prevent any Docker volume mapping issues.)
  - `data/` contains certbot's pervious work and archives.
- NGINX_DIR - the container, folder path for nginx configuration.
