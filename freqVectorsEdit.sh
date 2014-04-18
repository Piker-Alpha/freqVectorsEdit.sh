#!/bin/sh

#
# Script (freqVectorsEdit.sh) to add 'FrequencyVectors' from a source plist to Mac-F60DEB81FF30ACF6.plist
#
# Version 0.7 - Copyright (c) 2013-2014 by Pike R. Alpha
#
# Updates:
#			- Show Mac model info (Pike R. Alpha, December 2013)
#			- Check for 'FrequencyVectors' in the Resource directory (Pike R. Alpha, December 2014)
#			- Touch /S8/L*/Extensions (Pike R. Alpha, Januari 2014)
#			- Ask if the user wants to reboot (Pike R. Alpha, Februari 2014)
#			- Bug report/feedback info/link added (Pike R. Alpha, April 2014)
#			- Cleanups/comments added (Pike R. Alpha, April 2014)
#			- Implement gCallOpen like ssdtPRGen.sh (Pike R. Alpha, April 2014)
#			- Implement _findPlistBuddy like ssdtPRGen.sh (Pike R. Alpha, April 2014)
#

# Bugs:
#			- Bug reports can be filed at https://github.com/Piker-Alpha/freqVectorsEdit.sh/issues
#			  Please provide clear steps to reproduce the bug, the output of the script. Thank you!
#

#================================= GLOBAL VARS ==================================

#
# Script version info.
#
gScriptVersion=0.7

#
# Initialised in function _listmatchingFiles()
#
gSourcePlist=""

#
# Hardcoded to MacPro6,1
#
gTargetPlist="Mac-F60DEB81FF30ACF6.plist"

#
#
#
gExtensionsDirectory="/System/Library/Extensions"

#
# Path to kext.
#
gPath="${gExtensionsDirectory}/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources/"

#
# Known board-id:model combos of configurations with a Haswell processor,
# except for Mac-F60DEB81FF30ACF6:MacPro6,1 – our target board-id/model.
#

gHaswellModelData=(
Mac-031B6874CF7F642A:iMac14,1
Mac-27ADBB7B4CEE8E61:iMac14,2
Mac-77EB7D7DAF985301:iMac14,3
Mac-189A3D4F975D5FFC:MacBookPro11,1
Mac-3CBD00234E554E41:MacBookPro11,2
Mac-2BD1B31983FE1663:MacBookPro11,3
Mac-35C1E88140C3E6CF:MacBookAir6,1
Mac-7DF21CB3ED6977E5:MacBookAir6,2
Mac-F60DEB81FF30ACF6:MacPro6,1
)

#
# Get user id
#
let gID=$(id -u)

#
# Change this to 0 if you don't want additional styling (bold/underlined).
#
let gExtraStyling=1

#
# Setting the debug mode (default off).
#
let gDebug=1

#
# Global variable used for the used/target board-id.
#
gBoardID=""

#
# Global variable used for the used/target board-id.
#
gModelID=""

#
# Open generated SSDT on request (default value is 2).
#
# 0 = don't open the plist.
# 1 = open the plist in the editor of your choice.
# 2 = ask for confirmation before opening the plist in the editor of your choice.
#
let gCallOpen=2

#
# Output styling.
#
STYLE_RESET="[0m"
STYLE_BOLD="[1m"
STYLE_UNDERLINED="[4m"


#
#--------------------------------------------------------------------------------
#

function _PRINT()
{
  #
  # Fancy output style?
  #
  if [[ $gExtraStyling -eq 1 ]];
    then
      #
      # Yes. Use a somewhat nicer output style.
      #
      printf "${STYLE_BOLD}${1}${STYLE_RESET}"
    else
      #
      # No. Use the basic output style.
      #
      printf "${1}"
  fi
}


#
#--------------------------------------------------------------------------------
#

function _showHeader()
{
  printf "freqVectorsEdit.sh v${gScriptVersion} Copyright (c) 2013-$(date "+%Y") by Pike R. Alpha.\n"
  echo "-----------------------------------------------------------------"
  printf "Bugs > https://github.com/Piker-Alpha/freqVectorsEdit.sh/issues <\n\n"
}


#
#--------------------------------------------------------------------------------
#

