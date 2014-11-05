#!/bin/bash

#
# Script (freqVectorsEdit.sh) to add 'FrequencyVectors' from a source plist to Mac-F60DEB81FF30ACF6.plist
#
# Version 1.3 - Copyright (c) 2013-2014 by Pike R. Alpha
#
# Updates:
#			- v0.5	Show Mac model info (Pike R. Alpha, December 2013)
#			-       Check for 'FrequencyVectors' in the Resource directory (Pike R. Alpha, December 2014)
#			-       Touch /S*/L*/Extensions (Pike R. Alpha, Januari 2014)
#			-       Ask if the user wants to reboot (Pike R. Alpha, Februari 2014)
#			- v0.6	Bug report/feedback info/link added (Pike R. Alpha, April 2014)
#			- v0.7	Cleanups/comments added (Pike R. Alpha, April 2014)
#			-       Implement gCallOpen like ssdtPRGen.sh (Pike R. Alpha, April 2014)
#			-       Implement _findPlistBuddy like ssdtPRGen.sh (Pike R. Alpha, April 2014)
#			- v0.8	Curl link and other typos fixed (Pike R. Alpha, April 2014)
#			- v0.9	Implement _selectEditor like dpEdit.sh (Pike R. Alpha, April 2014)
#			-       function _convertXML2BIN added (Pike R. Alpha, May 2014)
#			- v1.0	board-id's of the late iMac and Mac mini added (Pike R. Alpha, October 2014)
#			- v1.1	board-id's of the late 2014 iMac corrected (Pike R. Alpha, October 2014)
#			- v1.2	Implement _clearLines like AppleIntelFramebufferAzul.sh (Pike R. Alpha, October 2014)
#			-       Implement _showDelayedDots like AppleIntelFramebufferAzul.sh
#			- v1.3  Implement _invalidMenuAction like AppleIntelFramebufferAzul.sh (Pike R. Alpha, November 2014)
#			-       Implement _toLowerCase like AppleIntelFramebufferAzul.sh
#			-       Option 'Exit' to menus added (Pike R. Alpha, November 2014)
#			-       Improved layout of menus / styling added like AppleIntelFramebufferAzul.sh
#

# Bugs:
#			- Bug reports can be filed at https://github.com/Piker-Alpha/freqVectorsEdit.sh/issues
#			  Please provide clear steps to reproduce the bug, the output of the script. Thank you!
#

#================================= GLOBAL VARS ==================================

#
# Script version info.
#
gScriptVersion=1.3

#
# This variable is set to 1 by default and changed to 0 during the first run.
#
let gFirstRun=1

#
# Possible editors.
#
#gXcode="/Applications/Xcode.app/Contents/MacOS/Xcode"
gXcode="/usr/bin/open -Wa /Applications/Xcode.app"
gNano="/usr/bin/nano"
gVi="/usr/bin/vi"

#
# This is the selected editor. By default it is set to: "$gNano"
# and later, during the first run, updated (do not change this).
#

gEditor="$gXcode"

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
Mac-81E3E92DD6088272:iMac14,4
Mac-42FD25EABCABB274:iMac15,1
Mac-FA842E06C61E91C5:iMac15,2
Mac-189A3D4F975D5FFC:MacBookPro11,1
Mac-3CBD00234E554E41:MacBookPro11,2
Mac-2BD1B31983FE1663:MacBookPro11,3
Mac-35C1E88140C3E6CF:MacBookAir6,1
Mac-7DF21CB3ED6977E5:MacBookAir6,2
Mac-F60DEB81FF30ACF6:MacPro6,1
Mac-35C5E08120C7EEAF:Macmini7,1
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
let gDebug=0

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
# 
#
gTargetFileNames=""

#
# Output styling.
#
STYLE_RESET="\e[0m"
STYLE_BOLD="\e[1m"
STYLE_UNDERLINED="\e[4m"

#
# Color definitions.
#
COLOR_BLACK="\e[1m"
COLOR_RED="\e[1;31m"
COLOR_GREEN="\e[32m"
COLOR_DARK_YELLOW="\e[33m"
COLOR_MAGENTA="\e[1;35m"
COLOR_PURPLE="\e[35m"
COLOR_CYAN="\e[36m"
COLOR_BLUE="\e[1;34m"
COLOR_ORANGE="\e[31m"
COLOR_GREY="\e[37m"
COLOR_END="\e[0m"

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
      echo $1
  fi
}

#
#--------------------------------------------------------------------------------
#

function _clearLines()
{
  let lines=$1

  if [[ ! lines ]];
    then
      let lines=1
  fi

  for ((line=0; line < lines; line++));
  do
    printf "\e[A\e[K"
  done
}

