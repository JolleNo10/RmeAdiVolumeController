#!/bin/bash

# Default log level
log_level="${2:-ERROR}"
enableLogging=0

# Global variables
defaultVolume=-350
highVolume=-200
lowVolume=-1000
volumeTick=5
volumeTickMultiplierTimeThreshold=500
volumeTickMultiplier=2
defaultMute=0

rmeCurrentVolumeFile="/usr/local/bin/rmeAdiCurrentVolume"
logfile="/usr/local/bin/log"

# Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip
# 0x71 - ADI-2 DAC # 0x72 - ADI-2 Pro # 0x73 - ADI-2/4 Pro SE
midiConfig_device_id=0x71

# 0x02 - Send Parameter(s) to device
midiConfig_command_id=0x02

# 6 - Phones Channel Settings
midiConfig_address=6

# 15 - Mute
midiConfig_index_mute=15

# 12 - Volume
midiConfig_index_volume=12


log() {
    local loglevel="$1"
    local logmessage="$2"
    if [ "$enableLogging" -eq 0 ]; then
        return 0;
    fi
        
    # Check if log file exists, create if it doesn't
    if [ ! -f "$logfile" ]; then
        touch "$logfile" || { echo "Error: Failed to create log file $logfile"; return; }
    fi

    if [ "$loglevel" = "DEBUG" ] && ([ "$log_level" = "DEBUG" ]); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [DEBUG] $logmessage" >> $logfile
    elif [ "$loglevel" = "INFO" ] && ( [ "$log_level" = "INFO" ] || [ "$log_level" = "DEBUG" ]); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $logmessage" >> $logfile
    elif [ "$loglevel" = "ERROR" ] && ( [ "$log_level" = "INFO" ] || [ "$log_level" = "DEBUG" ] || [ "$log_level" = "ERROR" ]); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $logmessage" >> $logfile
    fi
}

getTimestampWithMillis() {
    date +%s%3N
}

#Reading state file and sets defaults
readStateFromFile() {
    log "DEBUG" "Reading Volume from File"
    local file=$rmeCurrentVolumeFile
    if [ -f "$file" ]; then

        # Use read command to split the string into variables
        IFS=',' read -r volumeTimestamp currentVolume currentMute < "$file"
        #read -r volumeTimestamp currentVolume < "$file"

        if checkVolume "$currentVolume"; then
            log "DEBUG" "Read value from file is valid: $currentVolume"
        else
            log "ERROR" "Read value from file is not valid: $currentVolume"
            echo "" > "$file"  # Deleting file content by overwriting it with an empty string
            volumeTimestamp=$(getTimestampWithMillis)
            currentVolume=$defaultVolume
            currentMute=$defaultMute
        fi
    else
        log "ERROR" "File rmeAdiCurrentVolume.txt not found."
    fi
}

writeStateToFile() { #adjustedVolume="$1" adjustedMute="$2"
    local currentTime=$(getTimestampWithMillis)

    log "DEBUG" "Writing state to File: $currentTime,$1,$2"
    echo "$currentTime,$1,$2" > "$rmeCurrentVolumeFile"
}

checkVolume() {
    local volume="$1"
    
    # Regular expression to check if the volume is an integer
    local integer_regex='^-?[0-9]+$'

    if [[ ! $volume =~ $integer_regex ]]; then
        log "ERROR" "Volume Check: is not an integer $volume value."
        return 1
    fi

    if (( $(bc <<< "$volume < $lowVolume") )) || (( $(bc <<< "$volume > $highVolume") )); then
        log "ERROR" "Volume Check: Volume is not within the range of $lowVolume to $highVolume."
        return 1
    fi
    log "DEBUG" "Volume Check ok: $volume"
    return 0
}

adjustVolume() {
    local mode=$1

    readStateFromFile
    #currentVolume
    #currentMute

    local midiconfig
    local midiConfig_index
    local value
    local state

    if ([ "$mode" = "up" ] || [ "$mode" = "down" ]); then
        local currentTime=$(getTimestampWithMillis)
        local tsDiff=$(($currentTime - $volumeTimestamp))

        #Adjusting tick with multiplier $volumeTickMultiplier if changing quicker than $volumeTickMultiplierTimeThreshold
        log "DEBUG" "Diff, ms since last volume adjust: $tsDiff"

        if [ "$tsDiff" -lt $volumeTickMultiplierTimeThreshold ]; then
            adjustedVolumeTick=$(echo "$volumeTick * $volumeTickMultiplier" | bc)
            log "DEBUG" "Diff less than threshold"
        else
            adjustedVolumeTick=$volumeTick
            log "DEBUG" "Diff normal threshold"
        fi
        
        log "DEBUG" "Adjusting volume $mode volumeTick: $volumeTick adjustedVolumeTick: $adjustedVolumeTick"

        #Setting new volume
        if [ "$mode" = "up" ]; then
            value=$((currentVolume + adjustedVolumeTick))
        else
            value=$((currentVolume - adjustedVolumeTick))
        fi

        #Check volume value
        if checkVolume "$value"; then
            log "INFO" "All checks ok, setting adjusted volume to $1"
        else
            log "ERROR" "Volume not valid $value Restting volume to $defaultVolume"
            value=$defaultVolume
        fi

        # 12 - Volume
        midiConfig_index=$midiConfig_index_volume

        state="$value $currentMute"
    elif  [ "$mode" = "mute" ]; then
        value=$((currentMute ^ 1))

        # 15 - Mute
        midiConfig_index=$midiConfig_index_mute

        state="$currentVolume $value"
    else
        log "ERROR" "Invalid input parameter. Please provide either 'up', 'down' or 'mute'."
        exit 1
    fi

    performChange $value $midiConfig_device_id $midiConfig_command_id $midiConfig_address $midiConfig_index
    writeStateToFile $state
}


performChange() {
    log "DEBUG" "Trying to adjusti value to $1"
    local adjustedValue="$1"
    local midiconfig="$2 $3 $4 $5"

    error=$(/usr/local/bin/rmeAdiMidiControl.sh $adjustedValue $midiconfig $enableLogging $log_level $logfile 2>&1)
    log "DEBUG" "$adjustedValue $midiconfig $enableLogging $log_level $logfile"
    
    if [ $? -eq 0 ]; then
        log "DEBUG" "Midi Script call succeeded."
    else
        log "ERROR" "MidiScript call failed with error: $error"
    fi
}

#------------------------------------------------------------------------------------------------------------------

# Check if the first input parameter is provided
if [ $# -eq 0 ]; then
    echo "Error: First input parameter is missing."
    exit 1
fi

# Check if debug parameter is provided
# Check if the second parameter is defined
if [ -n "$2" ]; then
    # Convert the second parameter to uppercase and set log level
    log_level=$(echo "$2" | tr '[:lower:]' '[:upper:]')
fi

log "DEBUG" "-- SCRIPT STARTED --"
log "DEBUG" "Perf: Timestart: $(getTimestampWithMillis)"
timeStart=$(getTimestampWithMillis)

# Check the value of the first input parameter and call the appropriate function
if ([ "$1" = "up" ] || [ "$1" = "down" ] || [ "$1" = "mute" ]); then
    log "DEBUG" "Adjusting volume $1"
    adjustVolume $1
else
    log "ERROR" "Invalid input parameter. Please provide either 'up' or 'down'."
    exit 1
fi
timeEnd=$(getTimestampWithMillis)

perfDiff=$(($timeEnd - $timeStart))

log "INFO" "Perf: Timeend: $timeEnd diff: $perfDiff"
#echo "Perf: Timeend: $timeEnd diff: $perfDiff"
