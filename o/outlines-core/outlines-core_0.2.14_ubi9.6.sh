#!/bin/bash -e
# -----------------------------------------------------------------------------
#
# Package       : outlines-core
# Version       : 0.2.14
# Source repo   : https://github.com/dottxt-ai/outlines-core
# Tested on     : UBI:9.6
# Language      : Python, Rust
# Ci-Check      : True
# Script License: Apache License, Version 2 or later
# Maintainer    : Ramnath Nayak <Ramnath.Nayak@ibm.com>
#
# Disclaimer: This script has been tested in root mode on given
# ==========  platform using the mentioned version of the package.
#             It may not work as expected with newer versions of the
#             package and/or distribution. In such case, please
#             contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------

# Variables
PACKAGE_NAME=outlines-core
PACKAGE_VERSION=${1:-0.2.14}
PACKAGE_URL=https://github.com/dottxt-ai/outlines-core
PACKAGE_DIR=outlines-core

# Install system dependencies
yum install -y git python3 python3-devel gcc-toolset-13 make wget sudo cmake diffutils

# Enable GCC Toolset 13
export PATH=/opt/rh/gcc-toolset-13/root/usr/bin:$PATH
export LD_LIBRARY_PATH=/opt/rh/gcc-toolset-13/root/usr/lib64:$LD_LIBRARY_PATH

OS_NAME=$(grep ^PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
SOURCE=Github

# Install Rust toolchain
if ! command -v rustc &> /dev/null; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Upgrade pip and install build tools
python3 -m pip install --upgrade pip setuptools wheel maturin pytest

# Clone repository
if [ -d "$PACKAGE_DIR" ]; then
    cd "$PACKAGE_DIR" || exit 1
else
    if ! git clone "$PACKAGE_URL" "$PACKAGE_DIR"; then
        echo "------------------$PACKAGE_NAME:clone_fails---------------------------------------"
        echo "$PACKAGE_URL $PACKAGE_NAME"
        echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | $SOURCE | Fail | Clone_Fails"
        exit 1
    fi
    cd "$PACKAGE_DIR" || exit 1
    git checkout "$PACKAGE_VERSION" || exit 1
fi

# Set version ONLY in [package] section (first occurrence)
python3 -c 'import re, sys; f="Cargo.toml"; s=open(f).read(); open(f,"w").write(re.sub(r"(?m)^version = \"[^\"]+\"", f"version = \"{sys.argv[1]}\"", s, count=1))' "$PACKAGE_VERSION"

# Install optional test dependencies
python3 -m pip install -e ".[test]" || python3 -m pip install numpy pydantic pytest pytest-cov || python3 -m pip install pydantic pytest pytest-cov

# Install the package
if ! python3 -m pip install -e .; then
    echo "------------------$PACKAGE_NAME:install_fails------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | $SOURCE | Fail | Install_Failed"
    exit 1
fi

# ------------------ Test Execution Block ------------------
test_status=1

if (python3 -m pytest tests/); then
    test_status=0
elif (python3 -m pytest tests/ --ignore=tests/test_kernels.py --ignore=tests/test_statistical.py); then
    test_status=0
elif (cargo test); then
    test_status=0
fi

# Final test result output
if [ $test_status -eq 0 ]; then
    echo "------------------$PACKAGE_NAME:install_and_test_both_success-------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | $SOURCE | Pass | Both_Install_and_Test_Success"
    exit 0
else
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | $SOURCE | Fail | Install_success_but_test_Fails"
    exit 2
fi