#!/bin/bash

host_name=$(hostname)

display_help() {
    echo "Usage: $0 [option]"
    echo
    echo "Options:"
    echo "  --show-all      Display information for all slots."
    echo "  --show-empty    Display information only for empty slots."
    echo "  --summary       Display a summary."
    echo "  --help          Display this help message."
    echo
    exit 0
}

# Command-line options
show_all=0
show_empty=0
summary=0

# Summary variables
total_slots=0
used_slots=0
blinking_disks=0
empty_slots=0

# Parse command-line options
for arg in "$@"; do
  case $arg in
    --show-all)
      show_all=1
      ;;
    --show-empty)
      show_empty=1
      ;;
    --summary)
      summary=1
      ;;
    --help|-h)
      display_help
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

# Loop through and display slots
for x in /sys/class/enclosure/*/*/locate; do
    total_slots=$((total_slots +1))
    value=$(cat $x)
    enclosure_path=$(dirname $x)
    enclosure_id=$(basename $(dirname $enclosure_path))
    slot=$(basename $enclosure_path)

    # Determine the drive letter
    drive_letter=$(basename $(readlink -f "$enclosure_path/device/block"/*) 2>/dev/null)

    # Check if the slot is empty
    if [ -z "$drive_letter" ]; then
        drive_letter="Empty"
    fi

    # Determine the number of slots to distinguish frontplane from backplane
    num_slots=$(ls -d $enclosure_path/../[S0-9]* 2>/dev/null | wc -l)

    if [ "$num_slots" -eq 0 ]; then
        num_slots=$(ls -d $enclosure_path/../[0-9][0-9]* 2>/dev/null | wc -l)
    fi

    # Determine whether it is a frontplane or backplane based on the number of slots
    if [ "$num_slots" -eq 24 ]; then
        plane="Frontplane ($enclosure_id)"
    elif [ "$num_slots" -eq 12 ]; then
        plane="Backplane ($enclosure_id)"
    else
        plane="Unknown ($enclosure_id)"
    fi

    disk_size_file="/sys/block/$drive_letter/size"
    if [ -f "$disk_size_file" ]; then
        disk_size=$(cat "$disk_size_file")
        # Convert to human-readable format if necessary
        disk_size_tb=$((disk_size * 512 / 1000 / 1000 / 1000 /1000 ))
    else
        disk_size="Unknown"
        disk_size_tb="Unknown"
    fi

    if [ "$drive_letter" != "Empty" ]; then
        used_slots=$((used_slots + 1))
    else
        empty_slots=$((empty_slots + 1))
    fi

    if [ "$value" -eq 1 ]; then
        blinking_disks=$((blinking_disks + 1))
    fi

    # Control what to display based on command-line options
    if [ "$show_all" -eq 1 ]; then
        echo "Host: $host_name, Plane: $plane, Slot: $slot, Drive: $drive_letter, Size: ${disk_size_tb} TB, Locate Value: $value"
    elif [ "$show_empty" -eq 1 ]; then
        if [ "$drive_letter" == "Empty" ] && [ "$value" -ne 1 ]; then
            echo "Host: $host_name, Plane: $plane, Slot: $slot, Drive: $drive_letter, Size: ${disk_size_tb} TB, Locate Value: $value"
        fi
    elif [ "$value" -eq 1 ]; then
        echo "Host: $host_name, Plane: $plane, Slot: $slot, Drive: $drive_letter, Size: ${disk_size_tb} TB ,Locate Value: $value"
    fi

done

# Print the summary, if the flag is set
if [ "$summary" -eq 1 ]; then
    echo "=== Summary ==="
    echo "Total slots: $total_slots"
    echo "Used slots: $used_slots"
    echo "Empty slots: $empty_slots"
    echo "Blinking slots: $blinking_disks"
fi
