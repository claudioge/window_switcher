import os
import time
import random
import pyautogui
import pygetwindow as gw
import ctypes
from PIL import ImageGrab
from datetime import datetime


# Configuration
WINDOW_SCALE = 1
TARGET_WINDOW_IDS = []  # Specify IDs for target windows to interact with
BANNED_WINDOW_IDS = []  # List of window IDs to check for visibility
PADDING = 10  # Space between windows in pixels
LABEL = 2 # Specify which label you are creating screenshots for

ITERATIONS = 500 # Number of iterations to run the script

# Directories for screenshots and logs
screenshot_dir = ""
text_dir = ""
background_dir = ""
os.makedirs(screenshot_dir, exist_ok=True)
os.makedirs(text_dir, exist_ok=True)

# Screen dimensions
screen_width, screen_height = pyautogui.size()
phys_screen_width = screen_width * WINDOW_SCALE
phys_screen_height = screen_height * WINDOW_SCALE

print(f"Screen resolution: {screen_width}x{screen_height}")

# --- Function Definitions ---

def random_range(min_val, max_val):
    """Generates a random integer between min and max, inclusive."""
    return random.randint(min_val, max_val)

def random_range_edge_bias(min_val, max_val):
    """Generates a random number with a bias towards the edges."""
    midpoint = (min_val + max_val) / 2
    if random.random() < 0.5:
        return random.randint(min_val, int(midpoint))
    else:
        return random.randint(int(midpoint), max_val)

def change_background():
    """Change the desktop background to a random image from the specified directory."""
    backgrounds = [os.path.join(background_dir, f) for f in os.listdir(background_dir) if os.path.isfile(os.path.join(background_dir, f))]
    if backgrounds:
        background = random.choice(backgrounds)
        ctypes.windll.user32.SystemParametersInfoW(20, 0, background, 3)  # SPI_SETDESKWALLPAPER
        print(f"Background changed to {background}")
        time.sleep(1)
    else:
        print("No background images found.")

def filter_windows(window_list, window_ids):
    """Filters windows by IDs or titles."""
    return [window for window in window_list if (str(window._hWnd) in window_ids)]



def arrange_windows_non_overlapping(target_windows):
    """Arranges windows in a randomly shuffled grid layout, ensuring natural side-by-side 
    placement for small numbers but varied positions for each run."""
    num_windows = len(target_windows)
    if num_windows == 0:
        print("No target windows found.")
        return

    # Shuffle windows to ensure different positions each time
    random.shuffle(target_windows)

    # Handle special cases for few windows
    if num_windows == 2:
        num_columns, num_rows = 2, 1
    elif num_windows == 3:
        num_columns, num_rows = 3, 1
    else:
        # Balanced grid layout for larger numbers of windows
        num_columns = int(num_windows ** 0.5)
        num_rows = (num_windows + num_columns - 1) // num_columns

    # Calculate base cell dimensions
    base_cell_width = (screen_width - (PADDING * (num_columns + 1))) // num_columns
    base_cell_height = (screen_height - (PADDING * (num_rows + 1))) // num_rows

    # Randomly shuffled list of grid cell coordinates
    grid_positions = [(row, col) for row in range(num_rows) for col in range(num_columns)]
    random.shuffle(grid_positions)

    for index, window in enumerate(target_windows):
        # Get randomized grid position
        row, col = grid_positions[index]

        # Calculate randomized window size within cell bounds
        cell_width = random.randint(int(0.9 * base_cell_width), int(1.1 * base_cell_width))
        cell_height = random.randint(int(0.9 * base_cell_height), int(1.1 * base_cell_height))

        # Ensure cell size fits within screen bounds
        cell_width = min(cell_width, screen_width - PADDING * (num_columns + 1))
        cell_height = min(cell_height, screen_height - PADDING * (num_rows + 1))

        # Calculate window position within the grid cell with slight jitter
        x = PADDING + col * (base_cell_width + PADDING) + random.randint(-PADDING // 4, PADDING // 4)
        y = PADDING + row * (base_cell_height + PADDING) + random.randint(-PADDING // 4, PADDING // 4)

        # Move and resize the window
        window.resizeTo(cell_width, cell_height)
        window.moveTo(x, y)
        print(f"Positioned window '{window.title}' at ({x}, {y}) with size ({cell_width}, {cell_height})")

    return True



def is_window_visible(window, banned_windows):
    """Checks if a window is visible on the screen."""
    x, y, width, height = window.left, window.top, window.width, window.height
    for banned_window in banned_windows:
        banned_x, banned_y, banned_width, banned_height = banned_window.left, banned_window.top, banned_window.width, banned_window.height
        if (x < banned_x + banned_width and x + width > banned_x and
            y < banned_y + banned_height and y + height > banned_y):
            return True
    return False


def check_banned_windows_visibility(banned_windows):
    """Checks if any banned windows are visible and logs their normalized coordinates if so."""
    print("Checking for banned windows visibility...")
    visible_windows_info = []
    for window in banned_windows:
        print(f"Checking visibility of banned window '{window.title}'")
        x, y, width, height = window.left, window.top, window.width, window.height
        if is_window_visible(window, banned_windows):
            # Normalize window position and dimensions
            center_x = (x + width / 2) / phys_screen_width
            center_y = (y + height / 2) / phys_screen_height
            norm_width = width / phys_screen_width
            norm_height = height / phys_screen_height
            visible_windows_info.append((center_x, center_y, norm_width, norm_height))
            print(f"Banned window '{window.title}' is visible at normalized coordinates ({center_x}, {center_y}) with size ({norm_width}, {norm_height})")
    return visible_windows_info

def create_datapoint(visible_windows_info):
    """Takes a screenshot and creates a data file with information about visible banned windows."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    screenshot_path = os.path.join(screenshot_dir, f"screenshot_{timestamp}.png")
    datafile_path = os.path.join(text_dir, f"screenshot_{timestamp}.txt")

    # Capture the main screen
    screenshot = ImageGrab.grab()
    screenshot.save(screenshot_path)
    print(f"Screenshot saved to {screenshot_path}")

    # Log the visible windows' data
    with open(datafile_path, 'w') as file:
        for info in visible_windows_info:
            file.write(f"{LABEL} {info[0]} {info[1]} {info[2]} {info[3]}\n")
    print(f"Visible banned window data written to {datafile_path}")

# --- Main Execution Loop ---
for _ in range(ITERATIONS):
    # Change the background
    change_background()

    # Filter windows by targets and banned lists
    all_windows = gw.getAllWindows()
    print('all_windows', [[all_windows.title, all_windows._hWnd] for all_windows in all_windows])
    target_windows = filter_windows(all_windows, TARGET_WINDOW_IDS)
    banned_windows = filter_windows(all_windows, BANNED_WINDOW_IDS)

    # Move and resize only the target windows
    arrange_windows_non_overlapping(target_windows)
    
    print('target_windows', target_windows)

    # Check visibility of banned windows and create a datapoint
    visible_windows_info = check_banned_windows_visibility(banned_windows)
    create_datapoint(visible_windows_info)
    
    time.sleep(1)  # Pause before the next iteration
