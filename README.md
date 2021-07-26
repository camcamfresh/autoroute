# Autoroute
## About
This container is designed to dynamically generate configuration files for unknown subdomain request from recognized top level domains using CGI scripts & the Docker Engine API. It is meant to help those who run or develop containers on their own network with personal domains.

DNS will still need to be configured for each subdomain. If you are devloping on a local network, you may want to create a wildcard subdomain in your DNS records to avoid this obstcale. This is not recommended for public IP addresses.

## Details
Nginx will handle all known request via the default configuration directory in `/etc/nginx/conf.d/`.
All unmatched request should default to `default.conf` inside this directory. A shell script is later used to trigger background process & return a CGI script via fcgiwrap.

### Matching Requests
If a request is unmatched by nginx, its subdomain, domain, and path are analyized.
Configuration files will only be generated under the following conditions:
- The TLD is found in the environment variable `TLDS`.
- A docker container matching the name of the subdomain is found
  - Note: A search parameter can be explicitly defined via environment variable.
- The docker container responds to request from Autoroute (e.g., on same docker network or has exposed ports)

### Processing Requests
If a request does not meet these conditions, it is redirected to the `not_found.html` page.

Otherwise, a responsive container exists and the request is temporarily redirected to the `searching.html` page. This contains JavaScript that refreshes the clients pages after a predetermined amount of time.

### HTTP & HTTPS Behavior
If the docker container supports HTTP traffic, a configuration file is immediately created. The client must wait 30 seconds for Nginx to reload the configuration. A daemon process is also created to configure SSL certificates.

If the docker continer only supports HTTPS traffic (even if self signed), the client must wait 90 seconds for SSL configuration to complete.


There are 4 environment variables that must be set in order to execute properly.
```dockerfile
ENV TLDS="example.com example.org"
VOLUME "/cert"
```

- TLDS - a string of recognized top level domains
  - Space-delineated domains create separate certificates.
- EMAIL - a single email for certbot to use when requesting each certificate.
- CERT_DIR - the container, folder path for certbot configuration.
  - `luadns.ini` must have the domain's luadns email & api token.
  - `cert/` contains the SSL certificate files. (Note: These are not symbolic links and should prevent any Docker volume mapping issues.)
  - `data/` contains certbot's pervious work and archives.
- NGINX_DIR - the container, folder path for nginx configuration.
