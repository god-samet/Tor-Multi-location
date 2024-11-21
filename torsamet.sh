#!/bin/bash
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'  # Reset color

# مسیرها به صورت متغیرهای سراسری
LOG_FILE="/var/log/tor_instance.log"  # فایل لاگ برای ذخیره گزارش‌ها
TORRC_FILE="/etc/tor/torrc"  # فایل پیکربندی Tor
INSTANCES_DIR="$HOME/tor_instances"  # دایرکتوری برای ذخیره تنظیمات
# بررسی نصب بودن Tor
function check_tor_status() {
    if command -v tor > /dev/null; then
        echo -e "${GREEN}======= Tor is installed. =======${NC}"
        return 0
    else
        echo -e "${RED}======= Tor is not installed. =======${NC}"
        return 1
    fi
}
# نمایش لوگو با استفاده از ASCII Art
function show_logo() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${MAGENTA}                    _________  ________  ________          ________  ________  _____ ______   _______  _________    ${NC}"    
    echo -e "${YELLOW}                    |\___   ___\\   __  \|\   __  \        |\   ____\|\   __  \|\   _ \  _   \|\  ___ \|\___   ___\    ${NC}"  
    echo -e "${GREEN}                     \|___ \  \_\ \  \|\  \ \  \|\  \       \ \  \___|\ \  \|\  \ \  \\\__\ \  \ \   __/\|___ \  \_|      ${NC}"
    echo -e "${BLUE}                           \ \  \ \ \  \\\  \ \   _  _\       \ \_____  \ \   __  \ \  \\|__| \  \ \  \_/__   \ \  \       ${NC}"
    echo -e "${RED}                             \ \  \ \ \  \\\  \ \  \\  \|       \|____|\  \ \  \ \  \ \  \    \ \  \ \  \_|\ \  \ \  \      ${NC}"
    echo -e "${MAGENTA}                          \ \__\ \ \_______\ \__\\ _\         ____\_\  \ \__\ \__\ \__\    \ \__\ \_______\  \ \__\     ${NC}"
    echo -e "${GREEN}                             \|__|  \|_______|\|__|\|__|       |\_________\|__|\|__|\|__|     \|__|\|_______|   \|__|     ${NC}"
    echo -e "${YELLOW}                                                               \|_________|                                               ${NC}"
    echo -e "${CYAN}======================================${NC}"
}


function install_tor() {
    echo -e "${YELLOW}Installing Tor...${NC}"
    sudo apt update && sudo apt install -y tor
    if [[ $? -eq 0 && -f /usr/bin/tor ]]; then
        echo -e "${GREEN}Tor successfully installed.${NC}"
    else
        echo -e "${RED}Error installing Tor. Check your internet connection or repository configuration.${NC}"
    fi
}

function uninstall_tor() {
    echo -e "${YELLOW}Removing Tor...${NC}"
    sudo apt remove -y tor && sudo apt purge -y tor
    if [[ $? -eq 0 && ! -f /usr/bin/tor ]]; then
        echo -e "${GREEN}Tor successfully removed.${NC}"
    else
        echo -e "${RED}Error removing Tor. Tor might still be installed partially.${NC}"
    fi
}

function show_menu() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${GREEN}        Tor Samet Management Script       ${NC}"
    echo -e "${CYAN}======================================${NC}"
    
    # وضعیت Tor
    check_tor_status
    
    echo -e "${CYAN}======= Tor Management Menu =======${NC}"
    echo -e "${WHITE}1)${NC} Install Tor"
    echo -e "${WHITE}2)${NC} Uninstall Tor"
    echo -e "${WHITE}3)${NC} Add New Configuration"
    echo -e "${WHITE}4)${NC} View Existing Configurations"
    echo -e "${WHITE}5)${NC} Delete Configuration"
    echo -e "${WHITE}6)${NC} Schedule IP Change"
    echo -e "${WHITE}7)${NC} Show Current IP"
    echo -e "${WHITE}8)${NC} Test Connection"
    echo -e "${WHITE}9)${NC} Tor Service Status"
    echo -e "${WHITE}10)${NC} Backup Configurations"
    echo -e "${WHITE}11)${NC} Edit Local IP"
    echo -e "${WHITE}0)${NC} Exit"
    echo -e "${CYAN}======================================${NC}"
    echo -e "${YELLOW}Please choose an option (0-11):${NC}"
    read choice
}

