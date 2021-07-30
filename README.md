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

More details coming soon.

Updating launcher icon
---
```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```