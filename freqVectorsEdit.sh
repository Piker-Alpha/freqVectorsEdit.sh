#!/bin/bash

#
# Script (freqVectorsEdit.sh) to add 'FrequencyVectors' from a source plist to Mac-F60DEB81FF30ACF6.plist
#
# Version 2.3 - Copyright (c) 2013-2016 by Pike R. Alpha
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
#			- v1.4  Use function _getBoardID to set target plist (Pike R. Alpha, November 2014)
#			- v1.5  Use defaults write to store preferences (Pike R. Alpha, December 2015)
#			-       Copied _checkLibraryDirectory from ssdtPRGen.sh
#			-       Copied _checkForConfigFile from ssdtPRGen.sh
#			-       Copied _getScriptArguments from ssdtPRGen.sh
#			-       Copied _invalidArgumentError from ssdtPRGen.sh
#			-       New function _getPMValue added to read PM data values.
#			-       New function _toLittleEndian added to convert values for function _getPMValue.
#			- v1.6  Now using Models.cfg from ssdtPRGen.sh (Pike R. Alpha, Januari 2016)
#			-       Function _getModelByPlist replaced by _getModelByBoardID
#			- v1.7  Unused function _getModelByPlist removed (Pike R. Alpha, Februari 2016)
#			-       Expand function _convertXML2BIN to show new/missing PM data.
#			- v1.8  Use defaults read to select the editor (Pike R. Alpha, Februari 2016)
#			-       Cleanups done, typo fixed, style nit and bug fixes.
#			- v1.9  Fix defaults read to select the editor (Pike R. Alpha, Februari 2016)
#			-       Variable gFirstRun removed (no longer used).
#			-       Calls to _showHeader and _selectEditor moved out of main.
#			- v2.0  Dump HWP and EPP settings (Pike R. Alpha, April 2016)
#			- v2.1  Fix regression in debug output (Pike R. Alpha, April 2016)
#			- v2.2  Remove StepContextDict from plist (Pike R. Alpha, July 2016)
#			- v2.3  Check for FrequencyVectors array added.
#			-       Add array for FrequencyVectors when it is missing.
#			-       Quick and dirty fix for Xcode-beta.app added.
#
#
# Known issues:
#
#			- Multiple FrequencyVectors in a plist are currently not supported/show up blank.
#			- Available plist are shown in random order instead of Haswell, Broadwell and Skylake.
#
#
# Bugs:
#			- Bug reports can be filed at https://github.com/Piker-Alpha/freqVectorsEdit.sh/issues
#			  Please provide clear steps to reproduce the bug, the output of the script. Thank you!
#

#================================= GLOBAL VARS ==================================

#
# Script version info.
#
gScriptVersion=2.3

#
# Path and filename setup.
#
gHome=$(echo $HOME)
gPath="${gHome}/Library/ssdtPRGen"
gDataPath="${gPath}/Data"
gPrefsPath="${gHome}/Library/Preferences"

#
# Possible editors.
#
gXcode="/usr/bin/open -Wa /Applications/Xcode.app"
gNano="/usr/bin/nano"
gVi="/usr/bin/vi"

#
# This is the selected editor. By default it is set to: "$gNano"
# and later, during the first run, updated (do not change this).
#

gEditor="$gNano"

#
# Initialised in function _listmatchingFiles()
#
gSourcePlist=""

#
# Initial target is MacPro6,1 (updated in function main)
#
gTargetPlist="Mac-F60DEB81FF30ACF6.plist"

#
#
#
gExtensionsDirectory="/System/Library/Extensions"

#
# Path to kext.
#
gResourcePath="${gExtensionsDirectory}/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources"

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
#--------------------------------------------------------------------------------
#

