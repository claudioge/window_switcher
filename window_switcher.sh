#!/bin/bash

# Get screen dimensions
screen_bounds=$(osascript -e 'tell application "Finder" to get bounds of window of desktop')
x1=$(echo $screen_bounds | awk -F', ' '{print $1}')
y1=$(echo $screen_bounds | awk -F', ' '{print $2}')
x2=$(echo $screen_bounds | awk -F', ' '{print $3}')
y2=$(echo $screen_bounds | awk -F', ' '{print $4}')
screen_width=$(($x2 - $x1))
screen_height=$(($y2 - $y1))

echo "Screen dimensions: $screen_width x $screen_height"

# Function to move and resize windows
move_and_resize_windows() {
  osascript <<EOF
tell application "System Events"
    set allProcesses to application processes whose visible is true
    repeat with proc in allProcesses
        try
            set allWindows to windows of proc
            repeat with win in allWindows
                -- Generate random position and size
                set randX to (random number from 50 to $((screen_width - 300)))
                set randY to (random number from 50 to $((screen_height - 300)))
                set randWidth to (random number from 300 to $((screen_width - randX)))
                set randHeight to (random number from 300 to $((screen_height - randY)))
                set position of win to {randX, randY}
                set size of win to {randWidth, randHeight}
            end repeat
        end try
    end repeat
end tell
EOF
}

# Function to change desktop background
change_background() {
  echo "Searching for images in $HOME/Pictures/backgrounds"
  # Initialize an empty array
  backgrounds=()
  # Use find with -print0 and read with -d '' to handle filenames with spaces
  while IFS= read -r -d '' file; do
    backgrounds+=("$file")
  done < <(find "$HOME/Pictures/backgrounds" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' \) -print0)

  if [ ${#backgrounds[@]} -eq 0 ]; then
    echo "No images found in $HOME/Pictures/backgrounds"
    return
  fi

  echo "Found ${#backgrounds[@]} images:"

  # Select a random image
  bg="${backgrounds[RANDOM % ${#backgrounds[@]}]}"

  osascript <<EOF
tell application "System Events"
    set picture of every desktop to POSIX file "$bg"
end tell
EOF

  # Force the desktop to refresh (optional)
  killall Dock
}

# Function to take a screenshot
take_screenshot() {
  screencapture -x ~/Desktop/screenshot_$(date +%s).png
}

# Main loop
while true; do
  move_and_resize_windows
  change_background
  sleep 1
  take_screenshot
  sleep 2 # Adjust the sleep duration as needed
done
