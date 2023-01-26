#!/bin/bash

set -e
set -u

if [[ ! -d "$1" ]]; then
  echo "Please provide a target folder path as the first parameter"
  exit 1
fi

TARGET=$(realpath "$1")
ENVIRONMENTS=("tt02" "prod")

mkdir -p "$1/.cache"

function get_deployments {
  local ORG="$1"
  local ENV_KEY="$2"
  local DEPLOYMENTS_FILE="$TARGET/.cache/deployments-$ORG-$ENV_KEY.json"
  local URL

  if [[ "$ENV_KEY" == "prod" ]]; then
    URL="https://$ORG.apps.altinn.no/kuberneteswrapper/api/v1/deployments"
  else
    URL="https://$ORG.apps.$ENV_KEY.altinn.no/kuberneteswrapper/api/v1/deployments"
  fi

  download_file_if_old "$DEPLOYMENTS_FILE" "$URL" "deployments for $ORG (in $ENV_KEY)"
  jq -r '.[] | .release + " " + .version' "$DEPLOYMENTS_FILE" | grep -v kuberneteswrapper
}

function get_release() {
  local ORG="$1"
  local APP="$2"
  local VERSION="$3"
  local URL_PROD="https://altinn.studio/designer/api/v1/$ORG/$APP/releases"
  local URL_DEV="https://dev.altinn.studio/designer/api/v1/$ORG/$APP/releases"
  local CACHE_PROD="$TARGET/.cache/releases-prod-$ORG-$APP.json"
  local CACHE_DEV="$TARGET/.cache/releases-dev-$ORG-$APP.json"
  local FOUND
  local REPO

  download_file_if_old "$CACHE_PROD" "$URL_PROD" "releases for $ORG/$APP"

  FOUND=$(jq -r '.results[] | (.tagName + " " + .targetCommitish)' "$CACHE_PROD" | grep "^$VERSION " | head -n 1 | awk '{print $2}')
  REPO="https://altinn.studio/repos/$ORG/$APP.git"
  if test -z "$FOUND"; then
    download_file_if_old "$CACHE_DEV" "$URL_DEV" "releases for $ORG/$APP (in dev)"
    FOUND=$(jq -r '.results[] | (.tagName + " " + .targetCommitish)' "$CACHE_DEV" | grep "^$VERSION " | head -n 1 | awk '{print $2}')
    REPO="https://dev.altinn.studio/repos/$ORG/$APP.git"
  fi

  echo "$REPO" "$FOUND"
}

function download_file_if_old {
  local FILE_PATH="$1"
  local URL="$2"
  local DESCRIPTION="$3"

  if test -e "$FILE_PATH"; then
    FILE_AGE=$(($(date +%s) - $(stat -c '%Y' "$FILE_PATH")))
    if test "$FILE_AGE" -gt "3600"; then
      >&2 echo " * Loading $DESCRIPTION"
      curl -s "$URL" > "$FILE_PATH"
    fi
  else
    >&2 echo " * Loading $DESCRIPTION"
    curl -s "$URL" > "$FILE_PATH"
  fi
}

curl -s https://altinncdn.no/orgs/altinn-orgs.json | jq '.orgs | keys[]' | sed 's/"//g' | while read -r ORG; do
  for ENV_KEY in "${ENVIRONMENTS[@]}"; do
    get_deployments "$ORG" "$ENV_KEY" | while read -r line; do
      APP=$(echo "$line" | awk '{print $1}' | sed "s/^$ORG-//")
      VERSION=$(echo "$line" | awk '{print $2}')
      RELEASE=$(get_release "$ORG" "$APP" "$VERSION")
      REPO=$(echo "$RELEASE" | awk '{print $1}')
      COMMIT=$(echo "$RELEASE" | awk '{print $2}')

      FULL_KEY="$ORG-$ENV_KEY-$APP"
      TARGET_FOLDER="$TARGET/$FULL_KEY"

      if test -e "$TARGET_FOLDER"; then
        echo " * Updating $ORG-$ENV_KEY-$APP = $VERSION ($COMMIT)"
        cd "$TARGET_FOLDER"
        git checkout -q "$COMMIT"
      else
        echo " * Cloning $ORG-$ENV_KEY-$APP = $VERSION ($COMMIT)"
        set +e
        git clone -q "$REPO" "$TARGET_FOLDER"
        set -e
        if test -e "$TARGET_FOLDER"; then
          cd "$TARGET_FOLDER"
          git checkout -q "$COMMIT"
        fi
      fi
    done
  done
done