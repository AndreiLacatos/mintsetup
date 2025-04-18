#!/bin/bash

# Ensure script is NOT run as root
if [[ "$EUID" -eq 0 ]]; then
    echo "❌ Run this script as regular (non-root) user"
  exit 1
fi

# Capture the HOME directory of the user
USER_HOME=$HOME
USER=$(whoami)

# Sanity check
echo "Setting up environment for:"
echo "  user: $USER"
echo "  home directory: $USER_HOME"
read -p "❔ Is this information correct? (y/N): " CONFIRMATION

if [[ "$CONFIRMATION" =~ ^[yY]$ ]]; then
  echo "✅ Proceeding setup"
else
  echo "❌ Aborting"
  exit 1
fi

# Ensure required utilities are installed
REQUIRED_UTILS=(git wget xmlstarlet)

echo "🔍 Verifying required utilities"
MISSING_PKGS=()

for pkg in "${REQUIRED_UTILS[@]}"; do
  if ! dpkg -s "$pkg" &> /dev/null; then
    echo "  🚫 $pkg is missing"
    MISSING_PKGS+=("$pkg")
  else
    echo "  ✅ $pkg is already installed"
  fi
done

# Install missing utilities if any
if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
  echo "📥 Installing missing utilities: ${MISSING_PKGS[*]}"

  # Ask for sudo access
  if sudo -v; then
    sudo apt update
    sudo apt install -y "${MISSING_PKGS[@]}"
  else
    echo "❌ Unable to gain sudo access. Exiting."
    exit 1
  fi
else
  echo "✅ All required utilities are present."
fi


# Immediately exit if any error occurs during script execution
#set -e
set -euo pipefail
trap 'echo "🔥 Script failed at line $LINENO: $BASH_COMMAND"' ERR



# Create temp directory
TEMP_DIR="$USER_HOME/setup-temp"

if [ -d $TEMP_DIR ]; then
  rm -rf $TEMP_DIR
fi

mkdir "$TEMP_DIR"
cd "$TEMP_DIR"


###############################################
#                     ICONS                   #
###############################################
ICONS_DIR="$USER_HOME/.icons"
ICONS_NAME="kora"

if [ -d "$ICONS_DIR/$ICONS_NAME" ]; then
  echo "✅ $ICONS_NAME icons already installed"
else
  # Clone resources
  echo "⬇️  Installing icons"
  ICONS_URL="https://github.com/bikass/kora.git"
  git clone $ICONS_URL
  mkdir -p "$ICONS_DIR"

  # Move resources to icons dir
  cp -r "$ICONS_NAME/$ICONS_NAME" "$ICONS_DIR"
fi

# Apply icons
xfconf-query -c xsettings -p /Net/IconThemeName -s $ICONS_NAME
echo "  ✅ Applied icons"


###############################################
#                     THEME                   #
###############################################
THEME_DIR="$USER_HOME/.themes"
THEME_URL="https://github.com/vinceliuice/WhiteSur-gtk-theme.git"
THEME_NAME="WhiteSur-Dark"

if [ -d "$THEME_DIR/$THEME_NAME" ]; then
  echo "✅ $THEME_NAME theme already installed"
else
  # Create themes directory
  mkdir -p "$THEME_DIR"
  
  # Clone resources
  echo "⬇️  Installing theme"
  git clone $THEME_URL

  # Extract archive and move to user themes dir
  $(cd "$(basename -s .git "$THEME_URL")/release" && tar -xJf "$THEME_NAME.tar.xz" -C "$THEME_DIR/" 2>&1)
fi

# Set the theme
xfconf-query -c xsettings -p /Net/ThemeName -s $THEME_NAME
# Set Xfwm theme
xfconf-query -c xfwm4 -p /general/theme -s $THEME_NAME
# Tweak window manager button layout
xfconf-query -c xfwm4 -p /general/button_layout -s "CMH|O"
echo "  ✅ Applied theme"


###############################################
#                     FONT                    #
###############################################
FONT_URL="https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git"
FONT_DIR="$USER_HOME/.fonts"
FONT_FAMILY="San Francisco"
FONT_NAME="SF Pro Display 10"