function _PRINT_MSG()
{
  local message=$1
  #
  # Fancy output style?
  #
  if [[ $gExtraStyling -eq 1 ]];
    then
      if [[ $message =~ 'Aborting ...' ]];
        then
          local message=$(echo $message | sed -e 's/^Aborting ...//')
          local messageType='Aborting ...'
        else
          local messageType=$(echo $message | sed -e 's/:.*//g')

          if [[ $messageType =~ ^"\n" ]];
            then
              local messageTypeStripped=$(echo $messageType | sed -e 's/^[\n]*//')
            else
              local messageTypeStripped=$messageType
          fi

          local message=":"$(echo $message | sed -e "s/^[\n]*${messageTypeStripped}://")
      fi

      printf "${STYLE_BOLD}${messageType}${STYLE_RESET}$message\n"
    else
      printf "${message}\n"
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
  _PRINT_MSG "Error: Invalid choice!\n       Retrying "
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
  printf "${STYLE_BOLD}freqVectorsEdit.sh${STYLE_RESET} v${gScriptVersion} Copyright (c) 2013-$(date "+%Y") by Pike R. Alpha.\n"
  echo '-----------------------------------------------------------------'
  printf "${STYLE_BOLD}Bugs${STYLE_RESET} > https://github.com/Piker-Alpha/freqVectorsEdit.sh/issues <\n\n"
}

#
#--------------------------------------------------------------------------------
#

function _DEBUG_PRINT()
{
  if [[ $gDebug -eq 1 ]];
    then
      echo -e $1
  fi
}

#
#--------------------------------------------------------------------------------
#
function _ABORT()
{
  _PRINT_MSG "Aborting ...\nDone.\n\n"

  exit $1
}

#
#--------------------------------------------------------------------------------
#

function _selectEditor()
{
  if [[ -f "${gPrefsPath}/com.wordpress.pikeralpha.plist" ]];
    then
      local editor=$(defaults read "${gPrefsPath}/com.wordpress.pikeralpha" freqVectorsEditor)

      case "$editor" in
        xcode) _DEBUG_PRINT XCODE_SELECTED_AS_EDITOR

               if [ -x /Applications/Xcode-beta.app ];
                 then
                   gXcode="/usr/bin/open -Wa /Applications/Xcode-beta.app"
               fi

               gEditor="$gXcode"
               ;;

        nano  ) _DEBUG_PRINT NANO_SELECTED_AS_EDITOR
                gEditor="$gNano"
                ;;

        vi    ) _DEBUG_PRINT VI_SELECTED_AS_EDITOR
                gEditor="$gVi"
                ;;
      esac
    else
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
                defaults write "${gPrefsPath}/com.wordpress.pikeralpha" freqVectorsEditor -string xcode
                gEditor="$gXcode"
                ;;

        2     ) _DEBUG_PRINT NANO_SELECTED_AS_EDITOR
                defaults write "${gPrefsPath}/com.wordpress.pikeralpha" freqVectorsEditor -string nano
                gEditor="$gNano"
                ;;

        3     ) _DEBUG_PRINT VI_SELECTED_AS_EDITOR
                defaults write "${gPrefsPath}/com.wordpress.pikeralpha" freqVectorsEditor -string vi
                gEditor="$gVi"
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

