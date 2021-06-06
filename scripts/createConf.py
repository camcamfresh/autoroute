#!/usr/bin/python3

# Exit 0 - Sucess
# Exit 1 - Hard Error
# Exit 2 - HTTPS Error

import docker, os, re, ssl, sys, urllib;

print(f"createConf executed: {sys.argv}")
container_name = ''

# Check Arguments & Set Variables
if len(sys.argv) == 4:
    container_name = sys.argv[3]
elif len(sys.argv) == 5:
    if sys.argv[4] == '':
        container_name = sys.argv[3]
    else:
        container_name = sys.argv[4]
else:
    print(f"Invalid Usage: {sys.argv[0]} SSL_(ON|OFF) DOMAIN SUBDOMAIN [PARAMETERS]")
    exit(1)

with_ssl = bool(sys.argv[1] == "SSL_ON")
domain = sys.argv[2]
subdomain = sys.argv[3]

# Search for Docker Container
print(f"Searching for docker container")
container = None
try:
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    container = client.containers.get(container_name)
except docker.errors.NotFound as e:
    print(f"Unable to find container: {container_name}")
    exit(1)
except docker.errors.DockerException as e:
    print(f"Unable to connect to docker: {str(e)}")
    exit(1)
except Exception as e:
    print(f"Unknown error occured getting container by name: {str(e)}")
    exit(1)

if container is None:
    print('Cannot retrieve docker client and/or container.')
    exit(1)

# Get Container IP
print(f"Searching for container ip")
container_ip = container.attrs['NetworkSettings']['IPAddress']
if container_ip == '':
    try:
        networks = container.attrs['NetworkSettings']['Networks']
        for net_key in networks.keys():
            if container_ip == '':
                container_ip = networks[net_key]['IPAddress']
    except Exception as e:
        print(f"Unknown error occured getting container IP address: {str(e)}")
        exit(1)

if container_ip == '':
    print('Cannot determine container IP address.')
    exit(1)

# Create Function to Check Container Ports
def isResponsive(address, acceptSelfSigned):
    try:
        if acceptSelfSigned:
            # Accept self signed certificates
            selfSignedContext = ssl.create_default_context()
            selfSignedContext.check_hostname=False
            selfSignedContext.verify_mode=ssl.CERT_NONE
            
            request = urllib.request.urlopen(address, context=selfSignedContext)
        else:
            request = urllib.request.urlopen(address)
        
        # urlopen will open the URL and follow any redirects; must check for same ip.
        if request.getcode() == 200 and request.geturl().startswith(address):
            print(f"Container responsive at URL: {address}")
            return True
    except Exception as e:
        print(f"Unknown error occured contacting container: {str(e)}")
    
    print(f"Container NOT responsive at URL: {address}")
    return False

# Get Container Ports
print(f"Searching for container port")
container_location = ''
http_ip = 'http://' + container_ip
https_ip = 'https://' + container_ip

# Check if 443 is Open First
if isResponsive(https_ip, True):
    container_location = https_ip
# Otherwise check if 80 is Open
elif isResponsive(http_ip, False):
    container_location = http_ip
# Finally Check Container Ports
else:
    ports = container.attrs['NetworkSettings']['Ports']
    for port_key in ports.keys():
        try:
            declared_port = re.search('[0-9]+', ports[port_key]).group(0)
            
            address = https_ip + ':' + declared_port
            if isResponsive(address, True):
                container_location = address
            else:
                address = http_ip + ':' + declared_port
                if isResponsive(address, False):
                    container_location = address
            
            if container_location != '':
                break
        except Exception as e:
            print(f"Unknown error occured parsing container ports: {str(e)}")

if container_location == '':
    print('Cannot determine a reachable port.')
    exit(1)

print("Creating container location strings")
server = f"{subdomain}.{domain}"
if with_ssl:
    httpLocation = f"return 301 https://{server}"
    httpsLocation = f"proxy_pass {container_location}"
# We check for https then http, if https we do nothing.
# If a container is programmed for https we'll never proxy it over http.
elif container_location.startswith('http://'):
    httpLocation = f"proxy_pass {container_location}"
    httpsLocation = ''
else:
    httpLocation = ''
    httpsLocation = ''

# Only reason to hit this point is when container is programmed for https, but ssl is off.
# Exit with special code 2, showing it was reachable. 
if httpLocation == '' and httpsLocation == '':
    print(f"Could not determine http(s) location for {container_location}")
    exit(2)
elif httpsLocation == '':
    print(f"HTTPS Configuration Disabled on Container using {container_location} instead")

# Create Nginx Configuration File
print(f"Creating Nginx Configuration File: {server}.conf")
with open(f"/etc/nginx/conf.d/{server}.conf", 'w') as conf:   
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
        ssl_location = f"include /etc/nginx/ssl.d/{server}/ssl.conf;\n"
    else:
        ssl_conf = ''
        ssl_location = ''
    
    if httpsLocation != '':
        conf.write(f"""
server {{
    listen 443{ssl_conf};
    server_name {server};
    {ssl_location}
    location / {{
        {httpsLocation};
    }}
}}
""")

print('Reloading nginx configuration\n')
os.system('nginx -s reload')
exit(0)
