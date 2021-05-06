http_port 3128 require-proxy-header

acl localnet src 10.0.0.0/8
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

# As per DW-4823, disabling publishing of the version of squid in headers
# and on error pages.
httpd_suppress_version_string on

# HOSTS
%{ if environment == "management-dev" }

acl hosts_packer_mgmtdev src          ${cidr_block_packer_mgmtdev}
acl hosts_internet_egress_mgmtdev src ${cidr_block_internet_egress_mgmtdev}
acl hosts_ci_cd_mgmtdev src           ${cidr_block_ci_cd_mgmtdev}

%{ endif }


%{ if environment == "management" }

%{ for kali_host in split(",", kali_hosts) ~}
acl hosts_kali src ${kali_host}
%{ endfor ~}

acl hosts_packer_mgmt src             ${cidr_block_packer_mgmt}
acl hosts_internet_egress_mgmt src    ${cidr_block_internet_egress_mgmt}
acl hosts_ci_cd_mgmt src              ${cidr_block_ci_cd_mgmt}
%{ endif }


# WHITELISTS
acl ${whitelist_ci_cd_name} dstdomain        "/etc/squid/conf.d/${whitelist_ci_cd_name}"
acl ${whitelist_packer_name} dstdomain       "/etc/squid/conf.d/${whitelist_packer_name}"
acl ${whitelist_aws_services_name} dstdomain "/etc/squid/conf.d/${whitelist_aws_services_name}"
acl ${whitelist_ingest_name} dstdomain       "/etc/squid/conf.d/${whitelist_ingest_name}"


# RULES
%{ if environment == "management-dev" }

http_access allow hosts_packer_mgmtdev          ${whitelist_aws_services_name}
http_access allow hosts_ci_cd_mgmtdev           ${whitelist_aws_services_name}

http_access allow hosts_packer_mgmtdev          ${whitelist_packer_name}
http_access allow hosts_ci_cd_mgmtdev           ${whitelist_ci_cd_name}
# temporarily allow NLBs to access the same sites as Concourse
# Concourse accesses the proxy through the NLBs in such a way that the source IPs
# are hidden from Squid
# http_access allow hosts_internet_egress_mgmtdev    ${whitelist_ci_cd_name}
%{ endif }


%{ if environment == "management" }

http_access allow hosts_packer_mgmt             ${whitelist_aws_services_name}
http_access allow hosts_ci_cd_mgmt              ${whitelist_aws_services_name}

http_access allow hosts_packer_mgmt             ${whitelist_packer_name}
http_access allow hosts_ci_cd_mgmt              ${whitelist_ci_cd_name}

%{ endif }

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
