#!/bin/bash

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

function create_timer() {
  read -p "Enter service name (with or without .service): " INPUT_NAME
  SERVICE_NAME=$(echo "$INPUT_NAME" | sed 's/\.service$//')
  RESTART_SERVICE_NAME="${SERVICE_NAME}-restart"
  TIMER_NAME="${SERVICE_NAME}.timer"

  read -p "Restart every how many hours? (e.g. 1, 3, 6): " INTERVAL

  echo -e "${GREEN}Creating restart service...${RESET}"

  cat <<EOF | sudo tee /etc/systemd/system/${RESTART_SERVICE_NAME}.service > /dev/null
[Unit]
Description=Restart ${SERVICE_NAME}.service

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart ${SERVICE_NAME}.service
EOF

  echo -e "${GREEN}Creating timer (every ${INTERVAL} hour(s))...${RESET}"

  cat <<EOF | sudo tee /etc/systemd/system/${TIMER_NAME} > /dev/null
[Unit]
Description=Restart ${SERVICE_NAME}.service every ${INTERVAL} hour(s)

[Timer]
OnCalendar=*-*-* 00/${INTERVAL}:00:00
Persistent=true
Unit=${RESTART_SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable --now ${TIMER_NAME}

  echo -e "${YELLOW}Timer created and enabled:${RESET}"
  echo -e "  ⏱️  ${TIMER_NAME}"
}

function get_custom_restart_timers() {
  mapfile -t TIMERS < <(ls /etc/systemd/system/*.timer 2>/dev/null | grep -oP '[^/]+(?=\.timer)' | while read -r name; do
    if [[ -f "/etc/systemd/system/${name}-restart.service" ]]; then
      echo "$name"
    fi
  done)
}

function list_timers_array() {
  get_custom_restart_timers

  if [ ${#TIMERS[@]} -eq 0 ]; then
    echo -e "${RED}No restart timers found.${RESET}"
    return 1
  fi

  echo -e "${GREEN}Restart timers created by this script:${RESET}"
  for i in "${!TIMERS[@]}"; do
    echo "[$i] ${TIMERS[$i]}"
  done
  return 0
}

function delete_timer_by_index() {
  if ! list_timers_array; then return; fi

  echo -ne "${YELLOW}Enter the number of the timer you want to delete: ${RESET}"
  read INDEX

  if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ "$INDEX" -ge "${#TIMERS[@]}" ]; then
    echo -e "${RED}Invalid index.${RESET}"
    return
  fi

  NAME="${TIMERS[$INDEX]}"
  TIMER_FILE="${NAME}.timer"
  RESTART_SERVICE_FILE="${NAME}-restart.service"

  echo -e "${RED}Disabling and removing ${TIMER_FILE} and ${RESTART_SERVICE_FILE}...${RESET}"
  sudo systemctl disable --now "$TIMER_FILE"
  sudo rm -f "/etc/systemd/system/$TIMER_FILE"
  sudo rm -f "/etc/systemd/system/$RESTART_SERVICE_FILE"
  sudo systemctl daemon-reload

  echo -e "${GREEN}Deleted successfully.${RESET}"
}

function main_menu() {
  while true; do
    echo -e "\n${YELLOW}Restart Timer Manager${RESET}"
    echo "1) Create a new restart timer"
    echo "2) List restart timers"
    echo "3) Delete a restart timer"
    echo "0) Exit"
    echo -n "Select an option: "
    read OPTION

    case $OPTION in
      1) create_timer ;;
      2) list_timers_array ;;
      3) delete_timer_by_index ;;
      0) echo "Bye!"; break ;;
      *) echo -e "${RED}Invalid option.${RESET}" ;;
    esac
  done
}

main_menu
