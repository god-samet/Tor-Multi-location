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

# تابع برای بررسی کد کشور معتبر
function validate_country_code() {
    local country_code=$1
    # می‌توانید چک کنید که آیا کد کشور به درستی وارد شده است
    if [[ ! $country_code =~ ^[A-Za-z]{2}$ ]]; then
        echo -e "${RED}Invalid country code. Please enter a 2-letter country code (e.g., fr, it, tr).${NC}"
        echo "$(date) - Error: Invalid country code entered: $country_code" >> $LOG_FILE
        return 1
    fi
    return 0
}

# تابع اصلی برای اضافه کردن تنظیمات
function add_instance() {
    while true; do
        clear  
        echo -e "${YELLOW}Enter country code (e.g., fr, it, tr):${NC}"
        read country_code

        # تبدیل کد کشور به حروف بزرگ و بررسی
        country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')
        validate_country_code $country_code || return

        # درخواست پورت از کاربر یا انتخاب خودکار
        echo -e "${YELLOW}Enter a local port (or press Enter for random):${NC}"
        read local_port
        if [[ -z $local_port ]]; then
            echo -e "${YELLOW}No port entered. Searching for a free port...${NC}"
            local_port=$(find_free_port)
            if [[ -z $local_port ]]; then
                echo -e "${RED}No available ports found.${NC}"
                echo "$(date) - Error: No free port found." >> $LOG_FILE
                return
            fi
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

        # نمایش اطلاعات
        echo -e "${GREEN}Instance created successfully with the following details:${NC}"
        echo -e "Country code: $country_code"
        echo -e "Local IP: $local_ip"
        echo -e "Port: $local_port"
        echo -e "Instance configuration saved to $instance_file"

        # درخواست برای ادامه یا خروج
        echo -e "${YELLOW}Press Enter to add another instance or type 'exit' to go back to the main menu:${NC}"
        read user_input
        if [[ -z $user_input ]]; then
            # ادامه به حلقه
            echo -e "${CYAN}Adding new instance...${NC}"
            continue
        elif [[ "$user_input" == "exit" ]]; then
            # خروج از حلقه
            echo -e "${CYAN}Exiting...${NC}"
            break
        fi
    done
    
    # پاک‌سازی صفحه و نمایش منوی اصلی
    clear
    show_main_menu
}

# تابع برای نمایش تنظیمات موجود
function view_instances() {
    while true; do
        clear  # پاک‌کردن صفحه
        echo -e "${YELLOW}Available settings:${NC}"
        
        # بررسی تنظیمات در فایل torrc
        settings=$(grep -E "SocksPort|ExitNodes" $torrc_file)
        
        if [ -z "$settings" ]; then
            echo -e "${RED}Nothing in the file!${NC}"  # اگر هیچ تنظیماتی وجود ندارد
        else
            echo "$settings"  # نمایش تنظیمات موجود
        fi

        # پیام برای ادامه یا خروج
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # منتظر ورودی از کاربر
        if [ -z "$REPLY" ]; then
            break  # اگر کاربر اینتر بزند، از حلقه خارج می‌شود
        fi
    done
    show_menu  # نمایش منوی اصلی پس از خروج از حلقه
}


# تابع برای حذف تنظیمات
function delete_instance() {
    while true; do
        echo -e "\n**Enter the port of the settings you want to delete (or press Enter to exit):"
        read port_to_delete

        if [ -z "$port_to_delete" ]; then
            # اگر کاربر اینتر بزند بدون وارد کردن پورت، از حلقه خارج می‌شود
            break
        fi

        # حذف تنظیمات مربوط به پورت وارد شده
        sudo sed -i "/SocksPort .*:$port_to_delete/,+2d" $torrc_file
        echo -e "${GREEN}Port settings for $port_to_delete have been deleted.${NC}"

        # بارگذاری مجدد سرویس Tor برای اعمال تغییرات
        sudo systemctl reload tor

        # پاک‌سازی صفحه برای نمایش وضعیت به روز شده
        clear
    done

    # نمایش منوی اصلی بعد از خروج از حلقه
    show_menu
}


function schedule_ip_change() {
    while true; do
        clear  # Clear the screen
        echo "**How often should the IP change? (minutes, e.g., 10):"
        read interval

        if [ -z "$interval" ]; then
            # If no input is given, exit the loop and return to the menu
            break
        fi

        # Schedule the IP change in crontab
        echo "*/$interval * * * * root echo 'SIGNAL NEWNYM' | nc 127.0.0.1 9051" | sudo tee -a /etc/crontab

        # Display success message
        echo -e "${GREEN}IP change has been set to every $interval minutes.${NC}"

        # Clear the screen to show updated status
        clear
    done

    # After exiting the loop, show the menu again
    show_menu
}


function show_current_ip() {
    while true; do
        clear  # Clear the screen
        echo "**Enter the port to check the IP (or press Enter to exit):"
        read check_port

        if [ -z "$check_port" ]; then
            # If no input is given, exit the loop and return to the menu
            break
        fi

        # Check the IP using the entered port
        echo -e "Current IP: $(curl --socks5-hostname 127.0.0.1:$check_port https://check.torproject.org/api/ip | jq '.ip')"

        # Wait for user to press Enter to continue or exit
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # Wait for user input

        if [ -z "$REPLY" ]; then
            break  # If Enter is pressed, exit the loop and return to the menu
        fi

        # Clear the screen to show updated status
        clear
    done

    # After exiting the loop, show the menu again
    show_menu
}


function test_connection() {
    while true; do
        clear  # Clear the screen
        echo "**Enter the port to test the connection (or press Enter to exit):"
        read test_port

        if [ -z "$test_port" ]; then
            # If no input is given, exit the loop and return to the menu
            break
        fi

        # Test the connection using the entered port
        echo -e "Testing connection on port $test_port..."
        curl --socks5-hostname 127.0.0.1:$test_port https://www.google.com -I

        # Wait for user to press Enter to continue or exit
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # Wait for user input

        if [ -z "$REPLY" ]; then
            break  # If Enter is pressed, exit the loop and return to the menu
        fi

        # Clear the screen to show updated status
        clear
    done

    # After exiting the loop, show the menu again
    show_menu
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
    while true; do
        clear  # صفحه پاک شود
        echo "**Enter the port of the settings you want to edit (or press Enter to exit):"
        read edit_port

        # اگر کاربر اینتر بدون وارد کردن مقدار زد، از حلقه خارج شود
        if [ -z "$edit_port" ]; then
            break
        fi

        # فایل مربوط به پورت وارد شده
        instance_file="$instances_dir/torrc-127.0.0.1-$edit_port"

        # بررسی اینکه آیا فایل برای این پورت وجود دارد
        if [[ ! -f $instance_file ]]; then
            echo -e "${RED}No settings found for port $edit_port${NC}"
            continue  # اگر فایل پیدا نشد، دوباره از کاربر پورت خواسته شود
        fi

        # نمایش تنظیمات موجود برای پورت وارد شده
        echo -e "${YELLOW}=== Edit Settings for Port $edit_port ===${NC}"
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

    # بعد از تمام شدن عملیات، صفحه پاک شود و منوی اصلی نشان داده شود
    clear
    show_menu
}

while true; do
      clear  
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