#
#--------------------------------------------------------------------------------
#

function _showDelayedDots()
{
  local let index=0

  while [[ $index -lt 3 ]]
  do
    let index++
    sleep 0.150
    printf "."
  done

  sleep 0.200

  if [ $# ];
    then
      printf $1
  fi
}

#
#--------------------------------------------------------------------------------
#

function _invalidMenuAction()
{
  _PRINT_ERROR "Invalid choice!\n       Retrying "
  _showDelayedDots
  _clearLines $1+6
}

#
#--------------------------------------------------------------------------------
#

function _toLowerCase()
{
  echo "`echo $1 | tr '[:upper:]' '[:lower:]'`"
}

#
#--------------------------------------------------------------------------------
#

function _showHeader()
{
  echo "freqVectorsEdit.sh v${gScriptVersion} Copyright (c) 2013-$(date "+%Y") by Pike R. Alpha."
  echo '-----------------------------------------------------------------'
  echo 'Bugs > https://github.com/Piker-Alpha/freqVectorsEdit.sh/issues <'
  echo ''
}

#
#--------------------------------------------------------------------------------
#

function _DEBUG_PRINT()
{
  if [[ $gDebug -eq 1 ]];
    then
      echo $1
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
      echo 'Aborting ...'
      echo '${STYLE_BOLD}Done.${STYLE_RESET}'
    else
      echo 'Aborting ...'
      echo 'Done.'
  fi

  echo ''

  exit 1
}

#
#--------------------------------------------------------------------------------
#

function _selectEditor()
{
  if [[ $gFirstRun -eq 1 ]];
    then
      echo 'First run detected, select editor:'
      echo ''
      echo '[ 1 ] Xcode'
      echo '[ 2 ] nano'
      echo '[ 3 ] vi'
      echo ''
      printf "Please choose the editor that you want to use (${STYLE_UNDERLINED}E${STYLE_RESET}xit/1/2/3)"
      read -p " ? " editorSelection
      case "$(_toLowerCase $editorSelection)" in
        1     ) _DEBUG_PRINT XCODE_SELECTED_AS_EDITOR
                dpEdit=$(sudo sed -l '/^let gFirstRun=/ s/1/0/' "$0")
                echo "$dpEdit" | sed '/^gEditor=/ s/"$gNano"/"$gXcode"/' > "$0"
                gEditor="$gXcode"
                ;;

        2     ) _DEBUG_PRINT NANO_SELECTED_AS_EDITOR
                dpEdit=$(sudo sed -l '/^let gFirstRun=/ s/1/0/' "$0")
                echo "$dpEdit" | sed '/^gEditor=/ s/"$gNano"/"$gNano"/' > "$0"
                gEditor="$gNano"
                ;;

        3     ) _DEBUG_PRINT VI_SELECTED_AS_EDITOR
                dpEdit=$(sudo sed -l '/^let gFirstRun=/ s/1/0/' "$0")
                echo "$dpEdit" | sed '/^gEditor=/ s/"$gNano"/"$gVi"/' > "$0"
                gEditorID="$gVi"
                ;;

        e|exit) printf 'Aborting script '
                _showDelayedDots
                _clearLines 8
                echo 'Done'
                exit -0
                ;;

        *     ) _invalidMenuAction 3
                _selectEditor
                ;;
      esac

      _clearLines 7
    else
      _DEBUG_PRINT NOT_FIRST_RUN
  fi
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
  #
  # Show 'Unknown' for unsupported plists.
  #
  echo "Unknown"
}

#
#--------------------------------------------------------------------------------
#

function _getResourceFiles()
{
  cd "${gPath}"

  gTargetFileNames=($(grep -rlse 'FrequencyVectors' .))

  if [[ "${#gTargetFileNames[@]}" -eq 0 ]];
    then
      _PRINT_ERROR 'No FrequencyVector data found in X86PlatformPlugin.kext!'
      _ABORT
    else
      _DEBUG_PRINT "${#gTargetFileNames[@]} plists found with FrequencyVectors"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _selectSourceResourceFile()
{
  local index=0
  local selection=0

  echo 'Available resource files (plists) with FrequencyVectors:'
  echo ''

  for filename in "${gTargetFileNames[@]}"
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

    printf " [ %2d ] $file / $model" $index
    echo ''
  done
  #
  #
  #
  echo ''
  #
  # Let user make a selection.
  #
  printf "Please choose the desired plist for your hardware (${STYLE_UNDERLINED}E${STYLE_RESET}xit/1-${index})"
  read -p " ? " selection
  case "$(_toLowerCase $selection)" in
    e|exit       ) printf 'Aborting script '
                   _showDelayedDots
                   _clearLines 5+$index
                   echo 'Done'
                   exit -0
                   ;;

    [[:digit:]]* ) if [[ $selection -lt 1 || $selection -gt $index ]];
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
                     gSourcePlist=${gTargetFileNames[$selection]}

                     _DEBUG_PRINT "gSourcePlist: $gSourcePlist"
                   fi
                   ;;

    *            ) _invalidMenuAction $index
                   _selectSourceResourceFile
                   ;;
  esac
  #
  #
  echo ''
}