function _getResourceFiles()
{
  cd "${gResourcePath}"

  gTargetFileNames=($(grep -rlse 'FrequencyVectors' .))

  if [[ "${#gTargetFileNames[@]}" -eq 0 ]];
    then
      _PRINT_MSG 'Error: FrequencyVector data found in X86PlatformPlugin.kext!'
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
    # Strip path from filename.
    #
    local file=$(echo "$filename" | sed 's/\.\///')
    #
    # Get board-id (by chopping off the file extension).
    #
    local boardID=${file%.*}
    #
    # Match board-id with model name.
    #
    local model=$(_getModelByBoardID $boardID)
    #
    # Show item.
    #
    printf " [ %2d ] $file ($model)" $index
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

                   if [[ $gDebug -eq 1 ]];
                     then
                       _clearLines 8+$index
                     else
                       _clearLines 5+$index
                   fi

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

function _toLittleEndian()
{
  local data=$1
  local i=${#data}
  local value

  while [ $i -gt 0 ]
  do
    i=$[$i-2]
    value+=${data:$i:2}
  done

  let value="0x${value}"

  echo -n "$value"
}

#
#--------------------------------------------------------------------------------
#

function _getPMValue()
{
  local matchingData
  local filename="/tmp/${boardID}.dat"

  case "$1" in
    hard-rt-ns    ) # 68 61 72 64 2D 72 74 2D 6E 73 00 00 00 00 00 00 00 00 00 00 00 09 3D 00
                    matchingData=$(egrep -o '686172642d72742d6e730{20}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    ubpc          ) # 75 62 70 63 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00
                    matchingData=$(egrep -o '756270630{24}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:32:8}"
                    ;;

    off           ) # 6F 66 66 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '6F66660{18}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:24:8}"
                    ;;

    on            ) # 6F 6E 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '6F6E{28}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:24:8}"
                    ;;

    hwp           ) #
                    # HardWare-controlled Performance states.
                    #
                    # 68 77 70 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00
                    matchingData=$(egrep -o '6877700{26}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:32:8}"
                    ;;

    epp           ) #
                    # Energy Performance Preference.
                    #
                    # Conveys a hint to the HWP hardware. The OS may write a range of values from 0 (performance preference) to 0FFH (energy efficiency preference)
                    # to influence the rate of performance increase / decrease and the result of the hardware's energy efficiency and performance optimizations. The
                    # default value of this field is 80H.
                    #
                    # Note: If CPUID.06H:EAX[bit 10] indicates that this field is not supported, HWP uses the value of the IA32_ENERGY_PERF_BIAS MSR (perf-bias) to
                    #       determine the energy efficiency / performance preference.
                    #
                    # 65 70 70 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 92 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '6570700{34}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    perf-bias     ) # 70 65 72 66 2D 62 69 61 73 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00
                    # 70 65 72 66 2D 62 69 61 73 00 00 00 00 00 00 00 00 00 00 00 05 00 00 00
                    matchingData=$(egrep -o '706572662d626961730{22}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    utility-tlvl  ) # 75 74 69 6C 69 74 79 2D 74 6C 76 6C 00 00 00 00 00 00 00 00 28 00 00 00
                    # 75 74 69 6C 69 74 79 2D 74 6C 76 6C 00 00 00 00 00 00 00 00 3d 00 00 00
                    # 75 74 69 6C 69 74 79 2D 74 6C 76 6C 00 00 00 00 00 00 00 00 3e 00 00 00
                    # 75 74 69 6C 69 74 79 2D 74 6C 76 6C 00 00 00 00 00 00 00 00 4e 00 00 00
                    # 75 74 69 6C 69 74 79 2D 74 6C 76 6C 00 00 00 00 00 00 00 00 4f 00 00 00
                    matchingData=$(egrep -o '7574696c6974792d746c766c0{16}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    non-focal-tlvl) # 6E 6F 6E 2D 66 6F 63 61 6C 2D 74 6C 76 6C 00 00 00 00 00 00 FA 00 00 00
                    matchingData=$(egrep -o '6e6f6e2d666f63616c2d746c766c0{12}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    iocs_engage   ) # 69 6F 63 73 5F 65 6E 67 61 67 65 00 00 00 00 00 00 00 00 00 00 6A 18 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '696f63735f656e676167650{18}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    iocs_disengage) # 69 6F 63 73 5F 64 69 73 65 6E 67 61 67 65 00 00 00 00 00 00 A0 25 26 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '696f63735f646973656e676167650{12}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    iocs_cstflr   ) # 69 6F 63 73 5F 63 73 74 66 6C 72 00 00 00 00 00 00 00 00 00 03 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '696f63735f637374666c720{18}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;

    iocs_rtrigger ) # 69 6F 63 73 5F 72 74 72 69 67 67 65 72 00 00 00 00 00 00 00 64 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                    matchingData=$(egrep -o '696f63735f72747269676765720{14}[0-9a-f]{8}' "$filename")
                    _toLittleEndian "${matchingData:40:8}"
                    ;;
     *        )
                ;;
  esac
}


#
#--------------------------------------------------------------------------------
#

function _checkPlistForEntry()
{
  local entry=$1
  local plist=$2
  local result=$(/usr/libexec/PlistBuddy -x -c "Print ${entry}" "${plist}" 2>&1)

  if [[ $result =~ "Does Not Exist" ]];
    then
      return 0
  fi

  return 1
}


