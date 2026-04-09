#!/bin/bash -e
# -----------------------------------------------------------------------------
#
# Package       : ml-metadata
# Version       : master
# Source repo   : https://github.com/google/ml-metadata.git
# Tested on     : UBI:9.6
# Language      : C++
# Ci-Check  : True
# Script License: Apache License, Version 2.0
# Maintainer    : Pankhudi Jain <Pankhudi.Jain@ibm.com>
#
# Disclaimer: This script has been tested in root mode on given
# ==========  platform using the mentioned version of the package.
#             It may not work as expected with newer versions of the
#             package and/or distribution. In such case, please
#             contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------
# Commit ID for master is: d3a70e909463a231d367270c9f3ef89cf39a1df4

set -ex

PACKAGE_URL=https://github.com/google/ml-metadata.git
PACKAGE_NAME=ml-metadata
PACKAGE_VERSION=${1:-master}
PACKAGE_DIR=ml-metadata

wdir=`pwd`
SCRIPT=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT)

#Install the dependencies
yum install -y autoconf automake cmake libtool zlib zlib-devel libjpeg libjpeg-devel gcc-toolset-13 python3.11 python3.11-pip python3.11-devel git wget unzip zip patch diffutils openssl-devel libffi-devel utf8proc tzdata
source /opt/rh/gcc-toolset-13/enable

yum install -y java-11-openjdk-devel
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p bazel
cd bazel
wget https://github.com/bazelbuild/bazel/releases/download/6.5.0/bazel-6.5.0-dist.zip
unzip bazel-6.5.0-dist.zip
env EXTRA_BAZEL_ARGS="--tool_java_runtime_version=local_jdk" bash ./compile.sh
cp output/bazel /usr/local/bin
export PATH="/usr/local/bin:$PATH"
bazel --version
cd "$wdir"

export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
python3.11 -m pip install --upgrade pip
python3.11 -m pip install numpy pytest

git clone $PACKAGE_URL
cd $PACKAGE_NAME/
wget https://raw.githubusercontent.com/ppc64le/build-scripts/master/m/ml-metadata/ml_metadata_ubi9.6.patch

#Fix HTML-escaped entities present IN THE PATCH ITSELF
sed -i \
  -e 's/&amp;/\&/g' \
  -e 's/&lt;/</g' \
  -e 's/&gt;/>/g' \
  ml_metadata_ubi9.6.patch

# Apply patch safely 
git apply ml_metadata_ubi9.6.patch --reject || true

#fix workspace
#Add PostgreSQL patch only if missing
if ! grep -q 'third_party:postgresql.patch' WORKSPACE; then
  sed -i '/name = "postgresql"/,/)/{
    /strip_prefix =/a\    patches = ["//ml_metadata/third_party:postgresql.patch"],
  }' WORKSPACE
fi

#Enable ZetaSQL patch if commented
if grep -q '#patches = \["//ml_metadata/third_party:zetasql.patch"\]' WORKSPACE; then
  sed -i 's/#patches = \["//ml_metadata\/third_party:zetasql.patch"\]/patches = ["\/\/ml_metadata\/third_party:zetasql.patch"]/' WORKSPACE
fi

export PYTHON_BIN_PATH=$(which python3.11)

if ! (python3.11 -m pip install .); then 
     echo "------------------$PACKAGE_NAME:Build_fails-------------------------------------"
     echo "$PACKAGE_URL $PACKAGE_NAME"
     echo "$PACKAGE_NAME  |  $PACKAGE_URL  | $PACKAGE_VERSION | GitHub | Fail |  Build_fails"
     exit 2;

elif ! pytest -vv; then
     echo "------------------$PACKAGE_NAME:Test_fails-------------------------------------"
     echo "$PACKAGE_URL $PACKAGE_NAME"
     echo "$PACKAGE_NAME  |  $PACKAGE_URL  | $PACKAGE_VERSION | GitHub | Fail |  Build_success_but_test_Fails"
     exit 1;

else
     echo "------------------$PACKAGE_NAME:Build_and_test_both_success-------------------------------------"
     echo "$PACKAGE_URL $PACKAGE_NAME"
     echo "$PACKAGE_NAME  |  $PACKAGE_URL  | $PACKAGE_VERSION | GitHub | Pass |  Both_Build_and_Test_Success"
     exit 0;
fi
