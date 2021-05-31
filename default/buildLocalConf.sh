#!/usr/bin/python3
import docker, os, re, sys;

domain = None
subdomain = None
parameter = None
search_term = None

if len(sys.argv) == 3:
    domain = sys.argv[1]
    subdomain = sys.argv[2]
    search_term = subdomain
elif len(sys.argv) == 4:
    domain = sys.argv[1]
    subdomain = sys.argv[2]
    parameter = sys.argv[3]
    search_term = parameter
else:
    print('Invalid usage: domain, subdomain, search override', file=sys.stderr)
    exit(1)

container = None
try:
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    container = client.containers.get(search_term)
except:
    print('Container ' + search_term + ' not found by name.', file=sys.stderr)
    exit(1)

ipaddr = container.attrs['NetworkSettings']['IPAddress']
if ipaddr is None or len(ipaddr) == 0:
    print('Unreachable IP Address: ' + ipaddr, file=sys.stderr)
    exit(1)

port = None
contiainerPorts = container.attrs['NetworkSettings']['Ports'].keys()
if len(contiainerPorts) > 0:
    for availablePort in contiainerPorts:
        portNumber = re.search('[0-9]+', availablePort).group(0)
        if os.system(f"curl --silent --fail {ipaddr}:{portNumber} > /dev/null") == 0:
            port = portNumber
            break
elif os.system(f"curl --silent --fail {ipaddr}:80 > /dev/null") == 0:
    port = 80

if port is None:
    print('Unreachable Port Number: ' + port, file=sys.stderr)
    exit(1)

if os.system(f"""
 cat local.conf |\
 sed -e 's/{{SERVER_NAME}}/{subdomain}.{domain}/g' |\
 sed -e 's/{{CONTAINER_IP}}/{ipaddr}/g' |\
 sed -e 's/{{CONTAINER_PORT}}/{port}/g' >\
 /etc/nginx/conf.d/{subdomain}.{domain}.conf &&\
 nginx -s reload
\n""") != 0:
    print('Unable to create conf file for ' + subdomain, sys.stderr)

