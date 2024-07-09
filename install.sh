#!/bin/bash

# Global variables
git_address="https://github.com/erfjab/sqlar.git"
dir_address="/root/sqlar"
py_address="/root/sqlar/sqlar.py"
env_address="/root/sqlar/.env"
venv_name="/root/sqlar/sqlar_venv"
marzban_env_file="/opt/marzban/.env"
version="1.0.1"

# Define colors and Helper functions for colored messages
colors=( "\033[1;31m" "\033[1;35m" "\033[1;92m" "\033[38;5;46m" "\033[1;38;5;208m" "\033[1;36m" "\033[0m" )
red=${colors[0]} pink=${colors[1]} green=${colors[2]} spring=${colors[3]} orange=${colors[4]} cyan=${colors[5]} reset=${colors[6]}
print() { echo -e "${cyan}$1${reset}"; }
error() { echo -e "${red}✗ $1${reset}"; }
success() { echo -e "${spring}✓ $1${reset}"; }
log() { echo -e "${green}! $1${reset}"; }
input() { read -p "$(echo -e "${orange}▶ $1${reset}")" "$2"; }
confirm() { read -p "$(echo -e "\n${pink}Press any key to continue...${reset}")"; }

# Handle SIGINT (Ctrl+C)
trap 'echo -e "\n"; error "Script interrupted by user! if you have problem @ErfJab"; echo -e "\n"; exit 1' SIGINT

# Function to check if user is root, update system, install Python, curl, and necessary packages
check_needs() {
    log "Checking root..."
    echo -e "Current user: $(whoami)"
    if [ "$EUID" -ne 0 ]; then
        error "Error: This script must be run as root."
        exit 1
    fi

    # Update the system
    log "Updating the system..."
    if ! apt-get update -y; then
        error "Failed to update the system."
        exit 1
    fi

    # Install necessary packages
    log "Installing necessary packages..."
    packages=("python3" "python3-venv" "curl" "git")
    for package in "${packages[@]}"; do
        log "Checking $package..."
        if ! dpkg -s "$package" >/dev/null 2>&1; then
            if ! apt-get install -y "$package"; then
                error "Failed to install $package."
                exit 1
            fi
        fi
    done
    success "System updated and required packages installed."
}

# Function for script main menu
menu() {
    clear
    print "\n\t Welcome to Sqlar!"
    print "\t\t version $version develop by @ErfJab (telegram & github)"
    print "—————————————————————————————————————————————————————————————————————————"
    print "1) Install bot"
    print "2) Uninstall bot"
    print "0) Exit"
    print ""
    input "Enter your option number: " option
    case $option in
        1) install_bot ;;
        2) uninstall_bot ;;
        0) print "Thank you for using ErfJab script. Goodbye!"; exit 0 ;;
        *) error "Invalid option, Please select a valid option!"; menu ;;
    esac
}

install_bot() {
    check_needs
    get_db_address
    get_bot_token
    get_admin_chatid
    get_language
    complete_install
    success "Bot installation completed successfully!"
}

get_db_address() {
    if [ ! -f "$marzban_env_file" ]; then
        error "Marzban .env file not found at $marzban_env_file"
        exit 1
    fi
    db_url=$(grep -E "^[[:space:]]*SQLALCHEMY_DATABASE_URL[[:space:]]*=" "$marzban_env_file" | sed -E 's/^[[:space:]]*SQLALCHEMY_DATABASE_URL[[:space:]]*=[[:space:]]*//' | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')
    if [ -n "$db_url" ]; then
        db_url=$(echo "$db_url" | sed 's/mysql+pymysql/mysql+aiomysql/')
        db_url=$(echo "$db_url" | sed 's/sqlite:\/\//sqlite+aiosqlite:\/\//')        
        success "Your db address: $db_url"
    else
        error "SQLALCHEMY_DATABASE_URL not found or is commented out."
        exit 1
    fi
}

get_bot_token() {
    while true; do
        input "Please enter token bot: " token
        response=$(curl -s "https://api.telegram.org/bot$token/getMe")
        if echo "$response" | grep -q '"ok":true'; then
            success "Token is valid."
            break
        else
            error "Invalid token. Please try again."
        fi
    done
}

get_admin_chatid() {
    while true; do
        input "Enter admin chat ID: " admin_chatid
        if [[ "$admin_chatid" =~ ^-?[0-9]+$ ]]; then
            success "Admin chat ID is valid."
            break
        else
            error "Invalid input. Please enter a valid number."
        fi
    done
}

get_language() {
    while true; do
        print "Select language:"
        print "1) English"
        print "2) Persian"
        print "3) Russian"
        input "Enter your language option number: " lang
        case $lang in
            1) language="EN"; break ;;
            2) language="PR"; break ;;
            3) language="RU"; break ;;
            *) error "Invalid input. Please try again." ;;
        esac
    done
    success "Selected language: $language"
}

