#!/bin/bash -euo pipefail

# derived/consolidated from
# https://blog.twitch.tv/ios-versioning-89e02f0a5146

#####

# When we increment TOR_BUNDLE_SHORT_VERSION_STRING
# also update TOR_BUNDLE_SHORT_VERSION_DATE to the current date/time
# we don't have to be very exact, but it should be updated at least
# once every 18 months because iTunes requires that a CFBundleVersion
# be at most 18 characters long, and DECIMALIZED_GIT_HASH will be
# at most 10 characters long. Thus, MINUTES_SINCE_DATE needs to be
# at most 7 characters long so we can use the format:
# ${MINUTES_SINCE_DATE}.${DECIMALIZED_GIT_HASH}

# the version for this framework is roughly in the format of:
# ABB.C.Y, where the tor version is 0.A.B.C ("BB" is two-digit B slot
# with leading zero if necessary) and Y is an incremental tor.framework version.
# so the first tor 0.3.5.2-alpha is 305.2.1

# BUGFIX: Don't use dates with localized month names, because that breaks building
# on non-english localized systems. Instead stick to an international format.
TOR_BUNDLE_SHORT_VERSION_DATE="2019-07-22 14:30:00 GMT"
TOR_BUNDLE_SHORT_VERSION_STRING=400.5.2

#####

BASH_SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#####
# minutes_since_date
SECONDS_FROM_EPOCH_TO_NOW=$( date "+%s" )
SECONDS_FROM_EPOCH_TO_DATE=$( date -j -f "%Y-%m-%d %H:%M:%S %Z" "${TOR_BUNDLE_SHORT_VERSION_DATE}" "+%s" )

MINUTES_SINCE_DATE=$(( $(( ${SECONDS_FROM_EPOCH_TO_NOW}-${SECONDS_FROM_EPOCH_TO_DATE} ))/60 ))

#####
# decimalize git hash

# decimalized git hash is guaranteed to be 10 characters or fewer because
# the biggest short=7 git hash we can get is FFFFFFF and
# $ ./decimalize_git_hash.bash FFFFFFF | wc -c
# is > 10

# We must prefix the git hash with a 1
# If it starts with a zero, when we decimalize it,
# and later hexify it, we'll lose the zero.
ONE_PREFIXED_GIT_HASH=1"$( git rev-parse --short=7 HEAD )"

# bc requires hex to be uppercase because
# lowercase letters are reserved for bc variables
UPPERCASE_ONE_PREFIXED_GIT_HASH=$( echo "${ONE_PREFIXED_GIT_HASH}" | tr "[:lower:]" "[:upper:]" )

# convert to decimal
# See "with bc": http://stackoverflow.com/a/13280173/9636
DECIMALIZED_GIT_HASH=$(echo "ibase=16;obase=A;${UPPERCASE_ONE_PREFIXED_GIT_HASH}" | bc)

#####

#echo "Decimalized: \"${DECIMALIZED_GIT_HASH}\""

TOR_BUNDLE_VERSION="${MINUTES_SINCE_DATE}"."${DECIMALIZED_GIT_HASH}"

echo $TOR_BUNDLE_SHORT_VERSION_STRING
echo $TOR_BUNDLE_VERSION

cat <<EOF > "${SRCROOT}"/Tor/version.h
#define TorBundleShortVersionString ${TOR_BUNDLE_SHORT_VERSION_STRING}
#define TorBundleVersion ${TOR_BUNDLE_VERSION}
EOF
