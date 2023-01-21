#!/bin/bash
shopt -s expand_aliases
alias protontricks='flatpak run com.github.Matoking.protontricks'

DEFAULT_7TH_HEAVEN_DIRECTORY="7th Heaven"
DEFAULT_7TH_HEAVEN_APP_NAME="7th Heaven"

# Download dependencies
downloadDependencies() {
  local REPO=$1
  local FILTER=$2
  local RETURN_VARIABLE=$3
  local RELEASE_URL=$(
    curl -s https://api.github.com/repos/"$REPO"/releases/tags/canary \
    | grep "browser_download_url.$FILTER" \
    | head -1 \
    | cut -d : -f 2,3 \
    | tr -d \")
  local FILENAME=$(basename "$RELEASE_URL")
  if [ -f "$FILENAME" ]; then
    echo "$FILENAME is ready to be installed."
  else
    echo "$FILENAME not found. Downloading..."
    wget --show-progress -q $RELEASE_URL
  fi
  eval "${RETURN_VARIABLE}=\"$FILENAME\""
}
downloadDependencies "tsunamods-codes/7th-Heaven" "*.exe" SEVENHEAVEN
downloadDependencies "julianxhokaxhiu/FFNx" "*.zip" FFNX

# new line
echo

# If FFNX somehow isn't there - do not continue as it will fail the unzip
[ ! -f "$FFNX" ] && echo "$FFNX file for FFNx is required. Re-run the script or download it manually to the root of this folder." && exit

echo -e "Make sure you have Final Fantasy VII installed on Steam.\nPress enter when you are ready to continue."
read -r

echo "Where is your FF7 folder located? "
locations=("Local" "SD" "Quit")
select loc in "${locations[@]}"; do
    case $loc in
        "Local")
            FF7_LOCATION="${HOME}/.local/share/Steam/steamapps/common/FINAL FANTASY VII"
            break;
            ;;
        "SD")
            FF7_LOCATION="/run/media/mmcblk0p1/SteamLibrary/steamapps/common/FINAL FANTASY VII"
            [ ! -d "$FF7_LOCATION" ] && FF7_LOCATION="/run/media/mmcblk0p1/steamapps/common/FINAL FANTASY VII"
            break;
            ;;
        "Quit")
            echo "User requested exit"
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

# Global path check regardless of option
[ ! -d "$FF7_LOCATION" ] && echo "Cannot find FF7 folder located at $FF7_LOCATION. Fix it and re-run the script." && exit

# Now onto installing 7TH-Heaven Canary & Proton-GE
echo
echo "Time to install 7th Heaven Canary and configure it for the Steam Deck!"
echo
echo "| Add a game as a \"Non-Steam Game\""
echo "| Select \""$(pwd)/$SEVENHEAVEN"\""
echo "| == Name it whatever you want but remember that name for later =="
echo "| == Preferred default is: \"$DEFAULT_7TH_HEAVEN_APP_NAME\""
echo "| Go to the \"Compatibility\" section and click \"Force compatibility\""
echo "| Select \"ProtonGE-XX\" (Where XX is the latest version available)"
echo "| -----------------------------------------------------"
echo "| Run the game. Go through the wizard and install at:"
echo "| == \"C:\\$DEFAULT_7TH_HEAVEN_DIRECTORY\""
echo "| == It's important to install it there otherwise it won't open =="
echo "| == DO NOT LAUNCH IT AFTER OR DURING THE INSTALLATION =="

echo

echo -e "The installation should be complete. Close the wizard.\nPress enter when you are ready to continue."
read -r

# Protontricks APP_ID finder + dinput fix
read -rp "Is your Non-Steam Game named: \"${DEFAULT_7TH_HEAVEN_APP_NAME}\"? [y/N] " USE_DEFAULT_NAME

SEVENTH_HEAVEN_APP_NAME=$DEFAULT_7TH_HEAVEN_APP_NAME
if [[ ! $USE_DEFAULT_NAME =~ ^[Yy]$ ]]; then
  read -rp "What is your Non-Steam Game named? " SEVENTH_HEAVEN_APP_NAME
fi

echo "Finding APP_ID..."
APP_ID=$(protontricks -s $SEVENTH_HEAVEN_APP_NAME | grep -Po "(?<=\()[0-9].+(?=\))")
# Ensures APP_ID is valid
[[ ! $APP_ID =~ ^[0-9]+$ ]] && echo "APP_ID was not found for \"$SEVENTH_HEAVEN_APP_NAME\". Make sure the name entered matches and retry." && exit

echo "Resolving PFX path..."
WINEPATH="${HOME}/.steam/steam/steamapps/compatdata/$APP_ID/pfx"

echo "PFX path detected at $WINEPATH"
read -rp "Do you want to use this path? [y/N] "
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  read -rp 'Manually enter PFX path: ' WINEPATH
fi

[ ! -d "$WINEPATH" ] && echo "Invalid PFX path at $WINEPATH. Abort." && exit

echo
echo "Removing & installing dinput..."
rm "$WINEPATH/drive_c/windows/syswow64/dinput.dll"
echo
protontricks $APP_ID dinput 2&> /dev/null

echo
echo "Copying FF7 directory..."
mkdir -p "$WINEPATH/drive_c"
echo "FF7DISC1" > "$WINEPATH/drive_c/.windows-label"
echo "44000000" > "$WINEPATH/drive_c/.windows-serial"
[ -d "$WINEPATH/drive_c/FF7" ] && rm -r "$WINEPATH/drive_c/FF7"
cp -Rfp "$FF7_LOCATION" "$WINEPATH/drive_c/FF7"
mkdir -p $WINEPATH/drive_c/FF7/mods/{7thHeaven,textures}
cp dxvk.conf "$WINEPATH/drive_c/$DEFAULT_7TH_HEAVEN_DIRECTORY"

echo "Installing FFNx..."
unzip -o "$FFNX" -d "$WINEPATH/drive_c/FF7"

echo
echo "7th Heaven Canary has been successfully installed!"
FULL_PATH="$WINEPATH/drive_c/$DEFAULT_7TH_HEAVEN_DIRECTORY"
echo
echo "| Altering Steam Shortcut"
SHORTCUTSFILE=$(ls -td ${HOME}/.steam/steam/userdata/* | head -1)/config/shortcuts.vdf
sed -i "s:$(pwd)/${SEVENHEAVEN}:${FULL_PATH}/7th Heaven.exe:" $SHORTCUTSFILE
sed -i "s:$(pwd):${FULL_PATH}:" $SHORTCUTSFILE
echo "| Done!"
echo "| "
echo "| ***** RESTART STEAM BEFORE LAUNCHING THE GAME *****"
