#!/bin/sh
# Xcode Cloud: regenerate project from project.yml before building
set -e

if [ -d "$CI_PRIMARY_REPOSITORY_PATH/echo" ]; then
    WD="$CI_PRIMARY_REPOSITORY_PATH/echo"
else
    WD="$CI_PRIMARY_REPOSITORY_PATH"
fi

cd "$WD" || exit 1

if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen via brew..."
    brew install xcodegen || {
        if [ ! -f /usr/local/bin/xcodegen ] && [ ! -f /opt/homebrew/bin/xcodegen ]; then
            echo "Error: xcodegen not available. Aborting."
            exit 1
        fi
    }
fi

echo "Regenerating Xcode project from project.yml..."
xcodegen generate || {
    echo "Error: xcodegen generate failed"
    exit 1
}

echo "Project regeneration complete"