#
#--------------------------------------------------------------------------------
#

function _convertXML2BIN()
{
  local index=0

  printf "\nConverting XML data to binary files ...\n"

  for plist in "${gTargetFileNames[@]}"
  do
    #
    # Convert filename.
    #
    local filename=$(basename $plist)
    #
    # Get board-id (by chopping off the extension).
    #
    local boardID=${filename%.*}
    #
    # Export the FrequencyVectors (with help of the Print command) to /tmp/[board-id].bin
    #
    sudo /usr/libexec/PlistBuddy -c "Print IOPlatformPowerProfile:FrequencyVectors:0" "${plist}" > "/tmp/${boardID}.bin"
    #
    # Now we remove the trailing 0x0A byte – which we don't need.
    #
    sudo perl -pi -e 'chomp if eof' "/tmp/${boardID}.bin"
    #
    # Convert binary FrequencyVectors to data format.
    #
    sudo xxd -c 256 -ps "/tmp/${boardID}.bin" | tr -d '\n' > "/tmp/${boardID}.dat"
    #
    # Get filesize.
    #
    local filesize=$(stat -f%z "/tmp/${boardID}.bin")
    #
    # Get model identifier from board-id.
    #
    local model=$(_getModelByBoardID $boardID)
    #
    echo ''
    echo "Data from ${boardID}.plist ($model) converted to: /tmp/${boardID}.bin ($filesize bytes)"
    #
    #
    #
    _checkPlistForEntry "IOPlatformPowerProfile:Frequencies" "${plist}"
    #
    # Are there any Frequencies specified?
    #
    if [[ $? -eq 1 ]];
      then
        #
        # Yes.
        #
        local index=0
        #
        # frequencies is now something like this:
        #
        # Dict {
        #     2600 = 1
        #     2900 = 2
        #     2400 = 0
        # }
        #
        frequencies=$(echo $frequencies | sed -e 's/Dict {//' -e 's/}//'  -e 's/=//g')
        #
        # Now we have this.
        #
        #     2600 = 1
        #     2900 = 2
        #     2400 = 0
        #
        frequencies=($frequencies)
        #
        # And now this:
        #
        # 2600
        # 1
        # 2900
        # 2
        # 2400
        # 0
        #

       if [[ "${#frequencies[@]}" ]];
         then
           printf "${STYLE_BOLD}Frequencies:${STYLE_RESET} ${frequencies[0]} MHz (FrequencyVectors @ ${frequencies[1]})\n"
           let index+=2
       fi

       while [ $index -lt "${#frequencies[@]}" ];
       do
         printf "\t   - ${frequencies[${index}]} MHz "
         let index++
         printf "(FrequencyVectors @ ${frequencies[${index}]})\n"
         let index++
       done
    fi
    #
    # Data types.
    #
    local targetData=('BACKGROUND','REALTIME_SHORT','REALTIME_LONG','KERNEL','THRU_TIER1','THRU_TIER2','THRU_TIER3','THRU_TIER4','THRU_TIER5','GRAPHICS_SERVER','hard-rt-ns','ubpc','off','on','hwp','epp','perf-bias','utility-tlvl','non-focal-tlvl','iocs_engage','iocs_disengage','iocs_cstflr','iocs_rtrigger')
    #
    # Save default (0) delimiter.
    #
    local ifs=$IFS
    #
    # Change delimiter to a comma character.
    #
    IFS=","
    #
    # Split vars.
    #
    local data=($targetData)
    #
    # Restore the default (0) delimiter.
    #
    IFS=$ifs
    #
    #
    #
    local item=0
    local count=0
    #
    #
    #
    printf "${STYLE_BOLD}PM type(s): ${STYLE_RESET}"
    #
    #
    #
    for target in "${data[@]}"
    do
      let item+=1

      if [[ $count -gt 0 && $item -eq 10 || $item -eq 17 ]];
        then
          printf "\n\t    "
          let count=0
      fi

      if [[ $(grep -c "${target}" "/tmp/${boardID}.bin") -eq 1 ]];
        then
          if [[ $count -gt 0 ]];
            then
              printf ", "
          fi

          let count+=1

          printf "${target}"

          if [[ $item -ge 10 ]];
            then
              local value=$(_getPMValue $target)
              printf " (${value})"
          fi
      fi
    done
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
      sudo curl https://raw.github.com/Piker-Alpha/freqVectorsEdit.sh/master/Tools/PlistBuddy -o /usr/libexec/PlistBuddy --create-dirs
      sudo chmod +x /usr/libexec/PlistBuddy
      printf 'Done.'
  fi
}