complete_install() {
    log "Starting installation process..."

    # First, uninstall any existing installation
    log "Checking for existing installation..."
    uninstall_bot

    # Download the project from GitHub
    log "Downloading the project from GitHub..."
    if [ -d "$dir_address" ]; then
        log "Removing existing project directory..."
        if ! rm -rf "$dir_address"; then
            error "Failed to remove existing project directory. Please check permissions."
            exit 1
        fi
    fi
    if ! git clone "$git_address" "$dir_address"; then
        error "Failed to clone the repository. Please check your internet connection and the repository URL."
        exit 1
    fi
    success "Project downloaded successfully."

    # Create .env file
    log "Creating .env file..."
    cat > "$env_address" << EOL
## soqaler bot settings
# bot settings
bot_token = "$token"
admin_chatid = "$admin_chatid"
language = "$language"

# db settings
db_address = "$db_url"
EOL
    if [ $? -ne 0 ]; then
        error "Failed to create .env file. Please check permissions."
        exit 1
    fi
    success ".env file created successfully."

    # Set up virtual environment
    log "Setting up virtual environment..."
    if [ ! -d "$venv_name" ]; then
        if ! python3 -m venv "$venv_name"; then
            error "Failed to create virtual environment. Please check your Python installation."
            exit 1
        fi
    fi
    source "$venv_name/bin/activate"
    if ! pip install -r "$dir_address/requirements.txt"; then
        error "Failed to install dependencies. Please check your internet connection and the requirements.txt file."
        exit 1
    fi
    success "Virtual environment '$venv_name' created and dependencies installed."

    # Set executable permissions
    log "Setting executable permissions..."
    if ! chmod +x "$py_address"; then
        error "Failed to set executable permissions on $py_address. Please check file permissions."
        exit 1
    fi

    # Start the bot using nohup
    log "Starting the bot..."
    nohup "$venv_name/bin/python3" "$py_address" > "$dir_address/bot.log" 2>&1 &
    if [ $? -ne 0 ]; then
        error "Failed to start the bot. Please check the logs."
        exit 1
    fi
    success "Bot started successfully."

    # Set up cron job
    log "Setting up cron job..."
    if ! (crontab -l 2>/dev/null; echo "@reboot cd $dir_address && $venv_name/bin/python3 $py_address > $dir_address/bot.log 2>&1 &") | crontab -; then
        error "Failed to set up cron job. Please check your crontab."
        exit 1
    fi
    success "Cron job set up successfully."

    success "Installation completed successfully!"
    log "The bot is now running in the background. You can check its status using 'ps aux | grep python'"
}

uninstall_bot() {
    log "Starting uninstallation of the bot..."

    # Stop the bot process
    log "Checking if the bot process is running..."
    bot_pids=$(pgrep -f "$py_address")
    if [ -n "$bot_pids" ]; then
        log "Bot process(es) found (PIDs: $bot_pids). Attempting to stop them..."
        
        for pid in $bot_pids; do
            # Attempt to stop the process
            kill $pid
            log "Waiting for process $pid to stop..."
            sleep 2
            
            # Check if the process was stopped
            if kill -0 $pid 2>/dev/null; then
                log "Process $pid still running. Attempting force stop..."
                kill -9 $pid
                sleep 1
            fi
            
            if kill -0 $pid 2>/dev/null; then
                error "Failed to stop bot process $pid. It may require manual intervention."
            else
                success "Bot process $pid stopped successfully."
            fi
        done
    else
        log "No bot processes found running."
    fi

    log "Continuing with uninstallation..."

    # Remove virtual environment
    if [ -d "$venv_name" ]; then
        log "Removing virtual environment..."
        if ! rm -rf "$venv_name"; then
            error "Failed to remove virtual environment. Continuing with uninstallation."
        else
            success "Virtual environment '$venv_name' removed."
        fi
    fi

    # Remove cron job
    log "Removing cron job..."
    if crontab -l 2>/dev/null | grep -q "$py_address"; then
        (crontab -l 2>/dev/null | grep -v "$py_address") | crontab -
        success "Cron job removed."
    else
        log "No cron job found for the bot."
    fi

    # Remove project directory
    if [ -d "$dir_address" ]; then
        log "Removing project directory..."
        if ! rm -rf "$dir_address"; then
            error "Failed to remove project directory. Please check and remove manually: $dir_address"
        else
            success "Project directory removed: $dir_address"
        fi
    else
        log "Project directory not found: $dir_address"
    fi

    # Remove .env file if it exists separately
    if [ -f "$env_address" ] && [ "$env_address" != "$dir_address/.env" ]; then
        log "Removing .env file..."
        if ! rm -f "$env_address"; then
            error "Failed to remove .env file. Please check and remove manually: $env_address"
        else
            success ".env file removed: $env_address"
        fi
    fi

    log "Uninstallation process completed."
    success "Bot uninstallation completed successfully!"
    log "If you encountered any errors during uninstallation, please check and remove any remaining files manually."
}

run() {
    menu
}

run