if [ -d "$FONT_DIR/$FONT_FAMILY" ]; then
  echo "✅ $FONT_FAMILY font already installed"
else
  # Create themes directory
  mkdir -p "$FONT_DIR/$FONT_FAMILY"
  
  # Clone resources
  echo "⬇️  Installing font family"
  git clone $FONT_URL

  # Move to user fonts dir
  $(cd "$(basename -s .git "$FONT_URL")" && cp *.otf "$FONT_DIR/$FONT_FAMILY")
fi

# Set system wide font
xfconf-query -c xsettings -p /Gtk/FontName -s "$FONT_NAME"
# Set window title font
xfconf-query -c xfwm4 -p /general/title_font -s "$FONT_NAME"
echo "  ✅ Applied font"


###############################################
#                    CURSOR                   #
###############################################
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s Adwaita


###############################################
#                    PANEL                    #
###############################################
echo "⚙️  Applying panel preferences..."
# Panel styles
# Use --create option on all properties to ensure they are set to
# the desired value even it they do not exist by default in the config
xfconf-query -c xfce4-panel -p /panels/panel-1/mode --create -t uint -s 0
xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior --create -t uint -s 2
xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked --create -t bool -s "true"
xfconf-query -c xfce4-panel -p /panels/panel-1/length --create -t double -s 80
xfconf-query -c xfce4-panel -p /panels/panel-1/length-adjust --create -t bool -s "true"
xfconf-query -c xfce4-panel -p /panels/panel-1/nrows --create -t uint -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/size --create -t uint -s 32
xfconf-query -c xfce4-panel -p /panels/dark-mode --create -t bool -s "true"
xfconf-query -c xfce4-panel -p /panels/panel-1/background-rgba --create -t double -s 0 -t double -s 0 -t double -s 0 -t double -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size --create -t uint -s 21
xfconf-query -c xfce4-panel -p /panels/panel-1/background-style --create -t uint -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/span-monitors --create -t bool -s "false"
xfconf-query -c xfce4-panel -p /panels/panel-1/output-name --create -t string -s "Primary"

# Temporarily stop xfconfd to stop messing with the config file
kill -9 $(pgrep xfconfd)

# Panel items
# Add the plugins in the desired order (plugin definition below)
PANEL_CFG_FILE="$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
# ID 1 is for Whisker menu, other IDs are prefixed 420X to avoid interference
# with other IDs generated by xfce4-panel (looks like it really can't let go of defaults)
PLUGIN_IDS=(1 3001 3002 3003 4203 4205 4206 4207 4208 4209 4210 4204 4202)
CMD="-d '//property[@name=\"plugin-ids\"]/value'"
i=0
for id in "${PLUGIN_IDS[@]}"; do
  i=$((i+1))
  CMD+=" -s '//property[@name=\"plugin-ids\"]' -t elem -n valueTMP$i -v ''"
  CMD+=" -i '//property[@name=\"plugin-ids\"]/valueTMP$i' -t attr -n type -v int"
  CMD+=" -i '//property[@name=\"plugin-ids\"]/valueTMP$i' -t attr -n value -v $id"
  CMD+=" -r '//property[@name=\"plugin-ids\"]/valueTMP$i' -v value"
done

TEMP_CFG_FILE="$TEMP_DIR/temp-cfg.xml"
# Output of xmlstarlet cannot be directly redirected to the config file because the shell 
# automatically removed the contents of the file as soon as it sees the > operator. It is
# saved to a temporary file, then it replaces the config file
CMD="xmlstarlet ed $CMD $PANEL_CFG_FILE > $TEMP_CFG_FILE"
sh -c "$CMD"
cp $TEMP_CFG_FILE $PANEL_CFG_FILE

