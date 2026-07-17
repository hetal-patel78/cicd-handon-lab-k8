#!/bin/bash
set -euo pipefail

SEMVER="${GitVersion_SemVer:-0.0.0}"
MAJOR_MINOR_PATCH="${GitVersion_MajorMinorPatch:-0.0.0}"

echo "fileVersion=$MAJOR_MINOR_PATCH"
echo "artifactVersion=$SEMVER"
echo "imageVersion=$SEMVER"
echo "imageName=ghcr.io/mycompany/my-subscription-service"
echo "buildNumber=$SEMVER+${GITHUB_RUN_NUMBER:-0}"