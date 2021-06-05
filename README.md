# Autocert
This container is designed to dynamically generate configuration files & certificates for unknown subdomain request from recognized top level domains using CGI scripts & the Docker Engine API. It is meant to help those who run or develop containers on their own network with personal domains.

DNS will still need to be configured for each subdomain. If you are devloping on a local network, you may want to create a wildcard subdomain in your DNS records to avoid this obstcale. This is not recommended for public IP address.

## About
Nginx will handle all known request via the default configuration directory in `/etc/nginx/conf.d/`.
All unmatched request should default to `default.conf` inside this directory. A shell script is later used to trigger background process & return a CGI script via fcgiwrap. This configuration file contains a 5 minute cache based on the requested URL's domain that prevents duplicating the SSL generation process.

If a request is unmatched, its subdomain, domain, and path are analyized.
Configuration files for a request will be generated on the following conditions:
 - The TLD is localhost, 127.0.0.1, or in the environment variable `DOMAINS`.
 - A docker container matching the name of the request path (or subdomain if not present) is found
 - The docker container responds to request from Autocert (e.g., on same docker network or has exposed ports)
Otherwise, the request is redirected to the `not_found.html` page.

SSL Certificates are generated on the following conditions:
 - A configuration file has just been generated.
 - The TLD is in the environment variable `DOMAINS`.

If a configuration file is generated, the request is temporarily redirected to the `searching.html` page.


The request must originate from a subdomain. 

Either the path or subdomain (if path is not provided) will be used to search for an existing Docker container

Recognized domains invoke the Docker Engine API and search by the URL path (or subdomain if path is not present). If a container is found, a processing page is returned to the user which automatically reloads the page via JavaScript.

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