# Plugin definition
# 1. Prepare the new definitions (as raw XML)
PLUGINS=$(cat <<'EOF'
    <property name="plugin-4202" type="string" value="showdesktop"/>
    <property name="plugin-4203" type="string" value="separator">
      <property name="style" type="uint" value="1"/>
      <property name="expand" type="bool" value="false"/>
    </property>
    <property name="plugin-4204" type="string" value="clock">
      <property name="digital-layout" type="uint" value="1"/>
      <property name="digital-time-font" type="string" value="SF Pro Display Bold 8"/>
      <property name="digital-date-font" type="string" value="SF Pro Display 8"/>
      <property name="digital-date-format" type="string" value="%Y-%m-%d"/>
      <property name="mode" type="uint" value="2"/>
    </property>
    <property name="plugin-4205" type="string" value="tasklist">
      <property name="show-handle" type="bool" value="false"/>
      <property name="middle-click" type="empty"/>
      <property name="show-labels" type="bool" value="false"/>
      <property name="flat-buttons" type="bool" value="false"/>
      <property name="show-tooltips" type="bool" value="false"/>
    </property>
    <property name="plugin-4206" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-4207" type="string" value="systray">
      <property name="known-legacy-items" type="array">
        <value type="string" value="mintupdate.py"/>
        <value type="string" value="tray.py"/>
        <value type="string" value="networkmanager applet"/>
        <value type="string" value="blueman-tray"/>
        <value type="string" value="blueman"/>
      </property>
      <property name="square-icons" type="bool" value="false"/>
      <property name="hidden-legacy-items" type="array">
        <value type="string" value="tray.py"/>
        <value type="string" value="mintupdate.py"/>
      </property>
      <property name="hide-new-items" type="bool" value="false"/>
      <property name="icon-size" type="int" value="22"/>
    </property>
    <property name="plugin-4208" type="string" value="notification-plugin"/>
    <property name="plugin-4209" type="string" value="pulseaudio">
      <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
    </property>
    <property name="plugin-4210" type="string" value="power-manager-plugin"/>
EOF
)

echo "$PLUGINS" > "$TEMP_DIR/plugins.xml"

# 2. Inject content
xmlstarlet ed -s '//property[@name="plugins"]' -t elem -n PLACEHOLDER -v '' $PANEL_CFG_FILE > $TEMP_CFG_FILE

sed -i "/<PLACEHOLDER\/>/ {
    r $TEMP_DIR/plugins.xml
    d
}" "$TEMP_CFG_FILE"

cp $TEMP_CFG_FILE $PANEL_CFG_FILE

echo "  ✅ Applied panel preferences. A reboot is necessary to apply the changes"

# Launchers
LAUNCHERS_DIR="$USER_HOME/.config/xfce4/panel"
# Settings manager
# 1. Prepare .desktop entry
LAUNCHER_ID=3001
LAUNCHER_NAME="settingsmanager.desktop"
DESKTOP_ENTRY=$(cat <<'EOF'
[Desktop Entry]
Name=Settings Manager
Comment=Graphical Settings Manager for Xfce
Keywords=control;panel;center;system;settings;personalize;hardware;
Exec=xfce4-settings-manager
Icon=org.xfce.settings.manager
Terminal=false
Type=Application
Categories=X-XFCE;Settings;DesktopSettings;
OnlyShowIn=XFCE;
X-XfceSettingsManagerHidden=true
X-XFCE-Source=file:///usr/share/applications/xfce-settings-manager.desktop
EOF
)

mkdir -p "$LAUNCHERS_DIR/launcher-$LAUNCHER_ID"
echo $DESKTOP_ENTRY > "$LAUNCHERS_DIR/launcher-$LAUNCHER_ID/$LAUNCHER_NAME"

# 2. Inject launcher definition
LAUNCHER_XML=$(cat <<EOF
<property name="plugin-$LAUNCHER_ID" type="string" value="launcher">
  <property name="items" type="array">
    <value type="string" value="$LAUNCHER_NAME"/>
  </property>
</property>
EOF
)
echo "$LAUNCHER_XML" > "$TEMP_DIR/launcher.xml"
xmlstarlet ed -s '//property[@name="plugins"]' -t elem -n PLACEHOLDER -v '' $PANEL_CFG_FILE > $TEMP_CFG_FILE

sed -i "/<PLACEHOLDER\/>/ {
    r $TEMP_DIR/launcher.xml
    d
}" "$TEMP_CFG_FILE"

cp $TEMP_CFG_FILE $PANEL_CFG_FILE

