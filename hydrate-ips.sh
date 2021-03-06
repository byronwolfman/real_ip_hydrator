#!/bin/bash

# Download list of IPv4 and IPv6 addresses from Cloudflare and write them into
# /etc/nginx/real_ip.conf, then reload nginx if changes have been made.
# IPv4 regex found via http://www.regexpal.com/93987 on 2016-09-24
# IPv6 regex found via http://www.regexpal.com/93988 on 2016-09-24

export PATH=/usr/local/sbin:/sbin:/bin:/usr/sbin:/usr/bin
export MYNAME=$0

# Print usage and exit
function showusage {
  echo -e "${0}\n\nUsage: ${0} [-h|--help] [-v|--verbose]\n"
  echo "  -h|--help    : Print this help message"
  echo "  -v|--verbose : Display output to stdout"
  exit 1
}

# Convenience function to log and/or output to stdout
function logput {
  /usr/bin/logger "${1}" --id --tag "${MYNAME}"
  if [ -n "$VERBOSE" ]; then
    echo "${MYNAME}[${$}]: ${1}"
  fi
}

# Parse options
for opt in "$@"; do
  case $opt in
    -v|--verbose)
      export VERBOSE=1
      shift
      ;;
    -h|--help)
      showusage
      ;;
    *)
      showusage
      exit 1
      ;;
  esac
done

# Get md5 of /etc/nginx/real_ip.conf if it exists; fake it otherwise
if [ -f /etc/nginx/real_ip.conf ]; then
  ORIGINAL_MD5=$(/usr/bin/md5sum /etc/nginx/real_ip.conf)
else
  ORIGINAL_MD5='NOMD5SUM'
fi

# Get cloudflare IP addresses and grep for IPv4/IPv6 objects
logput "Downloading Cloudflare IP adddresses"
IPV4=$(curl -Ss https://www.cloudflare.com/ips-v4/ | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(\/([0-9]|[1-2][0-9]|3[0-2]))?')
IPV6=$(curl -Ss https://www.cloudflare.com/ips-v6/ | grep -Eo 's*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:)))(%.+)?s*(\/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8]))?')
nIPV4FOUND=$(echo $IPV4 | wc -w)
nIPV6FOUND=$(echo $IPV6 | wc -w)

# Overwrite the old config
logput "Beginning overwrite"
echo -e '# Cloudflare IP addresses\n' > /etc/nginx/real_ip.conf

# Start adding IPs
for IP in $IPV4; do
  echo "set_real_ip_from ${IP};" >> /etc/nginx/real_ip.conf
done

for IP in $IPV6; do
  echo "set_real_ip_from ${IP};" >> /etc/nginx/real_ip.conf
done

logput "Wrote out ${nIPV4FOUND} ipv4 addresses"
logput "Wrote out ${nIPV6FOUND} ipv6 addresses"

# Finish with real_ip_header directive
echo -e '\nreal_ip_header X-Forwarded-For;' >> /etc/nginx/real_ip.conf
logput "Finished overwrite"

# Get md5 of /etc/nginx/real_ip.conf to see if rehydrating it has changed it
NEW_MD5=$(/usr/bin/md5sum /etc/nginx/real_ip.conf)
if [ "$ORIGINAL_MD5" != "$NEW_MD5" ]; then
  logput "Reloading nginx"
  sudo /bin/systemctl reload nginx
else
  logput "/etc/nginx/real_ip.conf unchanged after rehydrating"
fi
