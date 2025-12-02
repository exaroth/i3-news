# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
## [0.4.5] 2025-02-12
### Changed
- Don't default $I3_NEWS_BROWSER_CMD to $BROWSER env var
## [0.4.4] 2025-26-10
### Fixed
- Fix handling opening browser in scroll scripts
## [0.4.3] 2025-17-10
### Changed
- Rename i3 news binary to `i3-news`
- Suppress browser std out output when opening links
## [0.4.2] 2025-24-09
### Fixed
- Fix click handler for polybar ticker integration
## [0.4.1] 2025-24-09
### Fixed
- Fix click event for paginate command
## [0.4.0] 2025-23-09
### Added
- Add paginate option
- Add continuous scroll option
### Changed
- Change configuration env var names
## [0.3.2] 2025-18-09
### Changed
- Remove emojis/hashtags from output text (bscroll)
- Add option to enable/disable marking article as read when opened in the browser
 
## [0.3.1] 2025-13-09
### Fixed
- Fix coalescing null values for new cache when using standard headline retrieval
 
## [0.3.0] 2025-13-09
### Added
- Add --random and --latest options for headline retrieval

## [0.2.1] 2025-12-09
### Changed
- Refactor setting read_no for newest articles
- Vacuum cache during feed reload
### Fixed
- Fix install path in installation scripts
 
## [0.2.0] 2025-12-09
### Added
- Initial version