# Firefox
# 1. Prepare .desktop entry
LAUNCHER_ID=3002
LAUNCHER_NAME="firefox.desktop"
DESKTOP_ENTRY=$(cat <<'EOF'
[Desktop Entry]
Version=1.0
Name=Firefox Web Browser
Comment=Browse the World Wide Web
GenericName=Web Browser
Keywords=Internet;WWW;Browser;Web;Explorer
Exec=firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=firefox
Categories=GNOME;GTK;Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
StartupNotify=true
Actions=new-window;new-private-window;
X-XFCE-Source=file:///usr/share/applications/firefox.desktop

[Desktop Action new-window]
Name=Open a New Window
Exec=firefox -new-window

[Desktop Action new-private-window]
Name=Open a New Private Window
Exec=firefox -private-window
EOF
)

mkdir -p "$LAUNCHERS_DIR/launcher-$LAUNCHER_ID"
echo $DESKTOP_ENTRY > "$LAUNCHERS_DIR/launcher-$LAUNCHER_ID/$LAUNCHER_NAME"

# 2. Inject launcher definition
LAUNCHER_XML=$(cat <<EOF
<property name="plugin-$LAUNCHER_ID" type="string" value="launcher">
  <property name="items" type="array">
    <value type="string" value="$LAUNCHER_NAME"/>
  </property>
</property>
EOF
)
echo "$LAUNCHER_XML" > "$TEMP_DIR/launcher.xml"
xmlstarlet ed -s '//property[@name="plugins"]' -t elem -n PLACEHOLDER -v '' $PANEL_CFG_FILE > $TEMP_CFG_FILE

sed -i "/<PLACEHOLDER\/>/ {
    r $TEMP_DIR/launcher.xml
    d
}" "$TEMP_CFG_FILE"

cp $TEMP_CFG_FILE $PANEL_CFG_FILE

# Thunar
# 1. Prepare .desktop entry
LAUNCHER_ID=3003
LAUNCHER_NAME="thunar.desktop"
DESKTOP_ENTRY=$(cat <<'EOF'
[Desktop Entry]
Name=Thunar File Manager
Comment=Browse the filesystem with the file manager
GenericName=File Manager
Keywords=file manager;explorer;finder;browser;folders;directory;directories;partitions;drives;network;devices;rename;move;copy;delete;permissions;home;trash;
Exec=thunar %U
Icon=org.xfce.thunar
Terminal=false
StartupNotify=true
Type=Application
Categories=System;Core;GTK;FileTools;FileManager;
MimeType=inode/directory;
Actions=open-home;open-computer;open-trash;
X-XFCE-Source=file:///usr/share/applications/thunar.desktop

[Desktop Action open-home]
Name=Home
Exec=thunar %U

[Desktop Action open-computer]
Name=Computer
Exec=thunar computer:///

[Desktop Action open-trash]
Name=Trash
Exec=thunar trash:///
EOF
)

mkdir -p "$LAUNCHERS_DIR/launcher-$LAUNCHER_ID"
echo $DESKTOP_ENTRY > "$LAUNCHERS_DIR/launcher-$LAUNCHER_ID/$LAUNCHER_NAME"

# 2. Inject launcher definition
LAUNCHER_XML=$(cat <<EOF
<property name="plugin-$LAUNCHER_ID" type="string" value="launcher">
  <property name="items" type="array">
    <value type="string" value="$LAUNCHER_NAME"/>
  </property>
</property>
EOF
)
echo "$LAUNCHER_XML" > "$TEMP_DIR/launcher.xml"
xmlstarlet ed -s '//property[@name="plugins"]' -t elem -n PLACEHOLDER -v '' $PANEL_CFG_FILE > $TEMP_CFG_FILE

sed -i "/<PLACEHOLDER\/>/ {
    r $TEMP_DIR/launcher.xml
    d
}" "$TEMP_CFG_FILE"

cp $TEMP_CFG_FILE $PANEL_CFG_FILE


# Remove temp dir
rm -rf "$TEMP_DIR"


read -rp "🔁 Reboot now? [y/N]: " answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  echo "🔄 Rebooting..."
  sudo reboot
else
  echo "Skipped, reboot at a later time."
fi

