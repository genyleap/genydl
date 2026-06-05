on run argv
    set volumeName to item 1 of argv

    tell application "Finder"
        tell disk volumeName
            open
            delay 1

            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {100, 100, 760, 500}

            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 96

            if exists folder ".background" of disk volumeName then
                if exists file "background.png" of folder ".background" of disk volumeName then
                    set background picture of viewOptions to file "background.png" of folder ".background" of disk volumeName
                end if
            end if

            if exists item "Tondar.app" of container window then
                set position of item "Tondar.app" of container window to {170, 210}
            end if

            if exists item "Applications" of container window then
                set position of item "Applications" of container window to {490, 210}
            end if

            update without registering applications
            delay 2

            close
        end tell
    end tell
end run