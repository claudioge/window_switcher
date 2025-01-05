#!/bin/bash

WINDOW_SCALE=1 # Scaling factor of screen resolution
BANNED_WINDOW_IDS=() # List of window IDs to check for visibility
HEADER_OFFSET=38 # # Height of the header bar in pixels
BANNED_CLASS="2" # Specify which label you are creating screenshots for

ITERATIONS=500 # Number of iterations to run the script
BACKGROUND_DIR="$HOME/Pictures/backgrounds" # Path to the background directory

# Get screen dimensions properly
screen_dimensions=$(xrandr | grep ' connected' | grep -oP '[0-9]+x[0-9]+' | head -1)
screen_width=$(echo "$screen_dimensions" | cut -d 'x' -f1)
screen_height=$(echo "$screen_dimensions" | cut -d 'x' -f2)

# Get actual display size (without scaling)
phys_screen_width=$(echo "$screen_width * $WINDOW_SCALE" | bc)
phys_screen_height=$(echo "$screen_height * $WINDOW_SCALE" | bc)

echo "Screen Resolution: $screen_width x $screen_height"

# Min and Max functions
min() {
  if [ "$1" -lt "$2" ]; then echo "$1"; else echo "$2"; fi
}
max() {
  if [ "$1" -gt "$2" ]; then echo "$1"; else echo "$2"; fi
}

# Generates a random integer between min and max, inclusive
random_range() {
  local min=$1
  local max=$2
  echo $((RANDOM % (max - min + 1) + min))
}

# Function to generate a random number between min and max with edge bias
random_range_edge_bias() {
  local min=$1
  local max=$2
  local range=$((max - min + 1))

  # Generate a random floating-point number between 0 and 1
  local rand_float=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); print rand() }')

  # Apply a bias to skew towards min or max
  local biased
  if (($(echo "$rand_float < 0.5" | bc -l))); then
    biased=$(echo "scale=4; 1 - 4 * ((0.5 - $rand_float)^2)" | bc)
  else
    biased=$(echo "scale=4; 4 * (($rand_float - 0.5)^2)" | bc)
  fi

  # Scale the biased value to the desired range and round it to an integer
  local result=$(awk -v min="$min" -v range="$range" -v biased="$biased" \
    'BEGIN { printf("%d\n", min + biased * (range - 1)) }')

  echo "$result"
}

# Function to list windows
list_windows() {
  wmctrl -l | while read -r line; do
    id=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | cut -f5- -d' ')
    echo "$id ID: $id, Name: $name"
  done
}

get_windows_on_top() {
  # Normalize the input window_id for comparison by removing leading zeros after "0x"
  local window_id=$(echo "$1" | sed 's/^0x0*/0x/')

  xprop -root _NET_CLIENT_LIST_STACKING |
    sed -e 's/_NET_CLIENT_LIST_STACKING(WINDOW): window id # //;s/,//g' |
    awk -v target="$window_id" '{
            found=0
            for (i=1; i<=NF; i++) {
                # Normalize each xprop window ID only for comparison
                id = $i
                normalized_id = id
                sub(/^0x0*/, "0x", normalized_id)

                if (found) {
                    # Format output to ensure "0x0" prefix where required
                    if (id !~ /^0x0/) id = "0x0" substr(id, 3)
                    print id
                }
                if (normalized_id == target) found=1
            }
        }'
}

# Function to check if a window is visible (not completely covered by others)

is_window_visible() {
  local target_id=$1
  local target_x=$2
  local target_y=$3
  local target_width=$4
  local target_height=$5

  echo "checking if $target_id is visible"
  echo "getting windows on top"

  # First get the windows on top
  windows_on_top=$(get_windows_on_top "$target_id")
  echo "windows on top: $windows_on_top"

  # Get all windows info from wmctrl and store it directly in windows_info variable
  windows_info=$(wmctrl -lG)

  total_overlap=0

  # Check if any window overlaps with the target window
  while read -r window_id wx wy ww wh rest; do
    echo "checking window $window_id with geometry $wx, $wy, $ww, $wh"

    # Check if the current window_id is in the windows_on_top array
    if ! echo "$windows_on_top" | grep -qw "$window_id"; then
      # Skip this iteration if window_id is not in windows_on_top
      echo "window $window_id not on top, skipping"
      continue
    fi

    # Adjust coordinates for comparison
    wx=$(echo "$wx / 2" | bc)
    wy=$(echo "$wy / 2" | bc)

    # Calculate overlap in x-direction
    local overlap_x=$(($(min $((target_x + target_width)) $((wx + ww))) - $(max $target_x $wx)))
    # Calculate overlap in y-direction
    local overlap_y=$(($(min $((target_y + target_height)) $((wy + wh))) - $(max $target_y $wy)))

    # Ensure valid overlap (positive in both dimensions)
    if [ "$overlap_x" -gt 0 ] && [ "$overlap_y" -gt 0 ]; then
      # Calculate the overlapping area
      local overlap_area=$((overlap_x * overlap_y))
      local target_area=$((target_width * target_height))

      # Calculate overlap ratio
      local overlap_ratio=$(echo "scale=2; $overlap_area / $target_area" | bc)
      echo "overlap with $window_id is $overlap_ratio"

      total_overlap=$(echo "$total_overlap + $overlap_ratio" | bc)

      if (($(echo "$overlap_ratio > 0.6" | bc -l))); then
        echo "Window $window_id completely covers the target window."
        return 1 # Window is completely covered
      fi
    fi
  done <<<"$(echo "$windows_info" | awk '{print $1, $3, $4, $5, $6}')"

  if (($(echo "$overlap_ratio > 0.6" | bc -l))); then
    return 1
  fi

  return 0 # Window is at least partially visible
}

