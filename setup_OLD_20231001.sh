#!/bin/bash
set -e

#
# Kurzer Überblick über den Code
#
#

readonly FAILURE=1  # In Bash, functions return 0 (SUCCESS) by default, non-zero (FAILURE) indicates error.

print_logo_header() {
    cat <<"EOF"
******************************************
*  _____   _______            _  _ ___   *
* |_   _| |__   __|          | || |__ \  *
*   | |  ___ | |_ __ ___  ___| || |_ ) | *
*   | | / _ \| | '__/ _ \/ _ \__   _/ /  *
*  _| || (_) | | | |  __/  __/  | |/ /_  *
* |_____\___/|_|_|  \___|\___|  |_|____| *
*                                        *
******************************************
<<<----      SETUP OF IoTree42      --->>>
<<<----       Version v0.x.y        --->>>

For installation on a Raspberry Pi, use a PiBakery image on GitHub: 
<hier Link>

EOF
}

is_supported_cpu_architecture() {
    local cpu_architecture=$(uname -m)
    local cpu_arch_prefix=${cpu_architecture:0:3} 

    if [[ "$cpu_arch_prefix" != "amd" && "$cpu_arch_prefix" != "x86" ]]; then
         printf "Your system architecture, $cpu_arch_prefix, is not supported. Please install IoTree42 on an amd64 or x86_64 system.\n"
         return $FAILURE
    fi
}

is_running_with_sudo() {
    if [[ $(whoami) != "root" ]]; then
        printf "You must run this setup with sudo rights.\n"
        printf "Usage: sudo bash setup.sh -p (public) or -l (local).\n"
        return $FAILURE
    fi
}

parse_installation_scheme() {
    local chosen_scheme

    while getopts "pl" option 2>/dev/null; do  # 2>/dev/null discards error (stderr) messages
        case $option in
            p)  
                chosen_scheme="public (https support)" ;;
            l)  
                chosen_scheme="local (no https support)" ;;
            ?)  
                printf "Invalid option! Usage: sudo bash setup.sh -p (public) or -l (local)\n" >&2
                return $FAILURE ;;
        esac
    done
    if [ -z "$chosen_scheme" ]; then
        printf "No options were used. Usage: sudo bash setup.sh -p (public) or -l (local)\n" >&2
        return $FAILURE
    fi
    printf "$chosen_scheme"
}

confirm_proceed() {
    local question_to_ask=$1
    local user_answer

    while true; do
        read -p "${question_to_ask} (y/n): " user_answer

        case "$user_answer" in
            y|Y ) 
                break ;;
            n|N ) 
                printf "You declined to proceed. Exiting setup.\n" >&2
                return $FAILURE ;;
            * ) 
                printf "Invalid response. Please enter 'Y' or 'N'.\n" ;;
        esac
    done
}

is_valid_linux_username() {
    local username=$1
    if ! id "$username" &> /dev/null; then  # &> /dev/null discards stdout and stderr (error) messages
        return $FAILURE   
    fi
}

prompt_for_linux_username() {
    local entered_username
    printf "\n" >&2
    read -p "Enter Linux username for this installation: " entered_username

    if is_valid_linux_username "$entered_username"; then  
        printf "$entered_username"
    else
        printf "The username you entered does not exist. Exiting setup.\n" >&2
        return $FAILURE
    fi
}

prompt_for_password_of_length() {
    local required_length=$1
    local for_reason=$2
    local password
    local password_length
    local password_confirmation

    while true; do
        printf "\n" >&2
        read -s -p "Provide a secure password $for_reason (min $required_length characters): " password
        printf "\n" >&2
        password_length=${#password}
        if [[ $password_length -ge $required_length ]]; then
            read -s -p "Confirm your password: " password_confirmation
            printf "\n" >&2
            
            if [[ $password == $password_confirmation ]]; then
                printf "Your password has been accepted.\n" >&2
                break
            else
                printf "The passwords you entered do not match. Please try again.\n" >&2
            fi
        else
            printf "Your password is too short!" >&2
        fi
    done
}

prompt_for_confirmed_text_input() {
    local input_prompt=$1
    local confirmation_prompt=$2
    local input
    local confirmation

    while true; do
        printf "\n" >&2
        read -p "$input_prompt: " input
        read -p "$confirmation_prompt: " confirmation

        if [[ -z $input ]]; then
            printf "Nothing entered. Please try again.\n" >&2
        elif [[ $input == $confirmation ]]; then
            printf "$input"
            break
        else
            printf "First input and confirmation do not match. Please try again.\n" >&2
        fi
    done
}

get_email_for_django_admin() {
    local email="none@none"

    printf "\n\nProvide an IoTree42 admin email address now or set it later in the file /etc/iotree/config.json\n" >&2
    while true; do
        read -p "Do you want to enter it now? (y/n): " answer

        case "$answer" in
            [Yy])
                # No regex testing for a valid email address was implemented due to susceptibility to errors.
                email=$(prompt_for_confirmed_text_input \
                    "Enter an email address for your IoTree42 user 'admin'" \
                    "Confirm your email address")
                break ;;
            [Nn])
                break ;;
            *)
                printf "\nInvalid input. Please enter 'Y' or 'N'.\n" >&2 ;;
        esac
    done
    printf "$email"
}

prompt_for_reset_email_credentials() {
    local reset_email="none"
    local reset_email_password="none"

    printf "\nProvide an email address for the password reset function now or set it later in the file /etc/iotree/config.json\n" >&2
    while true; do
        read -p "Do you want to enter it now? (y/n): " answer

        case "$answer" in
            [Yy])
                reset_email=$(prompt_for_confirmed_text_input \
                    "Enter the password reset email address" \
                    "Confirm the password reset email address")
                printf "Provide the password associated with the password reset email: "
                reset_email_password=$(prompt_for_password_of_length 1 "for the password reset email")
                break ;;
            [Nn])
                break ;;
            *)
                printf "Invalid input. Please enter 'Y' or 'N'." ;;
        esac
    done
    printf "%s %s" "$reset_email" "$reset_email_password"
}

