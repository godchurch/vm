SRC = src
BUILD = build
M4 = --prefix-builtins --include='$(SRC)'

LIST_BROWSER = \
							 $(SRC)/browser.in \
							 $(SRC)/config.in \
							 $(SRC)/gtkrc-2.0.in \
							 $(SRC)/packages.in \
							 $(SRC)/settings.ini.in \
							 $(SRC)/xinitrc.in

SED_BROWSER = \
							s|DEFAULT_BACKGROUND_COLOR|\#AF5FAF|g; \
							s|DEFAULT_WINDOW_MANAGER|i3|g; \
							s|DEFAULT_BROWSER|chromium-browser|g; \
							s|DEFAULT_THEME|Adwaita|g; \
							s|DEFAULT_FONT|Sans 10|g; \
							s|DEFAULT_I3_MODIFIER|Mod1|g; \
							s|DEFAULT_I3_UP|j|g; \
							s|DEFAULT_I3_DOWN|k|g; \
							s|DEFAULT_I3_LEFT|h|g; \
							s|DEFAULT_I3_RIGHT|l|g

default: browser

clean:
	rm -rf browser

.PHONY: default clean

browser: $(LIST_BROWSER)
	m4 $(M4) '$<' | sed -e '$(SED_BROWSER)' > '$@'