#
#--------------------------------------------------------------------------------
#

function _convertXML2BIN()
{
  local index=0

  echo 'Converting XML data to binary files... '

  for plist in "${gTargetFileNames[@]}"
  do
    #
    # Convert filename.
    #
    local filename=$(echo "$plist" | sed -e 's/\.\///' -e 's/\.plist/\.bin/')
    #
    # Export the FrequencyVectors (with help of the Print command) to /tmp/FrequencyVectors.bin
    #
    /usr/libexec/PlistBuddy -c "Print IOPlatformPowerProfile:FrequencyVectors" "${plist}" > /tmp/${filename}
    #
    # Now we remove the 'complimentary' 0x0A byte – something we don't want.
    #
    perl -pi -e 'chomp if eof' /tmp/${filename}
    #
    #
    #
    local filesize=$(stat -f%z /tmp/$filename)
    echo ''
    echo "${gTargetFileNames[$index]} converted to: /tmp/${filename} ($filesize bytes)"

    if [[ $(grep -c 'BACKGROUND' /tmp/$filename) -eq 1 ]];
      then
        printf ' BACKGROUND'
    fi

    if [[ $(grep -c 'REALTIME_SHORT' /tmp/$filename) -eq 1 ]];
      then
        printf ' REALTIME_SHORT'
    fi

    if [[ $(grep -c 'THRU_TIER4' /tmp/$filename) -eq 1 ]];
      then
        printf ' THRU_TIER4'
    fi

    if [[ $(grep -c 'THRU_TIER5' /tmp/$filename) -eq 1 ]];
      then
        printf ' THRU_TIER5'
    fi

    if [[ $(grep -c 'hard-rt-ns' /tmp/$filename) -eq 1 ]];
      then
        echo ''
        printf ' hard-rt-ns'
    fi

    if [[ $(grep -c 'ubpc' /tmp/$filename) -eq 1 ]];
      then
        printf ' ubpc'
    fi

    if [[ $(grep -c 'off' /tmp/$filename) -eq 1 ]];
      then
        printf ' off'
    fi

    if [[ $(grep -c 'perf-bias' /tmp/$filename) -eq 1 ]];
      then
        printf ' perf-bias'
    fi

    #
    #
    #
    let index+=1

    echo ''
  done

  echo ''
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
      echo 'PlistBuddy not found ... Downloading PlistBuddy ...'
      curl https://raw.github.com/Piker-Alpha/freqVectorsEdit.sh/master/Tools/PlistBuddy -o /usr/libexec/PlistBuddy --create-dirs
      chmod +x /usr/libexec/PlistBuddy
      printf 'Done.'
  fi
}

#
#--------------------------------------------------------------------------------
#

function main()
{
  _showHeader
  _selectEditor
  #
  # Check if PlistBuddy is installed – download it when missing.
  #
  _findPlistBuddy
  _getResourceFiles

  if [ gDebug ];
    then
      _convertXML2BIN
  fi

  _selectSourceResourceFile
  _getBoardID
  _getModelID

  _DEBUG_PRINT "gBoardID: ${gBoardID}"
  _DEBUG_PRINT "gModelID: ${gModelID}"
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
  echo ''
  echo 'Triggering a kernelcache refresh ...'
  touch "${gExtensionsDirectory}"
  #
  # Ask for confirmation before opening the plist?
  #
  if [[ $gCallOpen -eq 2 ]];
    then
      #
      #
      #
      echo ''
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
      esac
  fi
  #
  # Should we open the Mac-*.plist?
  #
  if [[ $gCallOpen -eq 1 ]];
    then
      #
      # Yes. Open Mac-*.plist in TextEdit.
      #
      _DEBUG_PRINT "Launching $gEditor for: ${gTargetPlist}"
      $gEditor "${gTargetPlist}"
  fi

  read -p "Do you want to reboot now? (y/n) " choice
  case "$choice" in
    y|Y) reboot now
         ;;
  esac

  echo ''
}

#==================================== START =====================================

clear

if [[ $gID -ne 0 ]];
  then
    printf "This script ${STYLE_UNDERLINED}must${STYLE_RESET} be run as root!" 1>&2
    echo ''
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
