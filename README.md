# Window Switcher 
This project is a dataset generator for creating screenshots of different window and background setups for training a model to detect if certain programs are open on screen. Scripts for Linux, OSX and Windows are provided.

## Usage
Each script requires some preparation before running. The scripts are designed to be run in a terminal or command prompt. The scripts will take screenshots of the current screen and save them to a folder. The folder will be created in the same directory as the script. 

### Linux
The Linux script only works on Gnome desktop environments. The script requires the `xdotool` and `gnome-screenshot` packages to be installed.
Before running the following parameters must be set in the script:

- BANNED_WINDOW_IDS: List of window IDs to check for visibility
- HEADER_OFFSET: Height of the header bar in pixels
- BANNED_CLASS: Specify which label you are creating screenshots for
- BACKGROUND_DIR: Absolute path to background images to be used
### OSX
The OSX script requires the [_yabai_](https://github.com/koekeishiya/yabai) window manager to be installed.
Before running the following parameters must be set in the script:

- WINDOW_SCALE: Scaling factor of screen resolution
- BANNED_WINDOW_IDS: List of window IDs to check for visibility
- HEADER_OFFSET: Height of the header bar in pixels
- BACKGROUND_DIR : Absolute path to background images to be used
### Windows
The Windows script is a python script that requires the `pygetwindow` and `pyautogui` packages to be installed.
Before running the following parameters must be set in the script:

- TARGET_WINDOW_IDS: Specify IDs for target windows to interact with
- BANNED_WINDOW_IDS: List of window IDs to check for visibility
- PADDING: Space between windows in pixels
- LABEL: Label you are creating screenshots for
- screenshot_dir: Absolute path where screenshots should be saved
- text_dir: Absolute path where label files should be saved
- background_dir: Absolute path to background images to be used


## Output
By default, all script create 500 screenshots. This can be changed by changing the `ITERATIONS` variable in the script.
The screenshots and label files are saved in a YOLOv11 compatible labeling format on the Desktop.