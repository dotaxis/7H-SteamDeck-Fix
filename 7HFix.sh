#!/bin/bash
shopt -s expand_aliases
alias protontricks='flatpak run com.github.Matoking.protontricks'

DEFAULT_7TH_HEAVEN_DIRECTORY="7th Heaven"
DEFAULT_7TH_HEAVEN_APP_NAME="7th Heaven"

# Install protontricks and fix for SD cards
flatpak --system install com.github.Matoking.protontricks -y
flatpak override --user --filesystem=/run/media/mmcblk0p1 com.github.Matoking.protontricks

# Check for -c flag
copy_ff7=0
while getopts "c" opt; do
  case $opt in
    c) copy_ff7=1 ;;
    \?) copy_ff7=0 ;;
    *) copy_ff7=0 ;;
  esac
done

# Download 7th Heaven from Github
downloadDependency() {
  local REPO=$1
  local FILTER=$2
  local RETURN_VARIABLE=$3
  local RELEASE_URL=$(
    curl -s https://api.github.com/repos/"$REPO"/releases \
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
downloadDependency "tsunamods-codes/7th-Heaven" "*.exe" SEVENHEAVEN

zenity --width=500 --info --text="Make sure you have Final Fantasy VII installed on Steam.\nPress OK when you are ready to continue."

# Set install location
zenity --width=500 --question --text="Is your FF7 installed to an SD card?" --title="FF7 Install Location"
if [ $? -eq 1 ]; then
  FF7_LOCATION="${HOME}/.local/share/Steam/steamapps/common/FINAL FANTASY VII"
else
  FF7_LOCATION="/run/media/mmcblk0p1/SteamLibrary/steamapps/common/FINAL FANTASY VII"
  [ ! -d "$FF7_LOCATION" ] && FF7_LOCATION="/run/media/mmcblk0p1/steamapps/common/FINAL FANTASY VII"
fi
[ ! -d "$FF7_LOCATION" ] && zenity --width=500 --error --text "Cannot find FF7 folder located at $FF7_LOCATION. Fix it and re-run the script." && exit

# Instructions popup
zenity --width=500 --info \
--title="Installation" \
--text="Time to install 7th Heaven Canary and configure it for the Steam Deck!\n
1. Add a game as a \"Non-Steam Game\"\n
2. Select \""$(pwd)/$SEVENHEAVEN"\"\n
3. Name it whatever you want but remember that name for later
      Preferred default is: \"$DEFAULT_7TH_HEAVEN_APP_NAME\"\n
4. Go to the \"Compatibility\" section and click \"Force compatibility\"\n
5. Select \"Proton-8.XX\" (Where XX is the latest version available)\n
6. Run the game. Go through the wizard and install at:\n
      \"C:&#92;$DEFAULT_7TH_HEAVEN_DIRECTORY\"\n
<b>It's important to install it there otherwise it won't open</b>\n
<b>⚠️ DO NOT LAUNCH IT AFTER OR DURING THE INSTALLATION</b>"

zenity --width=500 --info --text="Wait for installation to complete. Close the wizard.\nPress OK when you are ready to continue."

# Protontricks APP_ID finder
zenity --width=500 --question --text="Is your Non-Steam Game named: \"${DEFAULT_7TH_HEAVEN_APP_NAME}\"?"
if [ $? -eq 0 ]; then
  SEVENTH_HEAVEN_APP_NAME=$DEFAULT_7TH_HEAVEN_APP_NAME
else
  SEVENTH_HEAVEN_APP_NAME=$(zenity --width=500 --entry \
  --title="Non-Steam Game Name" \
  --text="What is your Non-Steam Game named?" \
  --entry-text="$DEFAULT_7TH_HEAVEN_APP_NAME")
fi
APP_ID=$(protontricks -s $SEVENTH_HEAVEN_APP_NAME | grep -P "Non-Steam shortcut: $SEVENTH_HEAVEN_APP_NAME \([0-9]+\)" | grep -Po "(?<=\()[0-9].+(?=\))")
[[ ! $APP_ID =~ ^[0-9]+$ ]] && zenity --width=500 --error --text="APP_ID was not found for \"$SEVENTH_HEAVEN_APP_NAME\". Make sure the name entered matches and retry." && exit
WINEPATH="${HOME}/.steam/steam/steamapps/compatdata/$APP_ID/pfx"

# Option to move 7H to SD card
zenity --width=500 --question --title="Move to SD Card?" --text="Do you want to move 7th Heaven to the SD Card?\n
We'll put it under \"7th Heaven\" in the root of the SD card."
if [[ $? -eq 0 ]]; then
  SDCARD_FOLDER="/run/media/mmcblk0p1/7th Heaven"
  mv "${HOME}/.steam/steam/steamapps/compatdata/$APP_ID" "$SDCARD_FOLDER"
  ln -fs "$SDCARD_FOLDER" "${HOME}/.steam/steam/steamapps/compatdata/$APP_ID"
fi

# No-CD fix
mkdir -p "$WINEPATH/drive_c"
echo "FF7DISC1" > "$WINEPATH/drive_c/.windows-label"
echo "44000000" > "$WINEPATH/drive_c/.windows-serial"
[ -d "$WINEPATH/drive_c/FF7" ] && rm -r "$WINEPATH/drive_c/FF7"

if [ "$copy_ff7" -eq 1 ]; then
  # Copy FF7 directory to C:\FF7
  rsync -av --progress "$FF7_LOCATION/" "$WINEPATH/drive_c/FF7" |
  awk -f deps/rsync.awk |
  zenity --width=300 --progress --title "Copying FF7 Directory" \
  --text="Copying..." --percentage=0 --auto-kill
else
  # Symlink C:\FF7 to install path
  ln -fs "$FF7_LOCATION/" "$WINEPATH/drive_c/FF7"
fi

# Copy settings and patched exe
mkdir -p $WINEPATH/drive_c/FF7/mods/{"7th Heaven",textures}
FULL_PATH="$WINEPATH/drive_c/$DEFAULT_7TH_HEAVEN_DIRECTORY"
cp deps/dxvk.conf "$FULL_PATH"
mkdir -p "$FULL_PATH/7thWorkshop/"
cp -f deps/settings.xml "$FULL_PATH/7thWorkshop/"
cp -f "$FULL_PATH/Resources/FF7_1.02_Eng_Patch/ff7.exe" "$WINEPATH/drive_c/FF7/ff7.exe"

# Change target of Steam shortcut
for SHORTCUTSFILE in ${HOME}/.steam/steam/userdata/*/config/shortcuts.vdf ; do
  sed -i "s:$(pwd)/${SEVENHEAVEN}:${FULL_PATH}/7th Heaven.exe:" $SHORTCUTSFILE
  sed -i "s:$(pwd):${FULL_PATH}:" $SHORTCUTSFILE
done

# Fix updater
[ -f "$WINEPATH/drive_c/windows/syswow64/robocopy.exe" ] && rm "$WINEPATH/drive_c/windows/syswow64/robocopy.exe"
[ -f "$WINEPATH/drive_c/windows/system32/robocopy.exe" ] && rm "$WINEPATH/drive_c/windows/system32/robocopy.exe"
cp -f deps/robocopy.bat "$WINEPATH/drive_c/windows/system32/"
cp -f deps/timeout.exe "$WINEPATH/drive_c/windows/system32/"

# Option to copy saves
zenity --width=500 --question --title="Save Files" --text="Do you want to copy your save files from Vanilla FF7?"
if [[ $? -eq 0 ]]; then
  for file in "$WINEPATH/drive_c/FF7/save/"*.ff7 ; do
    [[ -e "$file" ]] && mv -- "$file" "$file.bak"
  done
  SAVES_FOLDER=$(ls -td ${HOME}/.steam/steam/steamapps/compatdata/39140/pfx/drive_c/users/steamuser/Documents/Square\ Enix/FINAL\ FANTASY\ VII\ Steam/user_* | head -1)
  [[ ! -d "$WINEPATH/drive_c/FF7/save" ]] && mkdir -p $WINEPATH/drive_c/FF7/save
  cd "$SAVES_FOLDER"
  for file in *".ff7" ; do
    cp -f -- "$file" "$WINEPATH/drive_c/FF7/save/$file"
  done
fi

# Dinput.dll fix
[ -f "$WINEPATH/drive_c/windows/syswow64/dinput.dll" ] && rm "$WINEPATH/drive_c/windows/syswow64/dinput.dll"
protontricks $APP_ID dinput

# Restart Steam
kill $(ps aux | grep '[s]team -steamdeck' | awk '{print $2}')
sleep 10
steam > /dev/null 2>&1 & disown

zenity --width=500 --info \
--title="Done!" \
--text="7th Heaven Canary has been successfully installed!\n
<b>******* IMPORTANT *******
⚠️ CLICK SAVE THE FIRST TIME YOU OPEN 7TH HEAVEN
⚠️ RUN THE GAME ONCE IN ORDER TO INSTALL FFNx</b>"
