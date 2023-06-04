#!/bin/sh -e

if [ -n "${GITHUB_WORKSPACE}" ]
then
    git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
    git config --global --add safe.directory "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1
    cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo '::group:: Installing fasterer with extensions ... https://github.com/presidentbeef/fasterer'
# if 'gemfile' fasterer version selected
if [ "$INPUT_FASTERER_VERSION" = "gemfile" ]; then
  # if Gemfile.lock is here
  if [ -f 'Gemfile.lock' ]; then
    # grep for fasterer version
    FASTERER_GEMFILE_VERSION=$(ruby -ne 'print $& if /^\s{4}fasterer\s\(\K.*(?=\))/' Gemfile.lock)

    # if fasterer version found, then pass it to the gem install
    # left it empty otherwise, so no version will be passed
    if [ -n "$FASTERER_GEMFILE_VERSION" ]; then
      FASTERER_VERSION=$FASTERER_GEMFILE_VERSION
      else
        printf "Cannot get the fasterer's version from Gemfile.lock. The latest version will be installed."
    fi
    else
      printf 'Gemfile.lock not found. The latest version will be installed.'
  fi
  else
    # set desired fasterer version
    FASTERER_VERSION=$INPUT_FASTERER_VERSION
fi

gem install -N fasterer --version "${FASTERER_VERSION}"
echo '::endgroup::'

echo '::group:: Running fasterer with reviewdog 🐶 ...'
 
# shellcheck disable=SC2086
fasterer | sed "s/\x1b\[[0-9;]*m//g" \
  | reviewdog \
    -efm="%f:%l %m" \
    -efm="%-G%.%#" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -level="${INPUT_LEVEL}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    "${INPUT_REVIEWDOG_FLAGS}"

exit_code=$?
echo '::endgroup::'

exit $exit_code