#
#--------------------------------------------------------------------------------
#

function _checkForConfigFile
{
  #
  # Does the target file exist?
  #
  if [ ! -f "${gDataPath}/${1}" ];
    then
      #
      # No. Return state is 2.
      #
      return 1
  fi
  #
  #
  #
  if [[ $(wc -c "${gDataPath}/${1}" | awk '{print $1}') -lt 100 ]];
    then
      #
      # Remove file.
      #
      rm "${gDataPath}/$1"
      #
      # No. Return state is 3.
      #
      return 3
  fi

  return 0
}

#
#--------------------------------------------------------------------------------
#

function _invalidArgumentError()
{
  _PRINT_MSG "Error: Invalid argument detected: ${1} (check ssdtPRGen.sh -h)"

  _ABORT
}

#
#--------------------------------------------------------------------------------
#

function _getModelByBoardID()
{
  #
  # Model/board-id arrays from models.cfg
  #
  local modelData=("gHaswellModelData[@]" "gBroadwellModelData[@]" "gSkylakeModelData[@]")
  #
  # Loop through the available model data.
  #
  for dataset in "${modelData[@]}"
  do
    #
    # Split 'dataset' into array 'targetList'.
    #
    local targetList=("${!dataset}")
    #
    # Loop through the target list.
    #
    for currentModel in "${targetList[@]}"
    do
      local boardID="${currentModel%:*}"

      if [[ $1 =~ $boardID ]];
        then
          #
          # Get model (by chopping off the colon and board-id).
          #
          echo "${currentModel##*:}"
          break
      fi
    done
  done
}

#
#--------------------------------------------------------------------------------
#

function _showSupportedBoardIDsAndModels()
{
  #
  # Save default (0) delimiter.
  #
  local ifs=$IFS
  #
  # Setup a local variable pointing to a list with supported model data.
  #
  case "$1" in
      Haswell) local modelDataList="gHaswellModelData[@]"
               ;;
    Broadwell) local modelDataList="gBroadwellModelData[@]"
               ;;
      Skylake) local modelDataList="gSkylakeModelData[@]"
               ;;
  esac
  #
  # Split 'modelDataList' into array.
  #
  local targetList=("${!modelDataList}")

  printf "${STYLE_BOLD}$1${STYLE_RESET}\n"
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
    local data=($modelData)
    echo "${data[0]} / ${data[1]}"
  done
  #
  # Restore the default (0) delimiter.
  #
  IFS=$ifs
  #
  # Print extra newline for a cleaner layout.
  #
  printf "\n"
}

#
#--------------------------------------------------------------------------------
#

function _checkLibraryDirectory()
{
  #
  # Do we have the ssdtPRGen.sh data directory?
  #
  if [ ! -d "${gDataPath}" ];
    then
      #
      # No. Not there. Create the directory.
      #
      mkdir -p "${gDataPath}"
  fi

  _checkForConfigFile "Models.cfg"

  if [[ $? -ge 1 ]];
    then
      #
      # Not there or damaged. Download it from the ssdtPRGen.sh repository.
      #
      curl -o "${gDataPath}/Models.cfg" --silent https://raw.githubusercontent.com/Piker-Alpha/ssdtPRGen.sh/Beta/Data/Models.cfg
  fi
  #
  # Load model data.
  #
  source "${gDataPath}/Models.cfg"
}

#
#--------------------------------------------------------------------------------
#

