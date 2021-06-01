#!/usr/bin/python3
import docker, os, re, ssl, sys, urllib;

domain = sys.argv[2]
subdomain = sys.argv[3]
with_ssl = bool(sys.argv[1] == "SSL_ON")

container_name = ''

# Check Arguments & Set Variables
if len(sys.argv) == 4:
    container_name = sys.argv[3]
elif len(sys.argv) == 5:
    container_name = sys.argv[4]
else:
    print(f"Invalid Usage: {sys.argv[0]} WITH_SSL DOMAIN SUBDOMAIN [PARAMETERS]")
    exit(1)

# Search for Docker Container
container = None
try:
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    container = client.containers.get(container_name)
except docker.errors.DockerException as e:
    print(f"Unable to connect to docker: {str(e)}", file=sys.stderr)
    exit(1)
except docker.errors.NotFound as e:
    print(f"Unable to find container: {container_name}", file=sys.stderr)
    exit(1)
except Exception as e:
    print(f"Unknown error occured getting container by name: {str(e)}", file=sys.stderr)
    exit(1)
if container is None:
    print('Cannot retrieve docker client and/or container.', file=sys.stderr)
    exit(1)

# Get Container IP
container_ip = container.attrs['NetworkSettings']['IPAddress']
if container_ip == '':
    try:
        networks = container.attrs['NetworkSettings']['Networks']
        for net_key in networks.keys():
            if container_ip == '':
                container_ip = networks[net_key]['IPAddress']
    except Exception as e:
        print(f"Unknown error occured getting container IP address: {str(e)}", file=sys.stderr)
        exit(1)
if container_ip == '':
    print('Cannot determine container IP address.', file=sys.stderr)
    exit(1)

# Get Container Ports
container_locations = []
http_ip = 'http://' + container_ip
https_ip = 'https://' + container_ip

# Check If Ports 80 & 443 Are Open
try:
    request = urllib.request.urlopen(http_ip)
    if request.getcode() == 200 and request.geturl().startswith(http_ip):
        container_locations.append(http_ip)
except:
    pass

selfSignedContext = ssl.create_default_context()
selfSignedContext.check_hostname=False
selfSignedContext.verify_mode=ssl.CERT_NONE

try:
    request = urllib.request.urlopen(https_ip, context=selfSignedContext)
    if request.getcode() == 200 and request.geturl().startswith(https_ip):
        container_locations.append(https_ip)
except:
    pass

# Check Container Ports
if len(container_locations) != 2:
    ports = container.attrs['NetworkSettings']['Ports']
    for port_key in ports.keys():
        try:
            declared_port = re.search('[0-9]+', ports[port_key]).group(0)

                                          
            request = urllib.request.urlopen(f"{http_ip}:{declared_port}")
            if request.getcode() == 200 and request.geturl().startswith(http_ip):
                container_locations.append(f"{http_ip}:{declared_port}")
            else:
                request = urllib.request.urlopen(f"{https_ip}:{declared_port}", context=selfSignedContext)
                if request.getcode() == 200 and request.geturl().startswith(https_ip):
                    container_locations.append(f"{https_ip}:{declared_port}")
            if len(ports) == 2:
                break
        except:
            pass

if len(container_locations) == 0:
    print('Cannot determine a reachable port.', file=sys.stderr)
    exit(1)

# Create Conf

server = subdomain + '.' + domain
with open(f"/etc/nginx/conf.d/{server}.conf", 'w') as conf:
    httpLocation = ''
    httpsLocation = ''

    for location in container_locations:
        if httpLocation == '' and location.startswith('http://'):
            httpLocation = location
        elif httpsLocation == '' and location.startswith('https://'):
            httpsLocation = location

    if httpsLocation == '':
        httpLocation = f"proxy_pass {httpLocation}"
    else:
        httpLocation = f"return 301 {httpsLocation}"
        

    conf.write(f"""server {{
    listen 80;
    server_name {server};

    location / {{
        {httpLocation};
    }}
}}
""")

    if with_ssl:
        ssl_conf = ' ssl'
    else:
        ssl_conf = ''
    

    if httpsLocation != '':
        conf.write(f"""
server {{
    listen 443{ssl_conf};
    server_name {server};

    location / {{
        proxy_pass {httpsLocation};
    }}
}}
""")

os.system('nginx -s reload')
exit(0)