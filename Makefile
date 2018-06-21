SRC = src
BUILD = build

LIST = \
			 browser \
			 config \
			 gtkrc-2.0 \
			 packages \
			 settings.ini \
			 xinitrc

BUILD_LIST = $(addprefix $(BUILD)/,$(LIST))

SED = \
			s|DEFAULT_BACKGROUND_COLOR|\#AF5FAF|g; \
			s|DEFAULT_BROWSER|chromium-borwser|g; \
			s|DEFAULT_WINDOW_MANAGER|i3|g; \
			s|DEFAULT_THEME|Adwaita|g; \
			s|DEFAULT_FONT|Sans 10|g; \
			s|DEFAULT_I3_MODIFIER|Mod1|g; \
			s|DEFAULT_I3_UP|j|g; \
			s|DEFAULT_I3_DONW|k|g; \
			s|DEFAULT_I3_LEFT|h|g; \
			s|DEFAULT_I3_RIGHT|l|g

.PHONY: default clean

default: browser

clean:
	rm -rf browser $(BUILD)

browser: $(BUILD_LIST)
	m4 -P -I './$(BUILD)' '$(addprefix $(BUILD)/,$@)' > '$@'

$(BUILD_LIST): $(BUILD)/%: $(SRC)/%.in | $(BUILD)
	sed -e '$(SED)' '$<' > '$@'

$(BUILD):
	install -d '$@'
