set -o errexit
set -o nounset
set -o pipefail

yum -y update && yum -y upgrade

yum -y install wget

#download dumb-init
wget -q -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_amd64
chmod +x /usr/local/bin/dumb-init

#verify dumb-init checksum
wget -q -O /tmp/dumb-init-sha256sums https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/sha256sums

DUMB_INIT_CHECKSUM=$(sha256sum /usr/local/bin/dumb-init | cut -c 1-64)
DUMB_INIT_HASH=$(grep "dumb-init_${DUMB_INIT_VERSION}_amd64$" /tmp/dumb-init-sha256sums | cut -c 1-64)

if [[ $DUMB_INIT_CHECKSUM == $DUMB_INIT_HASH ]]; then
  echo "Valid checksum for dumb-init binary"
else
  echo "Invalid checksum for dumb-init binary"
  echo "binary: $DUMB_INIT_HASH"
  echo "checksum: $DUMB_INIT_CHECKSUM"
  exit 1
fi

rm -f /tmp/dumb-init-sha256sums
unset DUMB_INIT_CHECKSUM DUMB_INIT_HASH
