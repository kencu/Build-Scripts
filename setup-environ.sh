#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script verifies most prerequisites and creates
# an environment for other scripts to execute in.
# This script is executed multiple times during a build.
# Nearly every other script has to execute this script
# because Bash does not allow us to export arrays.

###############################################################################

# SC2034: XXX appears unused. Verify use (or export if used externally).
# shellcheck disable=SC2034

###############################################################################

# Can't apply the fixup reliably. Ancient Bash causes build scripts
# to die after setting the environment. TODO... figure it out.

# Fixup ancient Bash
# https://unix.stackexchange.com/q/468579/56041
#if [[ -z "$BASH_SOURCE" ]]; then
#    BASH_SOURCE="$0"
#fi

###############################################################################

# Prerequisites needed for nearly all packages. Set to false to skip check.

if [[ "$INSTX_DISABLE_PKGCONFIG_CHECK" -ne 1 ]]
then
    if [[ -z $(command -v pkg-config 2>/dev/null) ]]; then
        printf "%s\n" "Some packages require Package-Config. Please install pkg-config, pkgconfig or pkgconf."
        [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    printf "%s\n" "Some packages require Gzip. Please install Gzip."
    [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v tar 2>/dev/null) ]]; then
    printf "%s\n" "Some packages require Tar. Please install Tar."
    [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

# setup-cacerts.sh does not source the environment, so we can't use the
# variables in the setup-cacerts.sh script. Other scripts can use them.

LETS_ENCRYPT_ROOT="$HOME/.build-scripts/cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.build-scripts/cacert/identrust-root-x3.pem"
GO_DADDY_ROOT="$HOME/.build-scripts/cacert/godaddy-root-ca.pem"
DIGICERT_ROOT="$HOME/.build-scripts/cacert/digicert-root-ca.pem"
DIGITRUST_ROOT="$HOME/.build-scripts/cacert/digitrust-root-ca.pem"
GLOBALSIGN_ROOT="$HOME/.build-scripts/cacert/globalsign-root-r1.pem"
USERTRUST_ROOT="$HOME/.build-scripts/cacert/usertrust-root-ca.pem"
GITHUB_ROOT="$HOME/.build-scripts/cacert/github-ca-zoo.pem"

# Some downloads need the CA Zoo due to multiple redirects
CA_ZOO="$HOME/.build-scripts/cacert/cacert.pem"

###############################################################################

CURR_DIR=$(pwd)

# `gcc ... -o /dev/null` does not work on Solaris.
# `mktemp` is not available on AIX or Git Windows shell...
infile="in.$RANDOM$RANDOM.c"
outfile="out.$RANDOM$RANDOM"
cp programs/test-stdc.c "$infile"

function finish {
  rm  -f "$CURR_DIR/$infile" 2>/dev/null
  rm  -f "$CURR_DIR/$outfile" 2>/dev/null
  rm -rf "$CURR_DIR/$outfile.dSYM" 2>/dev/null
}
trap finish EXIT INT

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_HURD=$(grep -i -c 'gnu' <<< "$THIS_SYSTEM")
IS_LINUX=$(grep -i -c 'linux' <<< "$THIS_SYSTEM")
IS_SOLARIS=$(grep -i -c 'sunos' <<< "$THIS_SYSTEM")
IS_DARWIN=$(grep -i -c 'darwin' <<< "$THIS_SYSTEM")
IS_AIX=$(grep -i -c 'aix' <<< "$THIS_SYSTEM")
IS_CYGWIN=$(grep -i -c 'cygwin' <<< "$THIS_SYSTEM")
IS_OPENBSD=$(grep -i -c 'openbsd' <<< "$THIS_SYSTEM")
IS_FREEBSD=$(grep -i -c 'freebsd' <<< "$THIS_SYSTEM")
IS_NETBSD=$(grep -i -c 'netbsd' <<< "$THIS_SYSTEM")

THIS_SYSTEM=$(uname -v 2>&1)
IS_ALPINE=$(grep -i -c 'alpine' <<< "$THIS_SYSTEM")

###############################################################################

GREP="${GREP:-"$(command -v grep)"}"
EGREP="${EGREP:-"$(command -v grep) -E"}"
SED="${SED:-"$(command -v sed)"}"
AWK="${AWK:-"$(command -v awk)"}"

# Non-anemic tools on Solaris
if [[ -d /usr/gnu/bin ]]; then
    GREP="/usr/gnu/bin/grep"
    EGREP="/usr/gnu/bin/grep -E"
    SED="/usr/gnu/bin/sed"
    AWK="/usr/gnu/bin/awk"
elif [[ -d /usr/sfw/bin ]]; then
    GREP="/usr/sfw/bin/grep"
    EGREP="/usr/sfw/bin/grep -E"
    SED="/usr/sfw/bin/sed"
    AWK="/usr/sfw/bin/awk"
fi

# Wget is special. We have to be able to bootstrap it and
# use a modern version throughout these scripts. The Wget
# we provide in $HOME is modern but crippled. However, it
# is enough to download all the packages we need.

if [[ -z "$WGET" ]]; then
    if [[ -e "$HOME/.build-scripts/wget/bin/wget" ]]; then
        WGET="$HOME/.build-scripts/wget/bin/wget"
    elif [[ -e "/usr/local/bin/wget" ]]; then
        WGET="/usr/local/bin/wget"
    elif [[ -n "$(command -v wget)" ]]; then
        WGET="$(command -v wget)"
    else
        WGET=wget
    fi
fi

export WGET

###############################################################################

# Paths are awful on Solaris. An unmodified environment only
# has /usr/bin and /usr/sbin with anemic tools.
if [ "$IS_SOLARIS" -ne 0 ]
then
    for path in /usr/gnu/bin /usr/sfw/bin /usr/ucb/bin /usr/xpg4/bin /bin /usr/bin /sbin /usr/sbin
    do
        if [ -d "$path" ]; then
            SOLARIS_PATH="$SOLARIS_PATH:$path"
        fi
    done

    # Add user's path in case a binary is in a non-standard location,
    # like /opt/local. Place the PATH after SOLARIS_PATH so the anemic
    # tools are last in the list.
    PATH="$SOLARIS_PATH:$PATH"
fi

# Strip leading, duplicate and trailing colons
PATH=$(echo "$PATH" | tr -s ':' | $SED -e 's/^:\(.*\)/\1/' | $SED -e 's/:$//g')
export PATH

# echo "New PATH: $PATH"

###############################################################################

# Check for the BSD family members
IS_BSD_FAMILY=$(${EGREP} -i -c 'dragonfly|freebsd|netbsd|openbsd' <<< "$THIS_SYSTEM")

# Red Hat and derivatives use /lib64, not /lib.
IS_REDHAT=$($GREP -i -c 'redhat' /etc/redhat-release 2>/dev/null)
IS_CENTOS=$($GREP -i -c 'centos' /etc/centos-release 2>/dev/null)
IS_FEDORA=$($GREP -i -c 'fedora' /etc/fedora-release 2>/dev/null)
IS_DRAGONFLY=$(uname -s | $GREP -i -c DragonFly 2>/dev/null)

OSX_VERSION=$(system_profiler SPSoftwareDataType 2>&1 | ${GREP} 'System Version:' | ${AWK} '{print $6}')
OSX_1010_OR_ABOVE=$(printf "%s" "$OSX_VERSION" | ${EGREP} -i -c "(^10.10|^1[1-9].|^[2-9][0-9])")

if [[ "$IS_REDHAT" -ne 0 || "$IS_CENTOS" -ne 0 || "$IS_FEDORA" -ne 0 ]]
then
    IS_RH_FAMILY=1
else
    IS_RH_FAMILY=0
fi

# Fix decades old compile and link errors on early Darwin.
# https://gmplib.org/list-archives/gmp-bugs/2009-May/001423.html
IS_OLD_DARWIN=$(system_profiler SPSoftwareDataType 2>/dev/null | ${EGREP} -i -c "OS X 10\.[0-5]")

THIS_MACHINE=$(uname -m 2>&1)
IS_IA32=$(${EGREP} -i -c 'i86pc|i.86|amd64|x86_64' <<< "$THIS_MACHINE")
IS_AMD64=$(${EGREP} -i -c 'amd64|x86_64' <<< "$THIS_MACHINE")
IS_MIPS=$(${EGREP} -i -c 'mips' <<< "$THIS_MACHINE")

# The BSDs and Solaris should have GMake installed if its needed
if [[ -z "${MAKE}" ]]; then
    if [[ $(command -v gmake 2>/dev/null) ]]; then
        MAKE="gmake"
    else
        MAKE="make"
    fi
fi

# Fix "don't know how to make w" on the BSDs
if [[ "${MAKE}" == "make" ]]; then
    MAKEOPTS=
fi

export MAKE
export MAKEOPTS

# If CC and CXX are not set, then use default or assume GCC, except on Darwin
if [[ "$IS_DARWIN" -ne 0 ]]; then
    if [[ -z "${CC}" ]] && [[ -n "$(command -v clang)" ]]; then CC='clang'; fi
    if [[ -z "${CXX}" ]] && [[ -n "$(command -v clang++)" ]]; then CXX='clang++'; fi
fi
if [[ -z "${CC}" ]] && [[ -n "$(command -v gcc)" ]]; then CC='gcc'; fi
if [[ -z "${CC}" ]] && [[ -n "$(command -v cc)" ]]; then CC='cc'; fi
if [[ -z "${CXX}" ]] && [[ -n "$(command -v g++)" ]]; then CXX='g++'; fi
if [[ -z "${CXX}" ]] && [[ -n "$(command -v CC)" ]]; then CXX='CC'; fi

export CC
export CXX

IS_GCC=$(${CC} --version 2>&1 | ${GREP} -i -c 'gcc')
IS_CLANG=$(${CC} --version 2>&1 | ${EGREP} -i -c 'clang|llvm')
IS_SUNC=$(${CC} -V 2>&1 | ${EGREP} -i -c 'sun|studio')

TEST_CC="${CC}"
TEST_CXX="${CXX}"

# Where the package will run. We need to override for 64-bit Solaris.
# On Solaris some Autotools packages use 32-bit instead of 64-bit build.
AUTOCONF_BUILD=$(bash programs/config.guess 2>/dev/null)

###############################################################################

# Use 64-bit for Solaris if available
# https://docs.oracle.com/cd/E37838_01/html/E66175/features-1.html

if [[ "$IS_SOLARIS" -ne 0 ]]
then
    if [[ $(isainfo -b 2>/dev/null) = 64 ]]; then
        CFLAGS64=-m64
        CXXFLAGS64=-m64
        TEST_CC="${TEST_CC} -m64"
        TEST_CXX="${TEST_CXX} -m64"
    fi
fi

IS_SUN_AMD64=$(isainfo -v 2>/dev/null | ${EGREP} -i -c 'amd64')
IS_SUN_SPARCv9=$(isainfo -v 2>/dev/null | ${EGREP} -i -c 'sparcv9')

# Solaris Fixup
if [[ "$IS_SUN_AMD64" -eq 1 ]]; then
    IS_AMD64=1
    AUTOCONF_BUILD=$($SED 's/i386/x86_64/g' <<< "$AUTOCONF_BUILD")
elif [[ "$IS_SUN_SPARCv9" -eq 1 ]]; then
    AUTOCONF_BUILD=$($SED 's/sparc/sparcv9/g' <<< "$AUTOCONF_BUILD")
fi

###############################################################################

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32,
# /usr/local/lib64 and /usr/local/lib/64. We drive a test compile
# using the supplied compiler and flags.
if ${TEST_CC} ${CFLAGS} programs/test-64bit.c -o "$outfile" &>/dev/null
then
    IS_64BIT=1
    IS_32BIT=0
    INSTX_BITNESS=64
else
    IS_64BIT=0
    IS_32BIT=1
    INSTX_BITNESS=32
fi

# Some of the BSDs install user software into /usr/local.
# We don't want to overwrite the system installed software.
if [[ "$IS_BSD_FAMILY" -ne 0 ]]; then
    DEF_PREFIX="/opt/local"
else
    DEF_PREFIX="/usr/local"
fi

# Don't override a user choice of INSTX_PREFIX
if [[ -z "$INSTX_PREFIX" ]]; then
    INSTX_PREFIX="$DEF_PREFIX"
fi

# RPATH's and their history at https://lekensteyn.nl/rpath.html.
# $ORIGIN on Linux should be available back to about 1998.
# We feature test for INSTX_OPATH and INSTX_RPATH below.
# AIX also needs -bsvr4; while HP-UX uses -Wl,+b.

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    DEF_LIBDIR="$INSTX_PREFIX/lib"
    DEF_RPATH="$INSTX_PREFIX/lib"
    DEF_OPATH="'""\$ORIGIN/../lib""'"
elif [[ "$IS_DARWIN" -ne 0 ]]; then
    DEF_LIBDIR="$INSTX_PREFIX/lib"
    DEF_RPATH="$INSTX_PREFIX/lib"
    DEF_OPATH="@loader_path/../lib"
elif [[ "$IS_RH_FAMILY" -ne 0 ]] && [[ "$IS_64BIT" -ne 0 ]]; then
    DEF_LIBDIR="$INSTX_PREFIX/lib64"
    DEF_RPATH="$INSTX_PREFIX/lib64"
    DEF_OPATH="'""\$ORIGIN/../lib64""'"
else
    DEF_LIBDIR="$INSTX_PREFIX/lib"
    DEF_RPATH="$INSTX_PREFIX/lib"
    DEF_OPATH="'""\$ORIGIN/../lib""'"
fi

# Don't override a user choice of INSTX_LIBDIR. Also see
# https://blogs.oracle.com/dipol/dynamic-libraries,-rpath,-and-mac-os
if [[ -z "$INSTX_LIBDIR" ]]; then
    INSTX_LIBDIR="$DEF_LIBDIR"
fi
if [[ -z "$INSTX_RPATH" ]]; then
    INSTX_RPATH="$DEF_RPATH"
fi
if [[ -z "$INSTX_OPATH" ]]; then
    INSTX_OPATH="$DEF_OPATH"
fi

# Remove duplicate and trailing slashes.
INSTX_PREFIX="$(echo ${INSTX_PREFIX} | tr -s '/' | $SED -e 's/\/$//g')"
INSTX_LIBDIR="$(echo ${INSTX_LIBDIR} | tr -s '/' | $SED -e 's/\/$//g')"
INSTX_RPATH="$(echo ${INSTX_RPATH} | tr -s '/' | $SED -e 's/\/$//g')"
INSTX_OPATH="$(echo ${INSTX_OPATH} | tr -s '/' | $SED -e 's/\/$//g')"

export INSTX_PREFIX
export INSTX_LIBDIR
export INSTX_RPATH
export INSTX_OPATH

# Add our path since we know we are using the latest binaries.
# Strip leading, duplicate and trailing colons
PATH=$(echo "$INSTX_PREFIX/bin:$PATH" | tr -s ':' | $SED -e 's/^:\(.*\)/\1/' | $SED -e 's/:$//g')
export PATH

###############################################################################

CC_RESULT=$(${TEST_CC} -fPIC -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_PIC="-fPIC"
fi

# Ugh... C++11 support as required. Things may still break.
CC_RESULT=$(${TEST_CXX} -o "$outfile" programs/test-cxx11.cpp 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    INSTX_CXX11=1
else
    CC_RESULT=$(${TEST_CXX} -std=gnu++11 -o "$outfile" programs/test-cxx11.cpp 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_CXX11="-std=gnu++11"
        INSTX_CXX11=1
    else
        CC_RESULT=$(${TEST_CXX} -std=c++11 -o "$outfile" programs/test-cxx11.cpp 2>&1 | wc -w)
        if [[ "$CC_RESULT" -eq 0 ]]; then
            OPT_CXX11="-std=c++11"
            INSTX_CXX11=1
        fi
    fi
fi

# Ugh... C++14 support as required. Things may still break.
CC_RESULT=$(${TEST_CXX} -o "$outfile" programs/test-cxx14.cpp 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    INSTX_CXX14=1
else
    CC_RESULT=$(${TEST_CXX} -std=gnu++14 -o "$outfile" programs/test-cxx14.cpp 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_CXX14="-std=gnu++14"
        INSTX_CXX14=1
    else
        CC_RESULT=$(${TEST_CXX} -std=c++14 -o "$outfile" programs/test-cxx14.cpp 2>&1 | wc -w)
        if [[ "$CC_RESULT" -eq 0 ]]; then
            OPT_CXX14="-std=c++14"
            INSTX_CXX14=1
        fi
    fi
fi

# patchelf needs C++11 support
# echo "INSTX_CXX11: $INSTX_CXX11"
INSTX_CXX11="${INSTX_CXX11:-0}"
INSTX_CXX14="${INSTX_CXX14:-0}"
export INSTX_CXX11
export INSTX_CXX14

# For the benefit of the programs and libraries. Make them run faster.
CC_RESULT=$(${TEST_CC} -march=native -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_NATIVE="-march=native"
fi

# PowerMac's with 128-bit long double. Gnulib and GetText expect 64-bit long double.
CC_RESULT=$(${TEST_CC} -o "$outfile" programs/test-128bit-double.c 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    if [[ $("./$outfile") == "106" ]]; then
        OPT_64BIT_DBL="-mlong-double-64"
    fi
fi

CC_RESULT=$(${TEST_CC} -pthread -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_PTHREAD="-pthread"
fi

# Switch from -march=native to something more appropriate
if [[ $($EGREP -i -c 'armv7' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    CC_RESULT=$(${TEST_CC} -march=armv7-a -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_ARMV7="-march=armv7-a"
    fi
fi
# See if we can upgrade to ARMv7+NEON
if [[ $($EGREP -i -c 'neon' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    CC_RESULT=$(${TEST_CC} -march=armv7-a -mfpu=neon -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        IS_ARM_NEON=1
        OPT_ARMV7="-march=armv7-a -mfpu=neon"
    fi
fi
# See if we can upgrade to ARMv8
if [[ $(uname -m 2>&1 | ${EGREP} -i -c 'aarch32|aarch64') -ne 0 ]]; then
    CC_RESULT=$(${TEST_CC} -march=armv8-a -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_ARMV8="-march=armv8-a"
    fi
fi

# See if -Wl,-rpath,$ORIGIN/../lib works
CC_RESULT=$(${TEST_CC} -Wl,-rpath,$INSTX_OPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_OPATH="-Wl,-rpath,$INSTX_OPATH"
fi
CC_RESULT=$(${TEST_CC} -Wl,-R,$INSTX_OPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_OPATH="-Wl,-R,$INSTX_OPATH"
fi
CC_RESULT=$(${TEST_CC} -Wl,-R,$INSTX_OPATH -bsvr4 -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_OPATH="-Wl,-R,$INSTX_OPATH -bsvr4"
fi
CC_RESULT=$(${TEST_CC} -Wl,+b,$INSTX_OPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_OPATH="-Wl,+b,$INSTX_OPATH"
fi

# See if -Wl,-rpath,${libdir} works.
CC_RESULT=$(${TEST_CC} -Wl,-rpath,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_RPATH="-Wl,-rpath,$INSTX_RPATH"
fi
CC_RESULT=$(${TEST_CC} -Wl,-R,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_RPATH="-Wl,-R,$INSTX_RPATH"
fi
CC_RESULT=$(${TEST_CC} -Wl,-R,$INSTX_RPATH -bsvr4 -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_RPATH="-Wl,-R,$INSTX_RPATH -bsvr4"
fi
CC_RESULT=$(${TEST_CC} -Wl,+b,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_RPATH="-Wl,+b,$INSTX_RPATH"
fi

# See if RUNPATHs are available. new-dtags convert a RPATH to a RUNPATH.
CC_RESULT=$(${TEST_CC} -Wl,--enable-new-dtags -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_NEW_DTAGS="-Wl,--enable-new-dtags"
fi

# http://www.sco.com/developers/gabi/latest/ch5.dynamic.html#shobj_dependencies
CC_RESULT=$(${TEST_CC} ${OPT_OPATH} -Wl,-z,origin -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_ORIGIN="-Wl,-z,origin"
fi

CC_RESULT=$(${TEST_CC} -fopenmp -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_OPENMP="-fopenmp"
fi

CC_RESULT=$(${TEST_CC} -Wl,--no-as-needed -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_NO_AS_NEEDED="-Wl,--no-as-needed"
fi

# OS X linker and install names
CC_RESULT=$(${TEST_CC} -headerpad_max_install_names -o "$outfile" "$infile" 2>&1 | wc -w)
if [[ "$CC_RESULT" -eq 0 ]]; then
    OPT_INSTNAME="-headerpad_max_install_names"
fi

# Debug symbols
if [[ -z "$OPT_SYM" ]]; then
    CC_RESULT=$(${TEST_CC} -g2 -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_SYM="-g2"
    else
        CC_RESULT=$(${TEST_CC} -g -o "$outfile" "$infile" 2>&1 | wc -w)
        if [[ "$CC_RESULT" -eq 0 ]]; then
            OPT_SYM="-g"
        fi
    fi
fi

# Optimizations symbols
if [[ -z "$OPT_OPT" ]]; then
    CC_RESULT=$(${TEST_CC} -O2 -o "$outfile" "$infile" 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_OPT="-O2"
    else
        CC_RESULT=$(${TEST_CC} -O -o "$outfile" "$infile" 2>&1 | wc -w)
        if [[ "$CC_RESULT" -eq 0 ]]; then
            OPT_OPT="-O"
        fi
    fi
fi

# OpenBSD does not have -ldl
if [[ -z "$OPT_DL" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -ldl 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_DL="-ldl"
    fi
fi

if [[ -z "$OPT_LIBPTHREAD" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -lpthread 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_LIBPTHREAD="-lpthread"
    fi
fi

# -fno-sanitize-recover causes an abort(). Useful for test
# programs that swallow UBsan output and pretty print "OK"
if [[ -z "$OPT_SAN_NORECOVER" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -fsanitize=undefined -fno-sanitize-recover=all 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_SAN_NORECOVER="-fno-sanitize-recover=all"
    else
        CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -fsanitize=undefined -fno-sanitize-recover 2>&1 | wc -w)
        if [[ "$CC_RESULT" -eq 0 ]]; then
            OPT_SAN_NORECOVER="-fno-sanitize-recover"
        fi
    fi
fi

# Msan option
if [[ -z "$OPT_MSAN_ORIGIN" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -fsanitize-memory-track-origins 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_MSAN_ORIGIN=1
    fi
fi

# GOT and PLT hardening
if [[ -z "$OPT_RELRO" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -Wl,-z,relro 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_RELRO="-Wl,-z,relro"
    fi
fi

if [[ -z "$OPT_NOW" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -Wl,-z,now 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_NOW="-Wl,-z,now"
    fi
fi

# NX stacks
if [[ -z "$OPT_AS_NXSTACK" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -Wa,--noexecstack 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_AS_NXSTACK="-Wa,--noexecstack"
    fi
fi

if [[ -z "$OPT_LD_NXSTACK" ]]; then
    CC_RESULT=$(${TEST_CC} -o "$outfile" "$infile" -Wl,-z,noexecstack 2>&1 | wc -w)
    if [[ "$CC_RESULT" -eq 0 ]]; then
        OPT_LD_NXSTACK="-Wl,-z,noexecstack"
    fi
fi

###############################################################################

# CA cert path? Also see http://gagravarr.org/writing/openssl-certs/others.shtml
# For simplicity use $INSTX_PREFIX/etc/pki. Avoid about 10 different places.

OPT_CACERT_PATH="$INSTX_PREFIX/etc/pki"
OPT_CACERT_FILE="$INSTX_PREFIX/etc/pki/cacert.pem"
OPT_UNBOUND_ROOTKEY_PATH="$INSTX_PREFIX/etc/unbound"
OPT_UNBOUND_ROOTKEY_FILE="$INSTX_PREFIX/etc/unbound/root.key"
OPT_UNBOUND_ICANN_PATH="$INSTX_PREFIX/etc/unbound"
OPT_UNBOUND_ICANN_FILE="$INSTX_PREFIX/etc/unbound/icannbundle.pem"

###############################################################################

INSTX_PKGCONFIG=("$INSTX_LIBDIR/pkgconfig")
INSTX_CPPFLAGS=("-I$INSTX_PREFIX/include" "-DNDEBUG")
INSTX_CFLAGS=("$OPT_SYM" "$OPT_OPT")
INSTX_CXXFLAGS=("$OPT_SYM" "$OPT_OPT")
INSTX_LDFLAGS=("-L$INSTX_LIBDIR")
INSTX_LIBS=()

if [[ -n "$CFLAGS64" ]]
then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$CFLAGS64"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$CFLAGS64"
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$CFLAGS64"
fi

if [[ -n "$OPT_64BIT_DBL" ]]
then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_64BIT_DBL"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_64BIT_DBL"
fi

if [[ -n "$INSTX_UBSAN" ]]; then
    INSTX_CPPFLAGS[${#INSTX_CPPFLAGS[@]}]="-DTEST_UBSAN=1"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fsanitize=undefined"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fsanitize=undefined"
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="-fsanitize=undefined"

    if [[ -n "$OPT_SAN_NORECOVER" ]]; then
        INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_SAN_NORECOVER"
        INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_SAN_NORECOVER"
        INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_SAN_NORECOVER"
    fi

elif [[ -n "$INSTX_ASAN" ]]; then
    INSTX_CPPFLAGS[${#INSTX_CPPFLAGS[@]}]="-DTEST_ASAN=1"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fsanitize=address"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fno-omit-frame-pointer"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fsanitize=address"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fno-omit-frame-pointer"
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="-fsanitize=address"

# Requires GCC 10, like on Fedora 32
elif [[ -n "$INSTX_ANALYZE" ]]; then
    INSTX_CPPFLAGS[${#INSTX_CPPFLAGS[@]}]="-DTEST_ANALYZE=1"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fanalyzer"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fno-omit-frame-pointer"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fanalyzer"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fno-omit-frame-pointer"
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="-fanalyzer"

elif [[ -n "$INSTX_MSAN" ]]; then
    INSTX_CPPFLAGS[${#INSTX_CPPFLAGS[@]}]="-DTEST_MSAN=1"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fsanitize=memory"
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fno-omit-frame-pointer"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fsanitize=memory"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fno-omit-frame-pointer"
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="-fsanitize=memory"
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="-fno-omit-frame-pointer"

    if [[ -n "$OPT_MSAN_ORIGIN" ]]; then
        INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="-fsanitize-memory-track-origins"
        INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="-fsanitize-memory-track-origins"
        INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="-fsanitize-memory-track-origins"
    fi
fi

if [[ -n "$OPT_ARMV8" ]]; then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_ARMV8"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_ARMV8"
elif [[ -n "$OPT_ARMV7" ]]; then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_ARMV7"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_ARMV7"
elif [[ -n "$OPT_NATIVE" ]]; then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_NATIVE"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_NATIVE"
fi

if [[ -n "$OPT_PIC" ]]; then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_PIC"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_PIC"
fi

if [[ -n "$OPT_PTHREAD" ]]; then
    INSTX_CFLAGS[${#INSTX_CFLAGS[@]}]="$OPT_PTHREAD"
    INSTX_CXXFLAGS[${#INSTX_CXXFLAGS[@]}]="$OPT_PTHREAD"
fi

if [[ -n "$OPT_AS_NXSTACK" ]]; then
    INSTX_ASFLAGS[${#INSTX_ASFLAGS[@]}]="$OPT_AS_NXSTACK"
fi

if [[ -n "$OPT_OPATH" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_OPATH"
fi

if [[ -n "$OPT_RPATH" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_RPATH"
fi

if [[ -n "$OPT_NEW_DTAGS" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_NEW_DTAGS"
fi

if [[ -n "$OPT_RELRO" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_RELRO"
fi

if [[ -n "$OPT_NOW" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_NOW"
fi

if [[ -n "$OPT_LD_NXSTACK" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_LD_NXSTACK"
fi

if [[ -n "$OPT_ORIGIN" ]]; then
    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_ORIGIN"
fi

if [[ -n "$OPT_DL" ]]; then
    INSTX_LIBS[${#INSTX_LIBS[@]}]="$OPT_DL"
fi

if [[ -n "$OPT_LIBPTHREAD" ]]; then
    INSTX_LIBS[${#INSTX_LIBS[@]}]="$OPT_LIBPTHREAD"
fi

#if [[ "$IS_DARWIN" -ne 0 ]] && [[ -n "$OPT_INSTNAME" ]]; then
#    INSTX_LDFLAGS+=("$OPT_INSTNAME")
#    INSTX_LDFLAGS[${#INSTX_LDFLAGS[@]}]="$OPT_INSTNAME"
#fi

if [[ -n "$INSTX_ASAN" ]]; then
    # Too many GNU programs and libraries leak
    echo "Disabling ASAN leak detection"
    ASAN_OPTIONS=detect_leaks=0
    export ASAN_OPTIONS
fi

# Used to track packages that have been built by these scripts.
# The accounting is local to a user account. There is no harm
# in rebuilding a package under another account. In April 2019
# we added INSTX_PREFIX so we could build packages in multiple
# locations. For example, /usr/local for updated packages, and
# /var/sanitize for testing packages.
if [[ -z "$INSTX_PKG_CACHE" ]]; then
    # Change / to - for CACHE_DIR
    CACHE_DIR=$(cut -c 2- <<< "$INSTX_PREFIX" | ${SED} 's/\//-/g')
    INSTX_PKG_CACHE="$HOME/.build-scripts/$CACHE_DIR"
    mkdir -p "$INSTX_PKG_CACHE"
fi

export INSTX_PKG_CACHE

###############################################################################

# If the package is older than 7 days, then rebuild it. This sidesteps the
# problem of continually rebuilding the same package when installing a
# program like Git and SSH. It also avoids version tracking by automatically
# building a package after 7 days (even if it is the same version).
IFS="" find "$INSTX_PKG_CACHE" -type f -mtime +7 -print | while read -r pkg
do
    # printf "Setting %s for rebuild\n" "$pkg"
    rm -f "$pkg" 2>/dev/null
done

###############################################################################

# Print a summary once
if [[ -z "$PRINT_ONCE" ]]; then

    if [[ "$IS_SOLARIS" -ne 0 ]]; then
        printf "\n"
        printf "%s\n" "Solaris tools:"
        printf "\n"
        printf "%s\n" "     sed: $(command -v sed)"
        printf "%s\n" "     awk: $(command -v awk)"
        printf "%s\n" "    grep: $(command -v grep)"
        if [[ -n "$LEX" ]]; then
            printf "%s\n" "     lex: $LEX"
        else
            printf "%s\n" "     lex: $(command -v lex)"
            printf "%s\n" "    flex: $(command -v flex)"
        fi
        if [[ -n "$YACC" ]]; then
            printf "%s\n" "     lex: $YACC"
        else
            printf "%s\n" "    yacc: $(command -v yacc)"
            printf "%s\n" "   bison: $(command -v bison)"
        fi
    fi

    printf "\n"
    printf "%s\n" "Common flags and options:"
    printf "\n"
    printf "%s\n" "  INSTX_BITNESS: $INSTX_BITNESS-bits"
    printf "%s\n" "   INSTX_PREFIX: $INSTX_PREFIX"
    printf "%s\n" "   INSTX_LIBDIR: $INSTX_LIBDIR"
    printf "%s\n" "    INSTX_OPATH: $INSTX_OPATH"
    printf "%s\n" "    INSTX_RPATH: $INSTX_RPATH"
    printf "\n"
    printf "%s\n" " AUTOCONF_BUILD: $AUTOCONF_BUILD"
    printf "%s\n" "PKG_CONFIG_PATH: ${INSTX_PKGCONFIG[*]}"
    printf "%s\n" "       CPPFLAGS: ${INSTX_CPPFLAGS[*]}"

    if [[ "${#INSTX_ASFLAGS[@]}" -ne 0 ]]; then
        printf "%s\n" "        ASFLAGS: ${INSTX_ASFLAGS[*]}"
    fi

    printf "%s\n" "         CFLAGS: ${INSTX_CFLAGS[*]}"
    printf "%s\n" "       CXXFLAGS: ${INSTX_CXXFLAGS[*]}"
    printf "%s\n" "        LDFLAGS: ${INSTX_LDFLAGS[*]}"
    printf "%s\n" "         LDLIBS: ${INSTX_LIBS[*]}"
    printf "\n"

    printf "%s\n" "   CC: $(command -v $CC)"
    printf "%s\n" "  CXX: $(command -v $CXX)"
    printf "%s\n" " WGET: $WGET"
    printf "\n"

    if [[ -n "$OPT_CACERT_PATH" ]]; then
        printf " OPT_CACERT_PATH: %s\n" "$OPT_CACERT_PATH"
    fi
    if [[ -n "$OPT_CACERT_FILE" ]]; then
        printf " OPT_CACERT_FILE: %s\n" "$OPT_CACERT_FILE"
    fi

    export PRINT_ONCE="TRUE"
fi

[[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
