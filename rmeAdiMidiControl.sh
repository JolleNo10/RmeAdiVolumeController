#!/usr/bin/env bash
set -euo pipefail

die_usage() {
    echo "${1-die_usage() arguments missing}"
    echo
    usage
    exit 0
}

usage() {
    cat << EOF
Usage: $(basename "${0}") VALUE DEVICE_ID COMMAND_ID ADDRESSS INDEX [LOGGING LOGLEVEL LOGFILE] [-h] 
    VALUE           - int Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip 
    DEVICE_ID       - byte Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip 
    COMMAND_ID      - byte Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip 
    ADDRESSS        - int Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip 
    INDEX           - int Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip 
    LOGGING         - 0 disable, 1 enabled 
    LOGLEVEL        - DEBUG,INFO,ERROR 
    LOGFILE         - File location 
    -h | --help     - this help message 
EOF
}



log() {
    local loglevel="$1"
    local logmessage="$2"
    if [[ -z ${enableLogging+x} || $enableLogging -eq 0 ]]; then
        return 0;
    fi
        
    # Check if log file exists, create if it doesn't
    if [ ! -f "$logfile" ]; then
        touch "$logfile" || { echo "Error: Failed to create log file $logfile"; return; }
    fi

    if [ "$loglevel" = "DEBUG" ] && ([ "$log_level" = "DEBUG" ]); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [DEBUG] [rmeAdiMidiControl] $logmessage" >> $logfile
    elif [ "$loglevel" = "INFO" ] && ( [ "$log_level" = "INFO" ] || [ "$log_level" = "DEBUG" ]); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] [rmeAdiMidiControl] $logmessage" >> $logfile
    elif [ "$loglevel" = "ERROR" ] && ( [ "$log_level" = "INFO" ] || [ "$log_level" = "DEBUG" ] || [ "$log_level" = "ERROR" ]); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] [rmeAdiMidiControl] $logmessage" >> $logfile
    fi

}

if [ -z "${1-}" ]; then
    log "ERROR" "Required argument missing"
    die_usage "Required argument missing"
fi
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]; then
    usage
    exit 1
fi

if [ "$#" -eq 5 ]; then
    value="${1}"
    device_id="${2}"
    command_id="${3}"
    address="${4}"
    index="${5}"
    enableLogging=0
elif [ "$#" -eq 8 ]; then
    value="${1}"
    device_id="${2}"
    command_id="${3}"
    address="${4}"
    index="${5}"
    enableLogging="${6}"
    if [ -n "$7" ]; then
        log_level=$(echo "$7" | tr '[:lower:]' '[:upper:]')
    fi
    logfile="${8}"
else
    die_usage "Required argument missing"
fi

if [[ ! $device_id =~ ^0x7[123]$ ]]; then
    log "ERROR" "device_id is not valid"
    die_usage "device_id is not valid"
fi

if [[ ! $command_id =~ ^0x0[1-7]$ ]]; then
    log "ERROR" "command_id is not valid"
    die_usage "command_id is not valid"
fi

if (( address < 0 || address > 12 )); then
    log "ERROR" "Address is not between 0 and 12."
    die_usage "Address is not between 0 and 12."
fi

if ! [[ $index =~ ^[0-9]+$ && $index -ge 0 && $index -le 100 ]]; then
    log "ERROR" "Index is not between 0 and 100 or is not an integer."
    die_usage "Index is not between 0 and 100 or is not an integer."
fi

if [[ "${5}" = "12" ]]; then
    if ! [[ $value =~ ^[-+]?[0-9]+$ ]]; then
        log "ERROR" "VOLUME must be an integer"
        die_usage "VOLUME must be an integer"
    elif (( value < -1140 || value > 60 )); then
        log "ERROR" "VOLUME must be between -1140 and 60"
        die_usage "VOLUME must be between -1140 and 60"
    fi
elif [[ "${5}" = "15" ]]; then
    if ! [[ $value =~ ^[-+]?[0-9]+$ ]]; then
        log "ERROR" "Mute value must be an integer"
        die_usage "Mute value must be an integer"
    elif (( value != 0 && value != 1 )); then
        log "ERROR" "Mute value must be 1 or 0"
        die_usage "Mute value must be 1 or 0"
    fi
fi


#------------------------------------------------------------------------------------------------------------------

# Select first ADI MIDI port.
port="$(amidi -l | grep -m1 ADI | tr -s ' ' | cut -d' ' -f2 || true)"
if [ -z "${port}" ]; then
    log "ERROR" "No ADI MIDI port found"
    exit 1
else
    log "DEBUG" "ADI MIDI port found at $port"
fi


value=$((value))

# split "index" into 3 high and 2 low bits
index_hi_mask=$(( (1 << 3) - 1 ))
index_lo_mask=$(( (1 << 2) - 1 ))
index_hi=$(( (index >> 2) & index_hi_mask ))
index_lo=$(( index & index_lo_mask ))

# split "value" into 5 high and 7 low bits
value_hi_mask=$(( (1 << 5) - 1 ))
value_lo_mask=$(( (1 << 7) - 1 ))
value_hi=$(( (value >> 7) & value_hi_mask ))
value_lo=$(( value & value_lo_mask ))

# combine "address", "index" and "value" into 3 bytes of parameter-transfer
byte_1=$((  (address << 3) | index_hi ))
byte_2=$(( (index_lo << 5) | value_hi ))
byte_3=$((  value_lo ))

midi_cmd="$(printf "F0 00 20 0D %02x %02x %02x %02x %02x F7" ${device_id} ${command_id} ${byte_1} ${byte_2} ${byte_3})"

#echo $midi_cmd
set -x
amidi -p "${port}" -S "${midi_cmd}"

log "DEBUG" "amidi -p $port -S \"$midi_cmd\""

exit 0