# تابع برای بررسی کد کشور
function validate_country_code() {
    local country_code=$1
    if [[ ! $country_code =~ ^[A-Z]{2}$ ]]; then
        echo -e "${RED}Invalid country code. Please use a valid ISO code (e.g., FR, IT, TR).${NC}"
        echo "$(date) - Error: Invalid country code entered: $country_code" >> $LOG_FILE
        return 1
    fi
    return 0
}

# تابع برای پیدا کردن پورت آزاد
function find_free_port() {
    for port in {9050..65535}; do
        if ! lsof -i:$port &>/dev/null; then
            echo $port
            return
        fi
    done
    return 1
}

# تابع برای بررسی IP معتبر
function validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^127\.0\.0\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid IP address. Please use a local IP in the range 127.0.0.1 - 127.0.0.255.${NC}"
        echo "$(date) - Error: Invalid local IP entered: $ip" >> $LOG_FILE
        return 1
    fi
    return 0
}

# تابع اصلی برای اضافه کردن تنظیمات
function add_instance() {
    echo -e "${YELLOW}Enter country code (e.g., fr, it, tr):${NC}"
    read country_code

    # تبدیل کد کشور به حروف بزرگ و بررسی
    country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')
    validate_country_code $country_code || return

    # پیدا کردن یک پورت آزاد به صورت خودکار
    echo -e "${YELLOW}Searching for a free port...${NC}"
    local local_port=$(find_free_port)
    if [[ -z $local_port ]]; then
        echo -e "${RED}No available ports found.${NC}"
        echo "$(date) - Error: No free port found." >> $LOG_FILE
        return
    fi

    # درخواست IP از کاربر
    echo -e "${YELLOW}Enter local IP (default is 127.0.0.1):${NC}"
    read local_ip
    local_ip=${local_ip:-127.0.0.1}  # اگر کاربر چیزی وارد نکرد، از 127.0.0.1 استفاده کن

    # بررسی IP وارد شده
    validate_ip $local_ip || return

    # چک کردن دایرکتوری‌ها و فایل‌های لازم
    if [[ ! -d $INSTANCES_DIR ]]; then
        echo -e "${RED}Instances directory not found: $INSTANCES_DIR${NC}"
        echo "$(date) - Error: Instances directory not found: $INSTANCES_DIR" >> $LOG_FILE
        return
    fi

    if [[ ! -f $TORRC_FILE ]]; then
        echo -e "${RED}Tor configuration file not found: $TORRC_FILE${NC}"
        echo "$(date) - Error: Tor configuration file not found: $TORRC_FILE" >> $LOG_FILE
        return
    fi

    # چک کردن پورت در فایل اصلی
    if grep -q "SocksPort $local_ip:$local_port" $TORRC_FILE; then
        echo -e "${RED}Port $local_port already exists in the Tor configuration.${NC}"
        echo "$(date) - Error: Port $local_port already in use in the configuration." >> $LOG_FILE
        return
    fi

    # ایجاد تنظیمات جدید
    instance_file="$INSTANCES_DIR/torrc-$local_port"
    echo "SocksPort $local_ip:$local_port" > $instance_file
    echo "ExitNodes {$country_code}" >> $instance_file
    echo "StrictNodes 1" >> $instance_file

    # افزودن تنظیمات به فایل اصلی
    cat $instance_file >> $TORRC_FILE

    # چک کردن وضعیت سرویس Tor
    if ! systemctl is-active --quiet tor; then
        echo -e "${RED}Tor service is not running. Starting it now...${NC}"
        if ! sudo systemctl start tor; then
            echo -e "${RED}Failed to start Tor service.${NC}"
            echo "$(date) - Error: Failed to start Tor service." >> $LOG_FILE
            return
        fi
    fi

    # بارگذاری مجدد Tor
    echo -e "${YELLOW}Reloading Tor service...${NC}"
    if ! sudo systemctl reload tor; then
        echo -e "${RED}Failed to reload Tor. Check configuration or system status.${NC}"
        echo "$(date) - Error: Failed to reload Tor service." >> $LOG_FILE
        return
    fi

    # اطمینان از اضافه شدن پورت
    if lsof -i:$local_port &>/dev/null; then
        echo -e "${GREEN}Settings for country ${country_code} with port ${local_port} added successfully.${NC}"
        echo -e "${GREEN}Socks proxy available at ${local_ip}:${local_port}${NC}"
        echo "$(date) - Success: Configuration for $country_code with port $local_port added." >> $LOG_FILE
    else
        echo -e "${RED}Failed to enable port ${local_port}. Check Tor configuration.${NC}"
        echo "$(date) - Error: Failed to enable port $local_port." >> $LOG_FILE
    fi
}
# مشاهده تنظیمات موجود
function view_instances() {
    echo -e "${YELLOW}Available settings:${NC}"
    grep -E "SocksPort|ExitNodes" $torrc_file
}

