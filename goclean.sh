#!/bin/bash
# The script does automatic checking on a Go package and its sub-packages, including:
# 1. gofmt         (http://golang.org/cmd/gofmt/)
# 2. goimports     (https://github.com/bradfitz/goimports)
# 3. golint        (https://github.com/golang/lint)
# 4. go vet        (http://golang.org/cmd/vet)
# 5. gosimple      (https://github.com/dominikh/go-simple)
# 6. unconvert     (https://github.com/mdempsky/unconvert)
# 7. race detector (http://blog.golang.org/race-detector)
# 8. test coverage (http://blog.golang.org/cover)
#

set -ex

# Automatic checks
for i in $(find . -name go.mod -type f -print); do
  module=$(dirname ${i})
  echo "==> ${module}"

  MODNAME=$(echo $module | sed -E -e "s/^$ROOTPATHPATTERN//" \
    -e 's,^/,,' -e 's,/v[0-9]+$,,')
  if [ -z "$MODNAME" ]; then
    MODNAME=.
  fi

  # run tests
  (cd $MODNAME && env GORACE=halt_on_error=1 go test -race)

  # check linters
  (cd $MODNAME && \
    go mod download && \
    golangci-lint run --deadline=10m --disable-all \
      --enable=gofmt \
      --enable=goimports \
      --enable=golint \
      --enable=govet \
      --enable=gosimple \
      --enable=unconvert
  )
done

# Run test coverage on each subdirectories and merge the coverage profile.

echo "mode: count" > profile.cov

# Standard go tooling behavior is to ignore dirs with leading underscores.
for dir in $(find . -maxdepth 10 -not -path './.git*' -not -path '*/_*' -type d);
do
if ls $dir/*.go &> /dev/null; then
  go test -covermode=count -coverprofile=$dir/profile.tmp $dir
  if [ -f $dir/profile.tmp ]; then
    cat $dir/profile.tmp | tail -n +2 >> profile.cov
    rm $dir/profile.tmp
  fi
fi
done

go tool cover -func profile.cov
