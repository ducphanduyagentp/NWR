#!/bin/bash
if [ ! -d ./build ]; then
    mkdir -p ./build
fi

if [[ "$1" != "" ]]; then
    filename=$1
else
    filename=$"weInfect"
fi  

CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o ./build/$filename src/all/*.go
GOOS=windows GOARCH=386 go build -o ./build/$filename.exe src/all/*.go
