#!/bin/env sh

curl -# -L -o /tmp/i3-news https://github.com/exaroth/i3-news/releases/download/stable/i3-news-self-contained
chmod +x /tmp/i3-news
sudo mv /tmp/i3-news /usr/local/bin/i3-news
echo "i3-news installed at /usr/local/bin/i3-news"
