from setup_utils import run_bash, get_random_string, get_conf_path

MOSQUITTO_INSTALL_LOG_FILE_NAME = "install_mosquitto.log"

def install_mosquitto(setup_dir, setup_scheme):
    # Generate random credentials
    dynsec_admin_name = get_random_string(10)
    dynsec_admin_pass = get_random_string(50)
    dj_mqtt_controle_user = get_random_string(10)
    dj_mqtt_controle_pw = get_random_string(50)
    mqtt_in_to_db_user = get_random_string(10)
    mqtt_in_to_db_pw = get_random_string(50)
    mqtt_out_to_db_user = get_random_string(10)
    mqtt_out_to_db_pw = get_random_string(50)

    commands = [
        "apt install -y mosquitto mosquitto-clients",
        # Assuming dynsec plugin is installed in a standard location
        ("echo 'include_dir /etc/mosquitto/conf.d' >> "
            "/etc/mosquitto/mosquitto.conf"),
        # Initialize and build dynamic-security.json file
        ("mosquitto_ctrl dynsec init /var/lib/mosquitto/dynamic-security.json "
            f"{dynsec_admin_name} {dynsec_admin_pass}"),
        # Set file permissions:
        "chown mosquitto:mosquitto /var/lib/mosquitto/dynamic-security.json",
        "chmod 700 /var/lib/mosquitto/dynamic-security.json",
    ]

    for command in commands:
        run_bash(command, MOSQUITTO_INSTALL_LOG_FILE_NAME)

    # Add Clients and Roles to dynamic-security.json using a prepared script
    config_path = get_conf_path()
    dynsec_command_script = f"{config_path}/tmp.mosquitto-dynsec-commands.sh"
    dynsec_commands = (f"bash {dynsec_command_script} " 
                      f"{dj_mqtt_controle_user} {dj_mqtt_controle_pw} " 
                      f"{mqtt_in_to_db_user} {mqtt_in_to_db_pw} " 
                      f"{mqtt_out_to_db_user} {mqtt_out_to_db_pw}"
    )
    run_bash(dynsec_commands, MOSQUITTO_INSTALL_LOG_FILE_NAME)

    # Configure Mosquitto for TLS or non-TLS
    conf_script = ("tmp.mosquitto-tls.conf.sh" if setup_scheme != "NO_TLS" \
        else "tmp.mosquitto-no-tls.conf.sh")
    
    conf_command = (f"bash {config_path}/{conf_script} > "
                    f"{setup_dir}/setup_files/tmp/mosquitto.conf")
    run_bash(conf_command, MOSQUITTO_INSTALL_LOG_FILE_NAME)

    run_bash(f"cp {setup_dir}/tmp/mosquitto.conf /etc/mosquitto/conf.d/", 
        MOSQUITTO_INSTALL_LOG_FILE_NAME
    )

    # Restart Mosquitto to apply configurations
    run_bash("systemctl restart mosquitto.service", MOSQUITTO_INSTALL_LOG_FILE_NAME)

    config_data = {
        "MOSQUITTO_HOST": "localhost",
        "MOSQUITTO_PORT": 1883,
        "DYNSEC_TOPIC": "$CONTROL/dynamic-security/v1",
        "DYNSEC_RESPONSE_TOPIC": "$CONTROL/dynamic-security/v1/response",
        "DYNSEC_ADMIN": dynsec_admin_name,
        "DYNSEC_ADMIN_PASS": dynsec_admin_pass,
        "DJ_MQTT_CONTROLE_USER": dj_mqtt_controle_user,
        "DJ_MQTT_CONTROLE_PW": dj_mqtt_controle_pw,
        "MQTT_IN_TO_DB_USER": mqtt_in_to_db_user,
        "MQTT_IN_TO_DB_PW": mqtt_in_to_db_pw,
        "MQTT_OUT_TO_DB_USER": mqtt_out_to_db_user,
        "MQTT_OUT_TO_DB_PW": mqtt_out_to_db_pw
    }

    return config_data
