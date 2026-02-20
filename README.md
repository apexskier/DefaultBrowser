#  Default Browser

Default Browser replaces macOS's system web browser setting with a flexible, convenient utility that opens links with your most recently used browser.

https://defaultbrowser.app

## Features

- **Intelligent link handling** Opens external links with your last used browser.
- **Quick browser toggle** Keyboard shortcuts from the menu bar.
- **Menu bar preview** Quick reference of the currently active browser.
- **Blocklist** Prevent browsers from automatically opening.
- **Legacy behavior** Select your primary browser to simulate traditional behavior.
- **Shortcuts support** Force a specific browser with Siri Shortcuts

## Notes

This app was initially written over 10 years ago, and Apple has introduced a few security restrictions I've made my best attempt to work around.

- [No longer can automatically register as `html` file handler](https://github.com/Hammerspoon/hammerspoon/issues/2205#issuecomment-541972453). Please [do this manually](https://support.apple.com/guide/mac-help/choose-an-app-to-open-a-file-on-mac-mh35597/mac) now.
- With App Sandboxing, we only have automatic access to system installed browsers. To enable browsers outside of `/Applications`, open "Preferences", expand "Additional Browsers", select the browsers you want to enable, and double click to grant access.