function delete_instance() {
    echo "**Port of the settings you want to delete:"
    read port_to_delete
    sudo sed -i "/SocksPort .*:$port_to_delete/,+2d" $torrc_file
    echo -e "${GREEN}Port settings $port_to_delete have been deleted.${NC}"
    sudo systemctl reload tor
}

function schedule_ip_change() {
    echo "**How often should the IP change? (minutes, e.g., 10):"
    read interval
    echo "*/$interval * * * * root echo 'SIGNAL NEWNYM' | nc 127.0.0.1 9051" | sudo tee -a /etc/crontab
    echo -e "${GREEN}IP change has been set to every $interval minutes.${NC}"
}

function show_current_ip() {
    echo "**Enter the port to check the IP:"
    read check_port
    curl --socks5-hostname 127.0.0.1:$check_port https://check.torproject.org/api/ip
}

function test_connection() {
    echo "**Enter the port to test the connection: "
    read test_port
    curl --socks5-hostname 127.0.0.1:$test_port https://www.google.com -I
}

function check_service_status() {
    echo -e "${YELLOW}Tor service status:${NC}"
    sudo systemctl status tor | grep "Active"
}

function backup_torrc() {
    sudo cp $torrc_file $torrc_file.bak
    echo -e "${GREEN}The settings backup has been saved in the file $torrc_file.bak.${NC}"
}

function edit_local_ip() {
    echo "**Enter the port of the settings you want to edit:"
    read edit_port

    echo "**Enter the local IP for the settings you want to edit (e.g., 127.0.0.1):"
    read edit_local_ip

    # بررسی اگر تنظیمات برای پورت و آی‌پی لوکال موجود باشد
    instance_file="$instances_dir/torrc-$edit_local_ip-$edit_port"
    if [[ ! -f $instance_file ]]; then
        echo -e "${RED}No settings found for local IP $edit_local_ip and port $edit_port${NC}"
        return
    fi

    while true; do
        echo -e "${YELLOW}=== Edit Settings for IP $edit_local_ip and Port $edit_port ===${NC}"
        echo "1) Change Local IP"
        echo "2) Change Port"
        echo "3) Change Country"
        echo "4) Exit"
        echo -e "${YELLOW}==============================${NC}"
        echo "Your choice:"
        read choice

        case $choice in
            1) 
                # تغییر آی‌پی لوکال
                echo "Enter new local IP (e.g., 127.0.0.2):"
                read new_ip
                sudo sed -i "s/^SocksPort .*/SocksPort $new_ip:$edit_port/" $instance_file
                echo -e "${GREEN}Local IP for port $edit_port has been changed to $new_ip.${NC}"
                sudo systemctl reload tor
                ;;

            2) 
                # تغییر پورت
                echo "Enter new port (e.g., 9050):"
                read new_port
                sudo sed -i "s/^SocksPort .*/SocksPort 127.0.0.1:$new_port/" $instance_file
                echo -e "${GREEN}Port for local IP $edit_local_ip has been changed to $new_port.${NC}"
                sudo systemctl reload tor
                ;;

            3)
                # تغییر کشور
                echo "Enter new country code (e.g., fr, it, tr):"
                read new_country
                sudo sed -i "s/^ExitNodes.*/ExitNodes {$new_country}/" $instance_file
                echo -e "${GREEN}Country for port $edit_port has been changed to $new_country.${NC}"
                sudo systemctl reload tor
                ;;

            4)
                # خروج
                echo -e "${GREEN}Exiting the editing menu.${NC}"
                break
                ;;

            *)
                echo -e "${RED}Invalid option, please try again.${NC}"
                ;;
        esac
    done
}

while true; do
     show_logo
     show_menu
    case $choice in
        1) install_tor ;;
        2) uninstall_tor ;;
        3) add_instance ;;
        4) view_instances ;;
        5) delete_instance ;;
        6) schedule_ip_change ;;
        7) show_current_ip ;;
        8) test_connection ;;
        9) check_service_status ;;
        10) backup_torrc ;;
        11) edit_local_ip ;;
        0) break ;;
        *)
            echo -e "${RED}Invalid choice, please try again.${NC}"
            ;;
    esac
done