function _DEBUG_PRINT()
{
  if [[ $gDebug -eq 1 ]];
    then
      printf "$1"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _PRINT_ERROR()
{
  if [[ $gExtraStyling -eq 1 ]];
    then
      printf "${STYLE_BOLD}Error:${STYLE_RESET} $1"
    else
      printf "Error: $1"
  fi
}


#
#--------------------------------------------------------------------------------
#
function _ABORT()
{
  if [[ $gExtraStyling -eq 1 ]];
    then
      printf "Aborting ...\n${STYLE_BOLD}Done.${STYLE_RESET}\n\n"
    else
      printf "Aborting ...\nDone.\n\n"
  fi

  exit 1
}


#
#--------------------------------------------------------------------------------
#

function _getModelID()
{
  #
  # Grab 'compatible' property from ioreg (stripped with sed / RegEX magic).
  #
  gModelID=$(ioreg -p IODeviceTree -d 2 -k compatible | grep compatible | sed -e 's/ *["=<>]//g' -e 's/compatible//')
}


#
#--------------------------------------------------------------------------------
#

function _getBoardID()
{
  #
  # Grab 'board-id' property from ioreg (stripped with sed / RegEX magic).
  #
  gBoardID=$(ioreg -p IODeviceTree -d 2 -k board-id | grep board-id | sed -e 's/ *["=<>]//g' -e 's/board-id//')
}


#
#--------------------------------------------------------------------------------
#

function _getModelByPlist()
{
  #
  # Strip '.plist' from filename.
  #
  local targetModel=$(echo "$1" | sed 's/\.plist//')
  #
  #
  #
  local modelDataList="gHaswellModelData[@]"
  #
  # Split 'modelDataList' into array.
  #
  local targetList=("${!modelDataList}")
  #
  # Change delimiter to a colon character.
  #
  IFS=":"
  #
  # Loop through target list.
  #
  for modelData in "${targetList[@]}"
  do
    #
    # Split 'modelData' into array.
    #
    data=($modelData)

    if [[ "${data[0]}" == "${targetModel}" ]];
      then
        #
        # Restore default (0) delimiter.
        #
        IFS=$ifs
        #
        # Model found.
        #
        echo "${data[1]}"
        #
        #
        #
        return
    fi
  done
  #
  # Restore default (0) delimiter.
  #
  IFS=$ifs
}


#
#--------------------------------------------------------------------------------
#

function _listmatchingFiles()
{
  cd "${gPath}"

  local index=0
  local selection=0
  local fileNames=($(grep -rlse 'FrequencyVectors' .))

  if [[ "${#fileNames[@]}" -eq 0 ]];
    then
      _PRINT_ERROR "No FrequencyVector data found in X86PlatformPlugin.kext!\n"
      _ABORT
  fi

  printf "\nAvailable resource files (plists) with FrequencyVectors:\n\n"

  for filename in "${fileNames[@]}"
  do
    let index++
    #
    # Strip filename.
    #
    local file=$(echo "$filename" | sed 's/\.\///')
    #
    # Match board-id with model name.
    #
    local model=$(_getModelByPlist $file)

    printf " [%d] - ${file} / ${model}\n" ${index}
  done

  printf "\nPlease choose the desired plist for your hardware "
  #
  # Let user make a selection.
  #
  read -p "[1-${index}]: " selection
  #
  # Check user input.
  #
  if [[ $selection < 1 || $selection > $index ]];
    then
      clear
      _showHeader
      _listmatchingFiles
    else
      #
      # Lower selection (arrays start at zero).
      #
      let selection-=1
      #
      # Initialise global variable with the selected plist.
      #
      gSourcePlist=${fileNames[$selection]}

      _DEBUG_PRINT "gSourcePlist: ${gSourcePlist}\n"
  fi
}


#
#--------------------------------------------------------------------------------
#

function _findPlistBuddy()
{
  #
  # Lookup PlistBuddy (should be there after the first run).
  #
  if [ ! -f /usr/libexec/PlistBuddy ];
    then
      printf "\nPlistBuddy not found ... Downloading PlistBuddy ...\n"
      curl https://raw.github.com/Piker-Alpha/freqVectors.sh/Tools/iasl -o /usr/libexec/PlistBuddy --create-dirs
      chmod +x /usr/libexec/PlistBuddy
      printf "Done."
  fi
}


#
#--------------------------------------------------------------------------------
#

function main()
{
  _showHeader
  _listmatchingFiles

  _getBoardID
  _DEBUG_PRINT "gBoardID: ${gBoardID}\n"

  _getModelID
  _DEBUG_PRINT "gModelID: ${gModelID}\n"
  #
  # Check if PlistBuddy is installed – download it when missing.
  #
  _findPlistBuddy
  #
  # Export the FrequencyVectors (with help of the Print command) to /tmp/FrequencyVectors.bin
  #
  /usr/libexec/PlistBuddy -c "Print IOPlatformPowerProfile:FrequencyVectors" "${gSourcePlist}" > /tmp/FrequencyVectors.bin
  #
  # Now we remove the 'complimentary' 0x0A byte – something we don't want.
  #
  perl -pi -e 'chomp if eof' /tmp/FrequencyVectors.bin
  #
  # Import FrequencyVectors into Mac-F60DEB81FF30ACF6.plist
  #
  /usr/libexec/PlistBuddy -c "Import IOPlatformPowerProfile:FrequencyVectors /tmp/FrequencyVectors.bin" ${gTargetPlist}
  #
  #
  #
  _DEBUG_PRINT "Triggering a kernelcache refresh ...\n"
  touch "${gExtensionsDirectory}"
  #
  # Ask for confirmation before opening the plist?
  #
  if [[ $gCallOpen -eq 2 ]];
    then
      #
      # Yes. Ask for confirmation.
      #
      read -p "Do you want to open ${gTargetPlist} (y/n)? " openAnswer
      case "$openAnswer" in
          y|Y ) #
                # Ok. Override default behaviour.
                #
                let gCallOpen=1
          ;;
  fi
  #
  # Should we open the Mac-*.plist?
  #
  if [[ $gCallOpen -eq 1 ]];
    then
      #
      # Yes. Open Mac-*.plist in TextEdit.
      #
      open -e "${gTargetPlist}""
  fi

  read -p "Do you want to reboot now? (y/n) " choice
  case "$choice" in
    y|Y ) reboot now
          ;;
  esac
}

#==================================== START =====================================

clear

if [[ $gID -ne 0 ]];
  then
    echo "This script ${STYLE_UNDERLINED}must${STYLE_RESET} be run as root!" 1>&2
    #
    # Re-run script with arguments.
    #
    sudo "$0" "$@"
  else
    #
    # We are root. Call main with arguments.
    #
    main "$@"
fi