function _getScriptArguments()
{
  #
  # Are we fired up with arguments?
  #
  if [ $# -gt 0 ];
    then
      #
      # Yes. Do we have a single (-help) argument?
      #
      local argument=$(echo "$1" | tr '[:upper:]' '[:lower:]')

      if [[ $# -eq 1 && "$argument" == "-h" || "$argument" == "-help"  ]];
        then
          printf "\n${STYLE_BOLD}Usage:${STYLE_RESET} ./freqVectorEdit.sh [-bhmosw]\n"
          printf "       -${STYLE_BOLD}b${STYLE_RESET}oard-id (example: Mac-F60DEB81FF30ACF6)\n"
          printf "       -${STYLE_BOLD}d${STYLE_RESET}ebug output:\n"
          printf "          0 = no debug output\n"
          printf "          1 = debug output\n"
          printf "       -${STYLE_BOLD}m${STYLE_RESET}odel (example: MacPro6,1)\n"
          printf "       -${STYLE_BOLD}show${STYLE_RESET} supported board-id and model combinations:\n"
          printf "          Haswell\n"
          printf "          Broadwell\n"
          printf "          Skylake\n"
          #
          # Stop script (success).
          #
          exit 0
      fi

      if [[ $# -eq 1 && "$argument" == "-show" ]];
        then
          printf "\nSupported board-id / model combinations for:\n"
          echo -e "--------------------------------------------\n"

          _showSupportedBoardIDsAndModels "Skylake"
          _showSupportedBoardIDsAndModels "Broadwell"
          _showSupportedBoardIDsAndModels "Haswell"
          #
          # Stop script (success).
          #
          exit 0
      fi

      if [[ $# -eq 2 && "$argument" == "-show" ]];
        then
          printf "\nSupported board-id / model combinations for:\n"
          echo -e "--------------------------------------------\n"

          case "$(echo $2 | tr '[:lower:]' '[:upper:]')" in
            HASWELL  ) _showSupportedBoardIDsAndModels "Haswell"
                       ;;
            BROADWELL) _showSupportedBoardIDsAndModels "Broadwell"
                       ;;
            SKYLAKE)   _showSupportedBoardIDsAndModels "Skylake"
                       ;;
          esac
          #
          # Stop script (success).
          #
          exit 0
        else
          #
          # Figure out what arguments are used.
          #
          while [ "$1" ];
          do
            #
            # Store lowercase value of $1 in $flag
            #
            local flag=$(echo "$1" | tr '[:upper:]' '[:lower:]')
            #
            # Is this a valid flag?
            #
            if [[ "${flag}" =~ ^[-bdm]+$ ]];
              then
                #
                # Yes. Figure out what flag it is.
                #
                case "${flag}" in
                  -b) shift

                      if [[ "$1" =~ ^Mac-[0-9A-F]+$ ]];
                        then
                          if [[ $gBoardID != "$1" ]];
                            then
                              gBoardID=$1
                              _PRINT_MSG "Override value: (-b) board-id, now using: ${gBoardID}!"
                          fi
                        else
                          _invalidArgumentError "-b $1"
                      fi
                      ;;

                  -d) shift

                      if [[ "$1" =~ ^[01]+$ ]];
                        then
                          if [[ $gDebug -ne $1 ]];
                            then
                              let gDebug=$1
                              _PRINT_MSG "Override value: (-d) debug mode, now using: ${gDebug}!"
                          fi
                        else
                          _invalidArgumentError "-d $1"
                      fi
                      ;;

                  -m) shift

                      if [[ "$1" =~ ^[a-zA-Z,0-9]+$ ]];
                        then
                          if [[ "$gModelID" != "$1" ]];
                            then
                              _PRINT_MSG "Override value: (-m) model, now using: ${1}!"
                              gModelID="$1"
                          fi
                        else
                          _invalidArgumentError "-m $1"
                      fi
                      ;;

                  *) _invalidArgumentError "$1"
                     ;;
                esac
              else
                _invalidArgumentError "$1"
            fi
            shift;
          done;
      fi
  fi
}

#
#--------------------------------------------------------------------------------
#

