# Centos / EPEL
mirrors.coreix.net
mirror.centos.org

# Oracle JDK
download.oracle.com
edelivery.oracle.com

# Apache Maven, TomCat
archive.apache.org

# Python Package Index
pypi.python.org
pypi.org
files.pythonhosted.org

# OS install & updates
cdn-fastly.deb.debian.org
dl-cdn.alpinelinux.org

# EPEL repository configuration files
dl.fedoraproject.org
mirrors.fedoraproject.org
download.fedoraproject.org

# GitHub.com
api.github.com
github.com
codeload.github.com

# Allow yum to contact the packages and repo URL's via proxy
packages.eu-west-2.amazonaws.com
repo.eu-west-2.amazonaws.com
amazonlinux.eu-west-2.amazonaws.com

# Sysdig Auditing
download.sysdig.com

%{ if environment == "management-dev" }
# More rules could be added here for mgmt-dev only
%{ endif }