move_and_resize_windows() {
  # Get list of window IDs that are in specific spaces (adjust if needed for your workspace setup)
  window_ids=$(wmctrl -l | awk '{print $1}')

  # Set min and max dimensions, as well as aspect ratio constraints
  minWidth=600
  maxWidth=$((screen_width))
  minHeight=600
  maxHeight=$((screen_height))
  minAspectRatio=0.6
  maxAspectRatio=2

  # Minimum distance between windows to prevent heavy stacking
  min_distance=100

  # Track positions of each window to avoid excessive overlap
  declare -A window_positions

  # Loop over each window ID and apply transformations
  for id in $window_ids; do
    while true; do
      # Generate random width and height within specified ranges
      randWidth=$(random_range_edge_bias $minWidth $maxWidth)
      randHeight=$(random_range_edge_bias $minHeight $maxHeight)

      # Calculate aspect ratio and check if it's within the allowed range
      aspectRatio=$(echo "scale=2; $randWidth / $randHeight" | bc)
      aspectRatioCheck=$(echo "$aspectRatio >= $minAspectRatio && $aspectRatio <= $maxAspectRatio" | bc)

      # Only break if the aspect ratio is within the desired range
      if [ "$aspectRatioCheck" -eq 1 ]; then
        break
      fi
    done

    # Generate a random position within screen bounds
    maxX=$((screen_width - randWidth))
    maxY=$((screen_height - randHeight))
    randX=$(random_range_edge_bias 0 $maxX)
    randY=$(random_range_edge_bias $HEADER_OFFSET $maxY)

    # Add a slight jitter to avoid exact alignment
    jitterX=$(random_range -20 20)
    jitterY=$(random_range -20 20)
    randX=$((randX + jitterX))
    randY=$((randY + jitterY))

    # Ensure minimum distance from previous windows to prevent heavy stacking
    overlap_found=false
    for prev_position in "${window_positions[@]}"; do
      prev_x=$(echo "$prev_position" | cut -d',' -f1)
      prev_y=$(echo "$prev_position" | cut -d',' -f2)

      # Calculate distance between new and previous window
      distance_x=$((randX - prev_x))
      distance_y=$((randY - prev_y))
      distance=$(echo "sqrt($distance_x * $distance_x + $distance_y * $distance_y)" | bc)

      # If overlap is too close, generate a new position
      if (($(echo "$distance < $min_distance" | bc -l))); then
        overlap_found=true
        break
      fi
    done

    # Retry if overlap found, otherwise save position and move window
    if [ "$overlap_found" = false ]; then
      window_positions["$id"]="$randX,$randY"
      echo "moving window $id to $randX $randY size $randWidth $randHeight"
      xdotool windowmove "$id" "$randX" "$randY"
      xdotool windowsize "$id" "$randWidth" "$randHeight"
    else
      continue
    fi
  done
}
# Function to check visibility of banned windows
check_banned_windows_visibility() {
  banned_items=()

  for banned_id in "${BANNED_WINDOW_IDS[@]}"; do
    # Fetch window information
    window_info=$(wmctrl -lG | awk -v id="$banned_id" '$1 == id {print $3, $4, $5, $6}')
    echo "window info = $window_info"

    if [ -z "$window_info" ]; then
      echo "Could not find window info for $banned_id"
      continue
    fi

    # Extract coordinates and size
    read -r target_x target_y target_width target_height <<<"$window_info"

    target_x=$(echo "$target_x / 2" | bc)
    target_y=$(echo "$target_y / 2" | bc)

    # Check if window is visible
    if is_window_visible "$banned_id" "$target_x" "$target_y" "$target_width" "$target_height"; then
      # Calculate normalized values
      center_x=$(echo "($target_x + $target_width / 2)" | bc)
      center_y=$(echo "($target_y + $target_height / 2)" | bc)
      echo "visbible window at $target_x, $target_y and height $target_width x $target_height"
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

# Function to create a screenshot and data file of the main screen only
create_datapoint() {
  local banned=("$@") timestamp=$(date +%s)
  screenshot_path=~/Desktop/test/email/images/screenshot_${timestamp}.png
  datafile_path=~/Desktop/test/email/lables/screenshot_${timestamp}.txt

  # Get primary screen's geometry
  main_screen_geometry=$(xrandr | grep ' primary' | grep -oP '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+')

  if [ -n "$main_screen_geometry" ]; then
    # Capture screenshot of the main screen area only with ImageMagick
    import -window root -crop "$main_screen_geometry" "$screenshot_path"
  else
    echo "Primary screen not found, capturing entire screen as fallback."
    gnome-screenshot -f "$screenshot_path"
  fi

  # Write banned items data
  if [ ${#banned[@]} -eq 0 ]; then
    touch "$datafile_path"
    return
  fi
  for ((i = 0; i < ${#banned[@]}; i += 5)); do
    echo "${banned[i]} ${banned[i + 1]} ${banned[i + 2]} ${banned[i + 3]} ${banned[i + 4]}" >>"$datafile_path"
  done
}

change_background() {
  backgrounds=()
  while IFS= read -r -d '' file; do
    backgrounds+=("$file")
  done < <(find "$BACKGROUND_DIR" -type f -print0)

  if [ ${#backgrounds[@]} -eq 0 ]; then
    echo "No images found in $BACKGROUND_DIR"
    return
  fi

  # Generate a random index based on the number of files
  index=$((RANDOM % ${#backgrounds[@]}))

  # Use gsettings with picture-uri-dark to set the wallpaper
  gsettings set org.gnome.desktop.background picture-uri-dark "file://${backgrounds[$index]}"
}

# Call the function to change the background
change_background
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
