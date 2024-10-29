#!/bin/bash

WINDOW_SCALE=2
BANNED_WINDOW_IDS=(37312 37113)
HEADER_OFFSET=38

# Get screen dimensions
screen_width=$(yabai -m query --displays | jq '.[0].frame.w')
screen_height=$(yabai -m query --displays | jq '.[0].frame.h')

# Get actual display size (without scaling)
phys_screen_width=$(echo "$screen_width * $WINDOW_SCALE" | bc)
phys_screen_height=$(echo "$screen_height * $WINDOW_SCALE" | bc)

echo "Screen Resolution: $screen_width x $screen_height"

# Function to generate a random number between min and max
random_range() {
  local min=$1
  local max=$2
  echo $((RANDOM % (max - min + 1) + min))
}

# Function to list all windows
list_windows() {
  window_ids=$(yabai -m query --windows | jq '.[] | select(.app != "Dock" and .app != "SystemUIServer" and .app != "iTerm2") | .id')

  # List all window names with their IDs
  for id in $window_ids; do
    name=$(yabai -m query --windows | jq -r ".[] | select(.id == $id) | .app")
    echo "Window ID: $id, Name: $name"
  done
}

# Function to move and resize windows with constraints
move_and_resize_windows() {
  window_ids=$(yabai -m query --windows | jq '.[] | select(.id == 37312 or .id == 37113) | .id')

  # Define minimum and maximum sizes
  minWidth=400
  maxWidth=$((screen_width))
  minHeight=300
  maxHeight=$((screen_height))
  minAspectRatio=0.7 # Minimum aspect ratio (width/height)
  maxAspectRatio=1.7 # Maximum aspect ratio (width/height)

  banned_items=()

  for id in $window_ids; do
    # Loop to find valid randWidth and randHeight
    while true; do
      randWidth=$(random_range $minWidth $maxWidth)
      randHeight=$(random_range $minHeight $maxHeight)

      # Calculate aspectRatio
      aspectRatio=$(echo "scale=2; $randWidth / $randHeight" | bc)
      aspectRatioCheck=$(echo "$aspectRatio >= $minAspectRatio && $aspectRatio <= $maxAspectRatio" | bc)

      if [ "$aspectRatioCheck" -eq 1 ]; then
        break
      fi
    done

    # Calculate maximum X and Y positions to keep the window on screen
    maxX=$((screen_width - randWidth))
    maxY=$((screen_height - randHeight))

    # Ensure maxX and maxY are not negative
    if [ $maxX -lt 0 ]; then maxX=0; fi
    if [ $maxY -lt 0 ]; then maxY=0; fi

    # Generate random X and Y positions within the allowed range
    randX=$(random_range 0 $maxX)
    randY=$(random_range $HEADER_OFFSET $maxY)

    echo "Positioning window $id to X:$randX Y:$randY with Width:$randWidth Height:$randHeight"

    yabai -m window "$id" --move abs:$randX:$randY
    yabai -m window "$id" --resize abs:$randWidth:$randHeight

    # Check if the window is in the banned list
    for banned_id in "${BANNED_WINDOW_IDS[@]}"; do
      if [ "$id" -eq "$banned_id" ]; then
        # Calculate center X and Y
        center_x=$(echo "($randX + $randWidth / 2) * $WINDOW_SCALE" | bc)
        center_y=$(echo "($randY + $randHeight / 2) * $WINDOW_SCALE" | bc)

        # Normalize the values by the physical screen size
        norm_center_x=$(echo "scale=4; $center_x / $phys_screen_width" | bc)
        norm_center_y=$(echo "scale=4; $center_y / $phys_screen_height" | bc)
        norm_width=$(echo "scale=4; $randWidth * $WINDOW_SCALE / $phys_screen_width" | bc)
        norm_height=$(echo "scale=4; $randHeight * $WINDOW_SCALE / $phys_screen_height" | bc)

        # Create an array for each banned window with label and dimensions
        banned_item=("2" "$norm_center_x" "$norm_center_y" "$norm_width" "$norm_height")
        banned_items+=("${banned_item[@]}")

        echo "Banned window found: $id at Center X: $norm_center_x Center Y: $norm_center_y with Normalized Width: $norm_width Height: $norm_height"
      fi
    done
  done

  sleep 0.5

  if [ ${#banned_items[@]} -gt 0 ]; then
    create_datapoint "${banned_items[@]}"
  fi
}

# Function to create a screenshot and data file
create_datapoint() {
  local banned=("$@")
  local timestamp=$(date +%s)
  local screenshot_path=~/Desktop/screenshot_${timestamp}.png
  local datafile_path=~/Desktop/screenshot_${timestamp}.txt

  # Take the screenshot
  screencapture -x "$screenshot_path"

  # Write the banned items to the data file
  for ((i = 0; i < ${#banned[@]}; i += 5)); do
    echo "${banned[i]} ${banned[i + 1]} ${banned[i + 2]} ${banned[i + 3]} ${banned[i + 4]}" >>"$datafile_path"
  done

  echo "Screenshot saved to $screenshot_path"
  echo "Banned items data saved to $datafile_path"
}

# Function to change desktop background
change_background() {
  echo "Searching for images in $HOME/Pictures/backgrounds"

  backgrounds=()

  while IFS= read -r -d '' file; do
    backgrounds+=("$file")
  done < <(find "$HOME/Pictures/backgrounds" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' \) -print0)

  if [ ${#backgrounds[@]} -eq 0 ]; then
    echo "No images found in $HOME/Pictures/backgrounds"
    return
  fi

  echo "Found ${#backgrounds[@]} images:"

  index=$(random_range 0 $((${#backgrounds[@]} - 1)))
  bg="${backgrounds[$index]}"

  desktoppr "$bg"
}

# Main loop

list_windows

while true; do
  move_and_resize_windows
  # change_background
  sleep 1 # Adjust the sleep duration as needed
done
