#!/bin/bash

# تنظیمات اولیه
torrc_file="/etc/tor/torrc"
instances_dir="/etc/tor/instances"

# رنگ‌ها برای رابط کاربری
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# بررسی نصب بودن Tor
function check_tor_status() {
    if command -v tor > /dev/null; then
        echo -e "${GREEN}Tor is already installed.${NC}"
        return 0
    else
        echo -e "${RED}Tor is not installed.${NC}"
        echo -e "${YELLOW}Please run 'sudo apt update && sudo apt install -y tor' manually if the script fails.${NC}"
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

# نمایش منو
function show_menu() {
    echo "=============Script by samet========"
    echo "======telgram id @hoot0ke:==========="
    echo -e "${YELLOW}=== Tor Management Menu ===${NC}"
    echo "1) Install Tor"
    echo "2) Uninstall Tor"
    echo "3) Add New Configuration"
    echo "4) View Existing Configurations"
    echo "5) List All IPs and Ports"
    echo "6) Delete Configuration"
    echo "7) Schedule IP Change"
    echo "8) Show Current IP"
    echo "9) Test Connection"
    echo "10) Tor Service Status"
    echo "11) Backup Configurations"
    echo "12) Edit Local IP"
    echo "0) Exit"
    echo -e "${YELLOW}=========================${NC}"
    echo "Your choice:"
    read choice
}

function add_instance() {
    echo "Enter country code (e.g., fr, it, tr):"
    read country_code
    echo "Enter port (e.g., 9050):"
    read local_port
    echo "Enter local IP (e.g., 127.0.0.1):"
    read local_ip

    if [[ ! $local_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid IP address.${NC}"
        return
    fi

    if [[ $local_port -lt 1024 || $local_port -gt 65535 ]]; then
        echo -e "${RED}Invalid port number. Ports must be between 1024 and 65535.${NC}"
        return
    fi

    if grep -q "SocksPort $local_ip:$local_port" $torrc_file; then
        echo -e "${RED}Port $local_port is already in use.${NC}"
        return
    fi

    # ایجاد تنظیمات جدید
    instance_file="$instances_dir/torrc-$local_port"
    echo "SocksPort $local_ip:$local_port" > $instance_file
    echo "ExitNodes {$country_code}" >> $instance_file
    echo "StrictNodes 1" >> $instance_file

    echo -e "${GREEN}Settings for country ${country_code} with port ${local_port} added successfully.${NC}"
    cat $instance_file >> $torrc_file
    sudo systemctl reload tor
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
    show_menu
    case $choice in
        1) install_tor ;;
        2) uninstall_tor ;;
        3) add_instance ;;
        4) view_instances ;;
        5) list_ips_ports ;;
        6) delete_instance ;;
        7) schedule_ip_change ;;
        8) show_current_ip ;;
        9) test_connection ;;
        10) check_service_status ;;
        11) backup_torrc ;;
        12) edit_local_ip ;;
        0) break ;;
        *)
            echo -e "${RED}Invalid choice, please try again.${NC}"
            ;;
    esac
done