function main()
{
  _checkLibraryDirectory
  _getScriptArguments "$@"
  #
  # Check if PlistBuddy is installed – download it when missing.
  #
  _findPlistBuddy
  _getResourceFiles
  #
  # Check if -d argument was used.
  #
  if [[ $gDebug -eq 1 ]];
    then
      _convertXML2BIN
  fi
  #
  # Check if -b argument was used.
  #
  if [[ $gBoardID == "" ]];
    then
      _getBoardID
  fi
  #
  # Check if -m argument was used.
  #
  if [[ $gModelID == "" ]];
    then
      _getModelID
  fi

  _DEBUG_PRINT "Used board-id: ${gBoardID}"
  _DEBUG_PRINT "Used model...: ${gModelID}\n"

  _selectSourceResourceFile
  #
  # Update target plist
  #
  gTargetPlist="${gBoardID}.plist"
  #
  #
  #
  if [[ ! -f /tmp/FrequencyVectors.bin ]];
    then
      #
      # Export the FrequencyVectors (with help of the Print command) to /tmp/FrequencyVectors.bin
      #
#     sudo echo "Array {" > /tmp/FrequencyVectors.bin
#     /usr/libexec/PlistBuddy -c "Print IOPlatformPowerProfile:FrequencyVectors:0" "${gSourcePlist}" > /tmp/tmp.bin
      /usr/libexec/PlistBuddy -c "Print IOPlatformPowerProfile:FrequencyVectors:0" "${gSourcePlist}" >/tmp/FrequencyVectors.bin
#     cat /tmp/tmp.bin >> /tmp/FrequencyVectors.bin
#     sudo echo "}" >> /tmp/FrequencyVectors.bin
  fi
  #
  # Now we remove the 'complimentary' 0x0A byte – something we don't want.
  #
  perl -pi -e 'chomp if eof' /tmp/FrequencyVectors.bin
  #
  # Check for FrequencyVectors array.
  #
  _checkPlistForEntry "IOPlatformPowerProfile:FrequencyVectors" "${gTargetPlist}"
  #
  # Is there a FrequencyVectors array in the target plist?
  #
  if [[ $? -eq 0 ]];
    then
      #
      # No. Not there. Let's add the array.
      #
      /usr/libexec/PlistBuddy -c "Add IOPlatformPowerProfile:FrequencyVectors array" "${gTargetPlist}"
  fi
  #
  # Import FrequencyVectors into target plist (for example: Mac-F60DEB81FF30ACF6.plist).
  #
  /usr/libexec/PlistBuddy -c "Import IOPlatformPowerProfile:FrequencyVectors:0 /tmp/FrequencyVectors.bin" "${gTargetPlist}"
  #
  # Check for StepContextDict.
  #
  _checkPlistForEntry "IOPlatformPowerProfile:StepContextDict" "${gTargetPlist}"
  #
  # Is there a StepContextDict dictionary in the target plist?
  #
  if [[ $? -eq 1 ]];
    then
      #
      # Yes. Remove it (we don't want it).
      #
      /usr/libexec/PlistBuddy -c "Remove IOPlatformPowerProfile:StepContextDict" "${gTargetPlist}"
  fi
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
      xcodePath=$(xcode-select --print-path)
      #
      # Check Xcode path (editor fails with commands line tools only installed).
      #
      if [[ $xcodePath =~ "CommandLineTools" ]];
        then
          #
          # Check if the Xcode.app is installed.
          #
          if [ -x /Applications/Xcode.app ];
            then
              local XcodeIsFound=1
            else
              #
              # Check if the Xcode-beta.app is installed.
              #
              if [ -x /Applications/Xcode-beta.app ];
                then
                  local XcodeIsFound=1
                else
                  #
                  # Yikes. Also not there. Error out.
                  #
                  _PRINT_MSG "Error: Xcode.app not found. Please install it!\n"
                  _ABORT
              fi
          fi
        else
          local XcodeIsFound=1
      fi

      if [[ $XcodeIsFound -eq 1 ]];
        then
          _DEBUG_PRINT "Launching $gEditor for: ${gTargetPlist}"
          $gEditor "${gResourcePath}/${gTargetPlist}"
      fi
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
_showHeader
_selectEditor

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

exit 0

#================================================================================
