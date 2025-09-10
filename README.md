## I3 News

__I3 News__ let's you create interactive news headline snippets compatible with various i3/sway bar plugins, based on user defined RSS/Atom feeds. 

Compatibility list:

- i3blocks
- polybar
- i3status
- waybar
 
### Installation
> [!NOTE]
> i3 news requires `fuse`/`libfuse` libraries installed in the system

I3 news ships with 2 versions available:

- Light version - this includes only i3 news binary and supplementary scripts, it does not contain [Newsboat](https://newsboat.org/) RSS reader required for retrieval of RSS data, you will need to install Newsboat package system wide (__Note:__ Snapcraft version is not supported)(__*Recommended*__)
 
 
To install this version execute:
``` bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/exaroth/i3-news/master/install.sh)"
```
- Self contained version - this is the same as above but ships with Newsboat app and all required shared libraries included. To install run:
 
``` bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/exaroth/i3-news/master/install_full.sh)"
```

You can also download `i3_news` executables from [releases](https://github.com/exaroth/i3-news/releases) page.

Next update your crontab to set up regular RSS feed reloads , eg to update feeds every 20 minutes:


`crontab -e`

``` crontab
*/20 * * * * /usr/local/bin/i3_news reload
```
 
### Usage

```
Usage: i3news

Options:
  -c, --configs       Snippet configuration or configurations to use
  -s, --i3status      I3status output
  -b, --i3blocks      I3blocks output
  -p, --polybar       Polybar output
  -w, --waybar        Waybar output
  -a, --add-config    Add new i3-news configuration
  -r, --rm-config     Remove existing configuration
  -e, --edit-config   Edit urls for given configuration
      --get-url       Retrieve url for currently displayed headline
      --plain         Plain output
      --debug         Print debug info
  -h, --help          Print help
```

### Creating new snippet

In order to create new I3 news snippet execute:

``` sh
i3_news -a <snippet_name>
```

You will be prompted to enter list of RSS/Atom urls which will be tracked by the snippet.

Use 
```
i3_news -e <snippet_name>
```
To edit snippet urls, or
```
i3_news -r <snippet_name>
```
to remove existing one.

Snippet configurations are stored at `$HOME/.config/i3_news/`.

### Integration with i3 bar plugins.

#### i3blocks
In order to add i3 news snippet to i3blocks bar edit existing configuration (typically stored at `~/.i3blocks`) adding following entry:

```
[News]
command=/usr/local/bin/i3_news -b -c <snippet_name>
interval=30
```
(`interval` value will determine how often headlines will be refreshed)

Additionally in order to customize browser command to use when opening headline url you can use `I3_NEWS_BROWSER_CMD` env variable, for example to open url in new firefox tab use:

```
command=I3_NEWS_BROWSER_CMD="/usr/bin/firefox --new-tab" /usr/local/bin/i3_news -b -c <snippet_name>
```

#### i3status

> [!NOTE]
> i3status plugin is non-interactive, thus clicking on headline wont result in opening of the url in the browser
 
Edit `i3` configuration (typically stored at `~/.config/i3/config`) and locate `bar { ... }` block containing
```
status_command  i3status
```

entry, replace it with:

```
status_command  i3status | /usr/local/bin/i3_news -s -c <snippet_name>
```

You can also output more than 1 snippet by passing comma delimited list of snippet names as part of `-c` parameter.

#### polybar

Edit polybar configuration file (usually stored at `~/.config/polybar/config.ini`), add following entry:

``` ini
    [module/i3-news]
    type = custom/script
    exec = /usr/local/bin/i3_news -p -c <snippet_name>
    tail = true
    interval = 10
    click-left = /usr/local/bin/i3_news open -c <snippet_name>
```
then update either `modules-left` or `modules-right` entry with `i3-news`.

Similarly to `i3blocks` integration you can customize browser used for opening headline urls by adding `I3_NEWS_BROWSER_CMD` env when executing `click-left` handler.


#### waybar

Edit waybar configuraton (typically stored at `~/.config/waybar/config`), add following entry

``` json
    "custom/i3-news": {
        "exec": "/usr/local/bin/i3_news -w -c <snippet_name>",
        "return-type": "json",
        "interval": 10,
        "tooltip": false,
        "on-click": "/usr/local/bin/i3_news open -c <snippet_name>"
    }
```

and update `modules-right`, `modules-left` or `modules-center` with `custom/i3-news` entry.

You can customize color rendering by editing `~/.config/waybar/style.css` and adding

``` css
#custom-i3-news.<snippet_name> {
    color: white;
}
```

### Scrolling text headlines

#### Polybar/Waybar

`i3-news` ships with [zscroll](https://github.com/noctuid/zscroll) script which allows for easy incorporation of scrolling text headlines, this feature is only compatible with `polybar` and `waybar` plugins. In order to output headline snippet run:
```
i3_news zscroll -c <snippet_name>
```
Parameters of the scrolling snippets can be configured via environment variables:
- `ZSCROLL_INTERVAL` - how often to refresh news headlines
- `ZSCROLL_DELAY` - Controls scroll speed
- `ZSCROLL_WIDTH` - Width of the snippet

##### Polybar integration

Reference configuration, note there's no need to include `interval` field for scrolling snippets.
```
    [module/i3-news-scroll]
    type = custom/script
    exec = ZSCROLL_DELAY=0.3 /usr/local/bin/i3_news zscroll -c <snippet_name>
    click-left = /usr/local/bin/i3_news open -c <snippet_name>
    tail = true
    label = %output:0:40:...%
```

#### I3blocks

I3 news comes supplied with dedicated command `bscroll` to handle scrolling headlines for i3bar, to use it execute:

```
/usr/local/bin/i3_news bscroll -c <snippet_name>
```

Command defaults can be overriden using following env vars:

- `BSCROLL_INTERVAL` - Refresh rate for the headlines
- `BSCROLL_DELAY` - Scroll speed
- `BSCROLL_WIDTH` - Width of the snippet

Example usage in i3blocks config (`markup=pango` and `interval=persist` settings are required)

```
[News]
command=BSCROLL_INTERVAL=20 /usr/local/bin/i3_news bscroll -c <snippet_name>
markup=pango
color=#FEC925
interval=persist
```


### Configuration

Configuration for each snippet is stored at `~/.config/i3_news/<snippet_name>/config` with following options available:

- `max-article-age` - amount of hours in the past for which to display headlines for
- `output-color` - text color for given snippet (hex based)
- `refresh-interval` - (i3status only) refresh rate when displaying the headlines

### License
See `LICENSE` file for details

