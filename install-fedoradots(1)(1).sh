#!/usr/bin/env bash

# Exit on error, unset variables, and pipe failures
set -euo pipefail

# Set DIR to the base directory of the script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DIR
echo "Base directory set to: $DIR"

# Define source directories
SRC_SPEC="$DIR/spectrwm/linux"
SRC_DMENU="$DIR/dmenu-solarized"
SRC_XTITLE="$DIR/xtitle"
SRC_DOTFILES="$DIR/dotfiles"
DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

# Function to check if command succeeded
check_success() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed"
    exit 1
  fi
}

# Function to install packages
install_packages() {
  echo "Installing required packages..."
  sudo dnf5 install -y $@
  check_success "Package installation"
}

# Function to clone repositories
clone_repo() {
  local repo_url="$1"
  local target_dir="$2"
  
  if [ ! -d "$target_dir" ]; then
    echo "Cloning $repo_url to $target_dir"
    git clone "$repo_url" "$target_dir"
    check_success "Cloning $repo_url"
  else
    echo "$target_dir already exists, skipping clone"
  fi
}

# Function to remove conflicting files and directories
remove_conflicts() {
  local target_path="$1"
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    echo "Removing: $target_path"
    rm -rf "$target_path"
  fi
}

# Main installation process
echo "=== Starting Fedora 40 Spectrwm Installation ==="

# Install dnf5
echo "Installing dnf5..."
sudo dnf install -y dnf5
check_success "dnf5 installation"

# Add RPM Fusion non-free repositories
echo "Adding RPM Fusion non-free repositories..."
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
#sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
check_success "RPM Fusion repository setup"

sudo ln -s /usr/include/freetype2/ft2build.h /usr/include/ft2build.h
sudo ln -s /usr/include/freetype2/freetype /usr/include/freetype

# Define package groups - including development tools packages individually
pkgs_fed="luarocks neovim nodejs kitty stow git wget curl xdotool nitrogen lxappearance picom sxhkd alacritty bspwm"
# Development tools packages
dev_tools="gcc gcc-c++ make automake autoconf libtool patch cmake"
# Compilation dependencies
pkgs_fed_compile="pkg-config libX11-devel libXft-devel libXinerama-devel libXrandr-devel libXpm-devel freetype cairo-devel pango-devel libxcb-devel xcb-util-devel libXcursor-devel xcb-util-wm-devel xcb-util-keysyms-devel libbsd-devel libXt-devel"

# Install packages
echo "Installing general packages..."
install_packages "$pkgs_fed"

echo "Installing development tools..."
install_packages "$dev_tools"
check_success "Development tools installation"

echo "Installing compilation dependencies..."
install_packages "$pkgs_fed_compile"

# Clone repositories
echo "Cloning required repositories..."
clone_repo "https://gitlab.com/cuauhtlios/bin.git" "$DIR/bin"
clone_repo "https://github.com/conformal/spectrwm.git" "$DIR/spectrwm"
clone_repo "https://gitlab.com/shastenm/dmenu-solarized.git" "$DIR/dmenu-solarized"
clone_repo "https://github.com/baskerville/xtitle.git" "$DIR/xtitle"
clone_repo "https://gitlab.com/shastenm/dotfiles.git" "$DIR/dotfiles"
clone_repo "https://gitlab.com/shastenm/wallpaper.git" "$DIR/wallpaper"

# Setup fonts
echo "Setting up fonts..."
mkdir -p "$HOME/.local/share/fonts/"
if [ -d "$DIR/fonts" ]; then
  cp -r "$DIR/fonts/"* "$HOME/.local/share/fonts/"
  check_success "Font installation"
  fc-cache -fv
else
  echo "Warning: Fonts directory not found at $DIR/fonts"
fi

# Setup bin directory
echo "Setting up bin directory..."
if [ -d "$DIR/bin" ]; then
  mkdir -p "$HOME/.local/bin"
  cp -r "$DIR/bin/"* "$HOME/.local/bin/"
  check_success "Bin installation"
else
  echo "Warning: Bin directory not found at $DIR/bin"
fi

# Compile and install software
echo "Compiling and installing spectrwm..."
if [ -d "$SRC_SPEC" ]; then
  cd "$SRC_SPEC"
  make
  check_success "spectrwm compilation"
  sudo make install
check_success "spectrwm installation"
cd "$DIR"
else
  echo "Error: spectrwm source directory not found"
  exit 1
fi

echo "Compiling and installing dmenu..."
if [ -d "$SRC_DMENU" ]; then
  cd "$SRC_DMENU"
  make
  check_success "dmenu compilation"
  sudo make clean install
  check_success "dmenu installation"
  cd "$DIR"
else
  echo "Error: dmenu source directory not found"
  exit 1
fi

echo "Compiling and installing xtitle..."
if [ -d "$SRC_XTITLE" ]; then
  cd "$SRC_XTITLE"
  make
  check_success "xtitle compilation"
  sudo make install
  check_success "xtitle installation"
  cd "$DIR"
else
  echo "Error: xtitle source directory not found"
  exit 1
fi

# Install dzen2 if RPM exists
if [ -f "$DIR/dzen2.rpm" ]; then
  echo "Installing dzen2 from RPM..."
  sudo dnf install -y "$DIR/dzen2.rpm"
  check_success "dzen2 installation"
else
  echo "Warning: dzen2.rpm not found at $DIR/dzen2.rpm"
fi

# Setup cargo environment
echo "Setting up cargo environment..."
mkdir -p "$HOME/.cargo"
touch "$HOME/.cargo/env"

# Install Starship prompt
echo "Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh
check_success "Starship installation"

# Setup wallpapers
if [ -d "$DIR/wallpaper" ]; then
  echo "Setting up wallpapers..."
  mkdir -p "$HOME/Pictures"
  cp -r "$DIR/wallpaper/"* "$HOME/Pictures/"
  check_success "Wallpaper installation"
else
  echo "Warning: Wallpaper directory not found"
fi
# backup bashrc

# mv $HOME/.bashrc $HOME/.bashrc.bak

# Setup dotfiles
echo "Setting up dotfiles..."
if [ -d "$DIR/dotfiles" ]; then
  # Remove existing dot dirs and files
  echo "Checking for conflicts in $HOME..."
  for item in "$DIR/dotfiles"/*; do
    # Skip if not a file or directory
    [ -e "$item" ] || continue
    
    dotfile=".$(basename "$item")"
    remove_conflicts "$HOME/$dotfile"
  done

  # Remove conflicting files and directories in .config
  if [ -d "$DIR/dotfiles/.config" ]; then
    echo "Checking for conflicts in $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    for item in "$DIR/dotfiles/.config/"*; do
      # Skip if not a file or directory
      [ -e "$item" ] || continue
      
      config_file="$CONFIG_DIR/$(basename "$item")"
      remove_conflicts "$config_file"
    done
  fi

  # Copy dotfiles to home directory and stow them
  sudo cp -r "$DIR/dotfiles" "$HOME"
  cd "$HOME/dotfiles"
  stow .
  check_success "Dotfiles installation"
else
  echo "Error: Dotfiles directory not found"
  exit 1
fi

echo "=== Installation Complete ==="
echo "You may need to log out and select spectrwm at the login screen to use your new window manager."
