#! /bin/bash

# Copyright (c) 2016 Cliqz GmbH. All rights reserved.
# Authors: Lucian Corlaciu <lucian@cliqz.com>
#          Max Breev <maxim@cliqz.com>

# Required ENVs:
# WIN32_REDIST_DIR
# CQZ_GOOGLE_API_KEY or MOZ_GOOGLE_API_KEY
# CQZ_RELEASE_CHANNEL or MOZ_UPDATE_CHANNEL
# CQZ_CERT_DB_PATH
#
# Optional ENVs:
#  CQZ_BUILD_LOCALIZATION - for build DE localization

set -e
set -x

source cliqz_env.sh

cd $SRC_BASE

if $CLOBBER; then
  ./mach clobber
fi

# TODO: Use MOZ_GOOGLE_API_KEY directly instead of CQZ_GOOGLE_API_KEY.
if [ $CQZ_GOOGLE_API_KEY ]; then
  export MOZ_GOOGLE_API_KEY=$CQZ_GOOGLE_API_KEY  # --with-google-api-keyfile=...
fi

if [ $IS_WIN ]; then
  export MOZ_MEMORY=1  # --enable-jemalloc
fi

# TODO: Use MOZ_UPDATE_CHANNEL directly instead of CQZ_RELEASE_CHANNEL.
# Don't forget to update magic_upload_files.sh along with this one.
# --enable-update-channel=...
if [ -z $CQZ_RELEASE_CHANNEL ]; then
  export MOZ_UPDATE_CHANNEL=release
else
  export MOZ_UPDATE_CHANNEL=$CQZ_RELEASE_CHANNEL
fi

if [ -z "$LANG" ]; then
  LANG='en-US'
fi

# for localization repack
if [[ $IS_MAC_OS ]]; then
  export L10NBASEDIR=../../l10n  # --with-l10n-base=...
else
  export L10NBASEDIR=../l10n  # --with-l10n-base=...
fi

echo '***** Building *****'
./mach build

if [ $IS_WIN ]; then
  echo '***** Windows build installer *****'
  ./mach build installer
fi

echo '***** Packaging *****'
if [[ $IS_MAC_OS ]]; then
  MOZ_OBJDIR_BACKUP=$MOZ_OBJDIR
  unset MOZ_OBJDIR  # Otherwise some python script throws. Good job, Mozilla!
  make -C $OBJ_DIR package
  # Restore still useful variable we unset before.
  export MOZ_OBJDIR=$MOZ_OBJDIR_BACKUP
else
  ./mach package
fi

echo '***** Build DE language pack *****'
if [ $CQZ_BUILD_LOCALIZATION ]; then
  cd $OLDPWD
  cd $SRC_BASE/$MOZ_OBJDIR/browser/locales
  $MAKE merge-de LOCALE_MERGEDIR=$(PWD)/mergedir
  $MAKE installers-de LOCALE_MERGEDIR=$(PWD)/mergedir
fi

echo '***** Build & package finished successfully. *****'
cd $OLDPWD
