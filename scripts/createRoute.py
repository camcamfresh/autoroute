#!/usr/bin/python3
# Author : Cameron S.
# License: https://www.gnu.org/licenses/gpl-3.0.en.html

# This script uses the Docker Engine API to search for containers that:
# 1) are on the same Docker network as this container, and
# 2) have an environment variable SUBDOMAIN matching the request, otherwise
#    conatiners with a name matching the requested subdomain

# Exit Statuses
# 0     Sucessfully Created Route
# 1     Failed to Create Route; Container Detected via HTTPS
# 2     Failed to Create Route; Runtime Error

import docker, os, re, ssl, sys, urllib

# Check Arguments
if len(sys.argv) != 3:
    print(f"Invalid Usage: createRoute.py DOMAIN SUBDOMAIN", file=sys.stderr)
    exit(2)
else:
    print(f"createRoute.py: Routing {sys.argv}")

# Set Initial Variables
domain = sys.argv[1]
subdomain = sys.argv[2]
override = os.getenv(sys.argv[2])

if override is None:
    container_name = sys.argv[2]
else:
    container_name = override

# Search for Docker Container
print(f"createRoute.py: Searching for Docker Container by name: {container_name}")
try:
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    container = client.containers.get(container_name)
except docker.errors.NotFound as e:
    print(f"createRoute.py: Unable to find container: {container_name}", file=sys.stderr)
    exit(2)
except docker.errors.DockerException as e:
    print(f"createRoute.py: Unable to connect to Docker: {str(e)}", file=sys.stderr)
    exit(2)
except Exception as e:
    print(f"createRoute.py: Unknown error occured getting container by name: {str(e)}", file=sys.stderr)
    exit(2)

if container is None:
    print('createRoute.py: Cannot retrieve docker client and/or container.', file=sys.stderr)
    exit(2)

# Get Container IP
print(f"createRoute.py: Searching for Container IP")
container_ip = container.attrs['NetworkSettings']['IPAddress']
if container_ip == '':
    try:
        networks = container.attrs['NetworkSettings']['Networks']
        for net_key in networks.keys():
            if container_ip == '':
                container_ip = networks[net_key]['IPAddress']
    except Exception as e:
        print(f"createRoute.py: Unknown error occured getting container IP address: {str(e)}", file=sys.stderr)
        exit(2)

if container_ip == '':
    print('createRoute.py: Cannot determine container IP address.', file=sys.stderr)
    exit(2)

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
            print(f"createRoute.py: Container responsive at URL: {address}")
            return True
    except Exception as e:
        print(f"createRoute.py: Unknown error occured contacting container: {str(e)}", file=sys.stderr)
    
    print(f"createRoute.py: Container not responsive at URL: {address}", file=sys.stderr)
    return False

# Get Container Ports
print(f"createRoute.py: Searching for container port")
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
            print(f"createRoute.py: Unknown error occured parsing container ports: {str(e)}", file=sys.stderr)

if container_location == '':
    print('createRoute.py: Cannot determine a reachable port.', file=sys.stderr)
    exit(2)

server = f"{subdomain}.{domain}"

# Search for Available SSL Certificates
if os.path.exists(f'/etc/nginx/ssl.d/{server}/ssl.conf'):
    hasSSL = True
    print(f"createRoute.py: SSL Certificates found for: {container_name}")
else:
    hasSSL = False
    print(f"createRoute.py: SSL Certificates not found for: /etc/nginx/ssl.d/{server}/ssl.conf")


print("createRoute.py: Generating Container location strings")
if hasSSL:
    httpLocation = f"return 301 https://{server}"
    httpsLocation = f"proxy_pass {container_location}"
elif container_location.startswith('http://'):
    httpLocation = f"proxy_pass {container_location}"
    httpsLocation = ''
    print(f"createRoute.py: WARNING {container_name} proxied over insecure HTTP connection.")
# If a container is programmed for https we'll never proxy it over http.
elif container_location.startswith('https://'):
    print(f"createRoute.py: SSL Certificates not available for: {container_location}", file=sys.stderr)
    exit(1)
else:
    print(f"createRoute.py: Could not determine location for: {container_location}", file=sys.stderr)
    exit(2)

# Create Nginx Configuration File
print(f"createRoute.py: Creating Nginx Configuration File: {server}.conf")
confDestination = f"/etc/nginx/conf.d/{server}.conf"
os.system(f'''cat /usr/share/nginx/defaults/template.conf | \\
        sed -e 's/{{LISTEN}}/80;/' \\
        -e 's/{{SERVER_NAME}}/{server};/' \\
        -e 's/{{INCLUDE}}//' \\
        -e 's>{{LOCATION}}>{re.escape(httpLocation)};>' > {confDestination}; ''')

if httpsLocation != '':
    os.system(f'''cat /usr/share/nginx/defaults/template.conf | \\
        sed -e 's/{{LISTEN}}/443 ssl;/' \\
        -e 's/{{SERVER_NAME}}/{server};/' \\
        -e 's/{{INCLUDE}}/include \/etc\/nginx\/ssl.d\/{server}\/ssl.conf;/' \\
        -e 's>{{LOCATION}}>{re.escape(httpsLocation)};>' >> {confDestination}; ''')

if os.path.exists(f"/etc/nginx/conf.d/{server}.conf"):
    print('createRoute.py: Reloading nginx configuration')
    os.system('nginx -s reload')
exit(0)
