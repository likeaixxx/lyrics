### Install Lyrics App
[Download from release page](https://github.com/likeaixxx/lyrics/releases)

### custom build
```shell
git clone https://github.com/likeaixxx/lyrics.git
cd lyrics
xcodebuild -project Lyrics.xcodeproj -scheme "Lyrics" -configuration Release
```
Open the build folder and copy the app to the Applications directory

### Setup server with docker
Require a database file:
```shell
mkdir ~/lyrics && touch ~/lyrics/lyrics.db
```

1. docker: `docker run --name lyrics -d -p 8331:8331 -v ~/lyrics/lyrics.db:/app/lyrics.db likeai1111/lyrics:latest`
2. docker compose:
```yaml
name: lyrics
services:
    lyrics:
        image: likeai1111/lyrics:latest
        container_name: lyrics
        volumes:
            - ~/lyrics/lyrics.db:/app/lyrics.db
        restart: unless-stopped
```

### Acknowledgements
[LyricFever](https://github.com/aviwad/LyricFever)
