http_port 3128 require-proxy-header

acl localnet src 10.0.0.0/8
acl localnet src fc00::/7 # RFC 4193 local private network range
acl localnet src fe80::/10 # RFC 4291 link-local (directly plugged) machines
proxy_protocol_access allow localnet

acl SSL_ports port 443
acl Safe_ports port 80            # http
acl Safe_ports port 443           # https

acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Only allow cachemgr access from localhost
http_access allow localhost manager
http_access deny manager

# We strongly recommend the following be uncommented to protect innocent
# web applications running on the proxy server who think the only
# one who can access services on "localhost" is a local user
#http_access deny to_localhost

# Disabling publishing of the version of squid in headers
# and on error pages.
httpd_suppress_version_string on

# HOSTS
%{ for acl_key, acl_val in acl.sources ~}
acl hosts_${acl_key} src ${join(" ", acl_val)}
%{ endfor ~}

# ALLOW LISTS
%{ for acl_key, acl_val in acl.destinations ~}
acl allowlist_${acl_key} dstdomain "/etc/squid/conf.d/allowlist_${acl_key}"
%{ endfor ~}

# RULES
%{ for acl_val in acl.rules ~}
http_access allow hosts_${acl_val.source} allowlist_${acl_val.destination}
%{ endfor ~}


# http_access allow localnet
# http_access allow localhost
http_access deny all

# Leave coredumps in the first cache dir
coredump_dir /var/cache/squid

refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Delete forwarded-for header, to hide internal IP addresses from Internet end-points
forwarded_for delete
