#!/bin/bash

WINDOW_SCALE=2 # Scaling factor of screen resolution
BANNED_WINDOW_IDS=() # List of window IDs to check for visibility
HEADER_OFFSET=38 # Height of the header bar in pixels
BANNED_CLASS="2" # Class label for banned windows

ITERATIONS=500 # Number of iterations to run the script
BACKGROUND_DIR="$HOME/Pictures/backgrounds" # Define the path to the background directory

# Get screen dimensions
screen_width=$(yabai -m query --displays | jq '.[0].frame.w')
screen_height=$(yabai -m query --displays | jq '.[0].frame.h')

# Get actual display size (without scaling)
phys_screen_width=$(echo "$screen_width * $WINDOW_SCALE" | bc)
phys_screen_height=$(echo "$screen_height * $WINDOW_SCALE" | bc)

echo "Screen Resolution: $screen_width x $screen_height"
# Min function to get the smaller of two numbers
min() {
    if [ "$1" -lt "$2" ]; then
        echo "$1"
    else
        echo "$2"
    fi
}

# Max function to get the larger of two numbers
max() {
    if [ "$1" -gt "$2" ]; then
        echo "$1"
    else
        echo "$2"
    fi
}
# Function to generate a random number between min and max with bias toward the edges
random_range() {
  local min=$1
  local max=$2
  local range=$((max - min + 1))

  # Generate a random floating-point number between 0 and 1
  local rand_float=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); print rand() }')

  # Apply a bias to skew towards min or max
  local biased=$(awk -v r="$rand_float" 'BEGIN { print (r < 0.5) ? (1 - 4 * (0.5 - r)^2) : (4 * (r - 0.5)^2) }')

  # Scale the biased value to the desired range and round it to an integer
  local result=$(awk -v min="$min" -v range="$range" -v biased="$biased" \
    'BEGIN { printf("%d\n", min + biased * (range - 1)) }')

  echo "$result"
}


# Function to list all windows
list_windows() {
  window_ids=$(yabai -m query --windows | jq '.[] | select(.app != "Dock" and .app != "SystemUIServer" and .app != "iTerm2") | .id')

  # List all window names with their IDs
  for id in $window_ids; do
    name=$(yabai -m query --windows | jq -r ".[] | select(.id == $id) | .app")
    space=$(yabai -m query --windows | jq -r ".[] | select(.id == $id) | .space")
    display=$(yabai -m query --windows | jq -r ".[] | select(.id == $id) | .display")


    echo "$id ID: $id, Name: $name", "Space: $space", "Display: $display"
  done
}

# Function to check if a window is visible (not completely covered by others)
is_window_visible() {
    local target_id=$1
    local target_x=$2
    local target_y=$3
    local target_width=$4
    local target_height=$5

    # Get all window information once
    local windows_info=$(yabai -m query --windows)

    # Find the index of our target window in the list
    local target_index=$(echo "$windows_info" | jq -r "to_entries | map(select(.value.id == $target_id)) | .[0].key")
    local target_display=$(echo "$windows_info" | jq -r ".[$target_index].display")
    local target_space=$(echo "$windows_info" | jq -r ".[$target_index].space")

    if [ -z "$target_index" ] || [ "$target_index" = "null" ]; then
        echo "Could not find index for window $target_id"
        return 0  # Assume visible if we can't determine index
    fi

    # Get windows that appear before our target in the list (potentially above it)
    local covering_windows=$(echo "$windows_info" | jq -c ".[:$target_index] | map(select(.display == $target_display and .space == $target_space and .id != $target_id))")

    # echo "Covering windows: $covering_windows"
    if [ -z "$covering_windows" ] || [ "$covering_windows" = "[]" ]; then
        return 0  # No covering windows
    fi

    while read -r window; do
        local wx=$(echo "$window" | jq -r '.frame.x // empty')
        local wy=$(echo "$window" | jq -r '.frame.y // empty')
        local ww=$(echo "$window" | jq -r '.frame.w // empty')
        local wh=$(echo "$window" | jq -r '.frame.h // empty')

        [ -z "$wx" ] || [ -z "$wy" ] || [ -z "$ww" ] || [ -z "$wh" ] && continue

        # Calculate overlap in x-direction
        overlap_x=$(echo "$(min $((target_x + target_width)) $((wx + ww))) - $(max $target_x $wx)" | bc)

        # Calculate overlap in y-direction
        overlap_y=$(echo "$(min $((target_y + target_height)) $((wy + wh))) - $(max $target_y $wy)" | bc)

        # Ensure valid overlap (positive in both dimensions)
        if [ $(echo "$overlap_x > 0" | bc) -eq 1 ] && [ $(echo "$overlap_y > 0" | bc) -eq 1 ]; then
            # Calculate the overlapping area
            overlap_area=$(echo "$overlap_x * $overlap_y" | bc)
            target_area=$(echo "$target_width * $target_height" | bc)

            # Calculate overlap ratio
            overlap_ratio=$(echo "scale=2; $overlap_area / $target_area" | bc)

            if [ $(echo "$overlap_ratio > 0.6" | bc) -eq 1 ]; then
                return 1  # Window is completely covered
            fi
        fi
    done < <(echo "$covering_windows" | jq -c '.[]')

    return 0  # Window is at least partially visible
}

