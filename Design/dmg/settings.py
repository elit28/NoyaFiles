# dmgbuild settings for the NOYA Files disk image, used by scripts/make-dmg.sh.
#
# The window shows the app on the left and the Applications folder on the right, over
# background.png (with background@2x.png for Retina screens). The icon positions match the
# cards drawn in background.html.

app = defines["app"]  # noqa: F821 (dmgbuild provides `defines`)

files = [app]
symlinks = {"Applications": "/Applications"}
hide_extension = ["NOYA Files.app"]

icon = defines["icon"]  # noqa: F821
background = defines["background"]  # noqa: F821

format = "UDZO"
filesystem = "HFS+"

# The Finder counts the title bar (about 32 points) in the window height, so the window is
# taller than the 660 × 420 background for all of it to show.
window_rect = ((200, 160), (660, 452))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0

arrange_by = None
icon_size = 112
text_size = 13
label_pos = "bottom"
icon_locations = {
    "NOYA Files.app": (180, 196),
    "Applications": (480, 196),
}
