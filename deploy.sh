#!/bin/bash

LAST_COMMIT=$(git rev-parse HEAD)

$(npm bin)/gulp build || exit $?

rm -rf deploy
git clone -b gh-pages $(git config --get remote.origin.url) deploy
cp -r dst/* deploy/

(cd deploy && \
 git add -A && \
 git commit -m "Automated deployment from ${LAST_COMMIT}." && \
 git push) || exit $?

rm -rf deploy
