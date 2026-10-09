# dmgbuild settings for the Cameo installer (see scripts/package.sh).
# Layout matches Sources/Cameo/DMGBackground.swift: a 720 x 440 window,
# the app at (190, 200) and Applications at (530, 200).
import os.path

app = defines["app"]
format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]
background = defines["background"]

window_rect = ((200, 160), (720, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    os.path.basename(app): (190, 200),
    "Applications": (530, 200),
}
