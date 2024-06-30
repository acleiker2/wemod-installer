## // initialize bash script
#!/bin/bash

## Identify all installed proton versions including GE-Proton
proton_versions=$(ls -d ~/.steam/root/compatibilitytools.d/* | grep -oP '(?<=compatibilitytools.d/).*')
wemod_dir=~/.local/share/wemod/bin/
wemoddata_dir=~/.local/share/wemod/data
wemod_path=~/.local/share/wemod/bin/WeMod.exe

#echo "Installed Proton versions: $proton_versions"
## Prompt user to select a proton version to use
echo "Select a Proton version to use: "
select pv in $proton_versions; do
  echo "Proton version selected: $pv"
  break
done

## Identify steam games from appmanifest files and enclose the names in quotes
mapfile -t steam_games < <(for file in ~/.steam/steam/steamapps/appmanifest_*.acf; do
        grep '"name"' "$file" | head -1 | cut -d\" -f4
done)

echo "Steam games:"
PS3="Select a game: "
select game in "${steam_games[@]}"; do
    echo "Game selected: $game"
    break
done

## Identify the game's appid from chosen $game 's appmanifest file'
appid=$(grep -l "\"name\".*\"$game\"" ~/.steam/steam/steamapps/appmanifest_*.acf | grep -oP '(?<=appmanifest_)\d+')
echo "AppID: $appid"

## Create a variable named protonpfx_path from $appid
protonpfx_path=~/.steam/steam/steamapps/compatdata/$appid/pfx
echo "Proton prefix path: $protonpfx_path"

echo "Preparing proton prefix for wemod compatibility..."
echo "This process may take a while"


## Check if folder exists at $protonpfx_path

## Check if dotnet40 and dotnet48 are installed in the prefix
if [ -d "$protonpfx_path/drive_c/windows/Microsoft.NET/Framework/v4.0.30319" ]; then
    echo "dotnet40 is installed in the proton prefix"
else
    echo "dotnet40 is not installed in the proton prefix"
## Use winetricks to install dotnet40 and dotnet 48 to the proton prefix and use the proton version for the wine version
WINEPREFIX="$protonpfx_path" winetricks -q dotnet40
echo "Installing dotnet40 in the proton prefix..."
fi
## Check if dotnet48 is installed in the prefix
if [ -d "$protonpfx_path/drive_c/windows/Microsoft.NET/Framework/v4.8.04084" ]; then
    echo "dotnet48 is installed in the proton prefix"
else
    echo "dotnet48 is not installed in the proton prefix"
    WINEPREFIX="$protonpfx_path" winetricks -q dotnet48
fi

## Install and setup WeMod in the future.. For now though just use the following path

## Check if wemod user data exists at $wemoddata_dir
if [ -d $wemoddata_dir ]; then
    echo "WeMod user data exists at $wemoddata_dir"
else
    echo "WeMod user data does not exist at $wemoddata_dir"
    echo "Creating WeMod user data at $wemoddata_dir"
    mkdir -p $wemoddata_dir
fi

## Fucntion to download WeMod installer
download_wemod() {
  ## Check if wget is installed if not check for curl
  if [ -x "$(command -v wget)" ]; then
      echo "wget is installed"
      echo "Downloading WeMod installer..."
      wget -q -O ~/tmp/wemod/WeModSetup.exe https://api.wemod.com/client/download
  else
      echo "wget is not installed"
      if [ -x "$(command -v curl)" ]; then
          echo "curl is installed"
          echo "Downloading WeMod installer..."
          curl -s -o ~/tmp/wemod/WeModSetup.exe https://api.wemod.com/client/download
      else
          echo "curl is not installed"
          echo "Please install wget or curl and try again"
      fi
  fi

}
## Function to install WeMod
install_wemod() {
  download_wemod
  ## Check if unzip is installed
if [ -x "$(command -v unzip)" ]; then
    echo "unzip is installed"
    echo "Extracting WeMod installer..."
    unzip -q ~/tmp/wemod/WeModSetup.exe -d ~/tmp/wemod
else
    echo "unzip is not installed"
    echo "Please install unzip and try again"
fi
  ## unzip the WeMod-*-full.nupkg file we just extracted to ~/tmp/wemod
  unzip -q ~/tmp/wemod/WeMod-*-full.nupkg -d ~/tmp/wemod
  ## Copy the contents of ~/tmp/wemod/lib/net45 to $wemod_dir/
  cp -r ~/tmp/wemod/lib/net45/* $wemod_dir/
  ## clean up ~/tmp/wemod
  rm -rf ~/tmp/wemod
}

## Check if ~/.local/share/wemod/bin/WeMod.exe exists
## Check if wemod is installed at $wemod_path
if [ -f "$wemod_path" ]; then
    echo "WeMod is installed at $wemod_path"
else
    echo "WeMod is not installed at $wemod_path"
    echo "Installing WeMod to $wemod_dir"
    install_wemod
fi

## Check if $wemod_dir exists
if [ -d $wemod_dir ]; then
    echo "WeMod bin folder exists at $wemod_dir"
else
    echo "WeMod bin folder does not exist at $wemod_dir"
    echo "Creating WeMod bin folder at $wemod_dir"
    mkdir -p $wemod_dir
fi

## Check if wemod user data exists at $wemoddata_dir
if [ -d $wemoddata_dir ]; then
    echo "WeMod user data exists at $wemoddata_dir"
else
    echo "WeMod user data does not exist at $wemoddata_dir"
    echo "Creating WeMod user data at $wemoddata_dir"
    mkdir -p $wemoddata_dir
fi

## Check for the existance of symlink in $protonpfx_path/drive_c/users/steamuser/AppData/Roaming/WeMod
if [ -L "$protonpfx_path/drive_c/users/steamuser/AppData/Roaming/WeMod" ]; then
    echo "Symlink exists in $protonpfx_path/drive_c/users/steamuser/AppData/Roaming/WeMod"
else
    echo "Symlink does not exist in $protonpfx_path/drive_c/users/steamuser/AppData/Roaming/WeMod"
    echo "Creating symlink in $protonpfx_path/drive_c/users/steamuser/AppData/Roaming/WeMod"
    ln -s $wemoddata_dir $protonpfx_path/drive_c/users/steamuser/AppData/Roaming/WeMod
fi

## Check if steamtinkerlaunch is installed
if [ -x "$(command -v steamtinkerlaunch)" ]; then
    echo "steamtinkerlaunch is installed"
else
    echo "steamtinkerlaunch is not installed"
    echo "Please install steamtinkerlaunch and try again"
fi

stl_conf=~/.config/steamtinkerlaunch/gamecfgs/id/$appid.conf

## Check if steamtinkerlaunch has a configuration for the selected game and delete it
if [ -f $stl_conf ]; then
    echo "Configuration exists for $game in steamtinkerlaunch"
    echo "Deleting configuration for $game in steamtinkerlaunch"
    rm $stl_conf
else
    echo "Configuration does not exist for $game in steamtinkerlaunch"
fi

## Create a new configuration for the selected game in steamtinkerlaunch
echo "Creating configuration for $game in steamtinkerlaunch"
touch $stl_conf
echo 'USEPROTON="$pv"' >> $stl_conf
echo 'USECUSTOMCMD="1"' >> $stl_conf
echo "CUSTOMCMD="/home/$USER/.local/share/wemod/bin/WeMod.exe"" >> $stl_conf
echo 'FORK_CUSTOMCMD="1"' >> $stl_conf
echo 'CUSTOMCMDFORCEWIN="1"' >> $stl_conf
echo 'WAITFORCUSTOMCMD="5"' >> $stl_conf

## Inform user to launch the game using steamtinkerlaunch in steam
echo "Configuration for $game in steamtinkerlaunch has been created"
echo "Launch $game using steamtinkerlaunch in steam"