get_ip_address() {
    local ip_address
    # Extract the first IP address of the running network interface
    ip_address="$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')"
    printf "$ip_address"
}

prompt_for_domain_name() {
    local installation_scheme=$1 
    local domain_name
    if [[ $installation_scheme = "public (https support)" ]]; then
        read -p "Enter the server domain name (e.g. example.com), if available. [Default: '$(hostname)']: " domain_name
    else
        domain_name=$(hostname)
    fi
    printf "$domain_name"
}

install_basic_packages() {
    : # install apt necessary packages --> Funct.-Name ggf. anpassen
}

do_install() {
    local installation_scheme
    local linux_username
    local iotree_admin_password
    local django_admin_email
    local reset_email_and_password
    local reset_email
    local reset_email_password
    local ip_address
    local domain_name

    print_logo_header

# Checks if system is prepared for installation
    is_supported_cpu_architecture || exit $FAILURE

    printf "\nTo make sure your system is up to date, run 'sudo apt update' and 'sudo apt upgrade' before setup.\n"
    confirm_proceed "Do you want to proceed? Otherwise please update, upgrade and reboot and come back." || exit $FAILURE

    is_running_with_sudo || exit $FAILURE

    installation_scheme=$(parse_installation_scheme "$@") || exit $FAILURE
    printf "\nThis will install Iotree42 with server installation scheme: $installation_scheme.\n"
    confirm_proceed "Do you want to proceed?" || exit $FAILURE


# Get configuration data from user
    linux_username=$(prompt_for_linux_username) || exit $FAILURE
    iotree_admin_password=$(prompt_for_password_of_length 1 "for your IoTree42 'admin' user")  # 12!!
    django_admin_email=$(get_email_for_django_admin)
    reset_email_and_password=($(prompt_for_reset_email_credentials))
    reset_email=${reset_email_and_password[0]}
    reset_email_password=${reset_email_and_password[1]}
    ip_address=$(get_ip_address)
    domain_name=$(prompt_for_domain_name installation_scheme)


# Update and install software
    printf "\nStarting installation of IoTree42 for user '$linux_username'. Please do not interrupt!\n" >&2
    confirm_proceed "Do you want to proceed?"
    printf "\nInstalling $installation_scheme\n" >&2

    # Update package lists
    sudo apt update

    # Install Python-related packages
    sudo apt install -y python3-pip python3-venv

    # Install neccessary libraries and other software
    apt install -y curl inotify-tools zip adduser git 
    apt install -y libopenjp2-7 libtiff5 libfontconfig1 

    if [[ $installation_scheme == "public (https support)" ]]; then  # besser doch $public = true ?
        printf "public scheme packages installation...\n" >&2
        apt -y install ufw
        apt install fail2ban
        apt install certbot python3-certbot-nginx
    fi

# Install main components of IoTree42
    apt install nginx
    # TODO node + npm ?
    apt install mosquitto mosquitto-clients
    # TODO Docker falls nötig

    # install with specific version:
    # Grafana (https://grafana.com/grafana/download?platform=linux&edition=oss)
    wget https://dl.grafana.com/oss/release/grafana_9.5.2_amd64.deb
    dpkg -i grafana_9.5.2_amd64.deb

    # InfluxDB (https://docs.influxdata.com/influxdb/v2.7/install/?t=Linux)
    wget https://dl.influxdata.com/influxdb/releases/influxdb2-2.7.0-amd64.deb
    dpkg -i influxdb2-2.7.0-amd64.deb

    # TODO nodered / flowforge

    # TODO Copy Django files, create venvs and install requirements (u.a. django-oauth-toolkit) oder erst bei config?
        # hier mock-ordner

    # TODO start/restart/status check: mosquitto, grafana-server, influxdb, ...
    systemctl start mosquitto
    service influxdb start
    # service influxdb status
        # Folgende Ausgabe erwartet:
        # influxdb.service - InfluxDB is an open-source, distributed, time series database
        # Loaded: loaded (/lib/systemd/system/influxdb.service; enabled; vendor preset: enable>
        # Active: active (running)


    ### TODO Make configurations ###
    # Certbot: https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-debian-11
    # setupt/generate user, pws, keys etc for:
    # config.json, mqttodb, grafana. influxdb, gunicorn, mosquitto, nginx-nossl/ssl, reload.sh, nodered
    # create temporary files of config-templates
    # write into temporary files 
    # copy all temporary files to destination (/etc/...)
    # start/restart above services
    # change file permissions
    # build gateway.zip file
    # install Python requirements into venvs (mit spezifischer Version?)
    # create Django admin 
    # crontabs?
    # set file permissions!


    ### TODO Final Confirmation Output to User ###
    printf "\nAll entries above can be changed later in the file /etc/iotree/config.json\n" >&2
    # Endpunkte (Dienste) mit ports
    # Hinweis auf config.json
    # You can delete ... (if not auto delete)
    # (if anything went wrong, user should be able to redo install or to fully remove all files
    # ask user to reboot

    if [[ $installation_scheme == "public (https support)" ]]; then  # besser doch $public = true ?
        printf "--> The server can be reached at: https://$domain_name/ \n" >&2 
    else
        printf "--> The server can be reached at: http://$ip_address/ \n" >&2
    fi
    
}

do_install "$@"
printf "\n!!!!!!!!!!!!!!!!!!!!!!!!!!! END !!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"  # line is just for debugging
# wrapped up in a function so that for some protection against only getting 
# half the file during "curl | sh"