# Function to move and resize windows
move_and_resize_windows() {
    window_ids=$(yabai -m query --windows | jq '.[] | select(.app != "Dock" and .app != "SystemUIServer" and .app != "iTerm2" and(.space == 1 or .space == 2 or .space == 3)) | .id')
    minWidth=400
    maxWidth=$((screen_width))
    minHeight=300
    maxHeight=$((screen_height))
    minAspectRatio=0.5
    maxAspectRatio=2

    for id in $window_ids; do
        while true; do
            randWidth=$(random_range $minWidth $maxWidth)
            randHeight=$(random_range $minHeight $maxHeight)

            aspectRatio=$(echo "scale=2; $randWidth / $randHeight" | bc)
            aspectRatioCheck=$(echo "$aspectRatio >= $minAspectRatio && $aspectRatio <= $maxAspectRatio" | bc)

            if [ "$aspectRatioCheck" -eq 1 ]; then
                break
            fi
        done

        randSpace=$(random_range 1 4)

        maxX=$((screen_width - randWidth))
        maxY=$((screen_height - randHeight))

        [ $maxX -lt 0 ] && maxX=0
        [ $maxY -lt 0 ] && maxY=0

        randX=$(random_range 0 $maxX)
        randY=$(random_range $HEADER_OFFSET $maxY)

        yabai -m window "$id" --space "$randSpace"
        if [ "$randSpace" -eq "1" ]; then
            yabai -m window "$id" --move abs:$randX:$randY
            yabai -m window "$id" --resize abs:$randWidth:$randHeight
        fi
    done
}

# Function to check visibility of banned windows
check_banned_windows_visibility() {
    banned_items=()

    for banned_id in "${BANNED_WINDOW_IDS[@]}"; do
        window_info=$(yabai -m query --windows --window "$banned_id")
        # skip if window is not in space 1
        space=$(echo "$window_info" | jq -r '.space')
        if [ "$space" != "1" ]; then
            continue
        fi
        if [ -z "$window_info" ] || [ "$window_info" = "null" ]; then
            echo "Could not find window info for $banned_id"
            continue
        fi
        target_x=$(echo "$window_info" | jq -r '.frame.x')
        target_y=$(echo "$window_info" | jq -r '.frame.y')
        target_width=$(echo "$window_info" | jq -r '.frame.w')
        target_height=$(echo "$window_info" | jq -r '.frame.h')

        if is_window_visible "$banned_id" "$target_x" "$target_y" "$target_width" "$target_height"; then
            center_x=$(echo "($target_x + $target_width / 2) * $WINDOW_SCALE" | bc)
            center_y=$(echo "($target_y + $target_height / 2) * $WINDOW_SCALE" | bc)

            norm_center_x=$(echo "scale=4; $center_x / $phys_screen_width" | bc)
            norm_center_y=$(echo "scale=4; $center_y / $phys_screen_height" | bc)
            norm_width=$(echo "scale=4; $target_width * $WINDOW_SCALE / $phys_screen_width" | bc)
            norm_height=$(echo "scale=4; $target_height * $WINDOW_SCALE / $phys_screen_height" | bc)

            banned_item=("$BANNED_CLASS" "$norm_center_x" "$norm_center_y" "$norm_width" "$norm_height")
            banned_items+=("${banned_item[@]}")

            echo "Visible banned window found: $banned_id at Center X: $norm_center_x Center Y: $norm_center_y with Normalized Width: $norm_width Height: $norm_height"
        else
            echo "Banned window $banned_id is completely covered by other windows - ignoring"
        fi
    done

    create_datapoint "${banned_items[@]}"
}

# Function to create a screenshot and data file
create_datapoint() {
    local banned=("$@")
    local timestamp=$(date +%s)
    local screenshot_path=~/Desktop/test/email/images/screenshot_${timestamp}.png
    local datafile_path=~/Desktop/test/email/lables/screenshot_${timestamp}.txt

    screencapture -x "$screenshot_path"

    if [ ${#banned[@]} -eq 0 ]; then
        touch "$datafile_path"
        return
    fi

    for ((i = 0; i < ${#banned[@]}; i += 5)); do
        echo "${banned[i]} ${banned[i + 1]} ${banned[i + 2]} ${banned[i + 3]} ${banned[i + 4]}" >>"$datafile_path"
    done
}

# Function to change desktop background
change_background() {
    backgrounds=()

    while IFS= read -r -d '' file; do
        backgrounds+=("$file")
    done < <(find "$BACKGROUND_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' \) -print0)

    if [ ${#backgrounds[@]} -eq 0 ]; then
        echo "No images found in $BACKGROUND_DIR"
        return
    fi

    index=$(random_range 0 $((${#backgrounds[@]} - 1)))
    bg="${backgrounds[$index]}"

    desktoppr "$bg"
}

# Main loop
list_windows

while [ $ITERATIONS -gt 0 ]; do
    echo "Iteration: $ITERATIONS"
    change_background
    move_and_resize_windows
    sleep 1
    check_banned_windows_visibility
    sleep 1
    ITERATIONS=$((ITERATIONS - 1))
done
