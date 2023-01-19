#!/bin/bash
shopt -s expand_aliases
alias protontricks='flatpak run com.github.Matoking.protontricks'

PS3='Where is your FF7 folder located? '
locations=("local" "SD" "Quit")
select loc in "${locations[@]}"; do
    case $loc in
        "local")
            FF7_LOCATION="${HOME}/.local/share/Steam/steamapps/common/FINAL FANTASY VII"
            break;
            ;;
        "SD")
            FF7_LOCATION="/run/media/mmcblk0p1/SteamLibrary/steamapps/common/FINAL FANTASY VII"
            if [ ! -d "$FF7_LOCATION" ]
            then
                FF7_LOCATION="/run/media/mmcblk0p1/steamapps/common/FINAL FANTASY VII"
            fi
            if [ ! -d "$FF7_LOCATION" ]
            then
                echo "Cannot find FF7 directory. Abort."
                exit
            fi
            break;
            ;;
        "Quit")
            echo "User requested exit"
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

APP_ID=$(protontricks -s "7th Heaven" | grep -Po "(?<=\()[0-9].+(?=\))")
WINEPATH="${HOME}/.steam/steam/steamapps/compatdata/$APP_ID/pfx"
echo "PFX path detected at $WINEPATH"
read -p "Do you want to use this path? [Y\n] " -n 1 -r
echo # new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    read -p 'Enter pfx path: ' WINEPATH
    [ -d "$WINEPATH" ] || echo "Invalid path, abort."; exit
fi

echo "Removing & installing dinput"
rm "$WINEPATH/drive_c/windows/syswow64/dinput.dll"
echo # newline
protontricks $APP_ID dinput

echo "Copying FF7 directory"
mkdir -p "$WINEPATH/drive_c"
echo "FF7DISC1" > "$WINEPATH/drive_c/.windows-label"
echo "44000000" > "$WINEPATH/drive_c/.windows-serial"
rm -r "$WINEPATH/drive_c/FF7"
cp -Rfp "$FF7_LOCATION" "$WINEPATH/drive_c/FF7"
mkdir -p $WINEPATH/drive_c/FF7/mods/{7thHeaven,textures}
cp dxvk.conf "$WINEPATH/drive_c/7th Heaven"
unzip -o FFNx-FF7_1998-v1.14.0.55.zip -d "$WINEPATH/drive_c/FF7"

echo
echo "Done installing"
echo "Copy this path on your non-steam app's target: $WINEPATH/drive_c/7th Heaven/7th Heaven.exe"
