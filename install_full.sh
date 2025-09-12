#!/bin/env sh

curl -# -L -o /tmp/i3_news https://github.com/exaroth/i3-news/releases/download/stable/i3_news_self_contained
chmod +x /tmp/i3_news
sudo mv /tmp/i3_news /usr/local/i3_news
echo "i3_news installed at /usr/local/bin/i3_news"
