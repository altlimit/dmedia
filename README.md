D-Media
===

Decentralized media is a self hosted backend powered by golang and sqlite for your photos and videos. It comes with a mobile app to sync your android directories to your server.

This is still in very early stages. The goal is to have searcheable media, auto detecting objects and faces, albums and more.

Setup
---

You can either compile directly from golang and run or download pre-compiled binaries in release page.
Install ffmpeg and make sure it's in your PATH to get video details.

Then intall the mobile app from google play or from the release page.

You need to put the server behind a proxy to enable https, you can also directly use the local port for home only back up.

Docker
---

Create a start_dmedia.sh file and add the contents below then run it. Mount a local directory to /data for all stored media, db and log files.

```bash
#!/bin/sh
set -e
docker pull altlimit/dmedia
docker stop dmedia
docker rm dmedia
docker create \
  --name=dmedia \
  -u 1000:1000 \
  -p 5454:5454 \
  -v /mnt/hd1/media:/data \
  --restart unless-stopped \
  altlimit/dmedia
docker start dmedia
```

Updating launcher icon
---
```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

Release new versions
---
```bash
# Mobile
git tag -a "v0.x.x-mobile" -m "message"
# Server
git tag -a "v0.x.x-server" -m "message"
# deploy
git push origin --tags
```