#!/bin/bash
if [[ -f "/usr/lib/multitoolbox/flux_common.sh" ]]; then
  source "/usr/lib/multitoolbox/flux_common.sh"
else
  source /dev/stdin <<< "$(curl -s "https://raw.githubusercontent.com/RunOnFlux/fluxnode-multitool/$ROOT_BRANCH/flux_common.sh")"
fi

function upnp_disable() {
  if [[ ! -f $FLUXOS_PATH/config/userconfig.js ]]; then
    echo -e "${WORNING} ${CYAN}Missing FluxOS configuration file - install/re-install Flux Node...${NC}" 
    echo -e ""
    exit
  fi
  
  if [[ -f $FLUX_BENCH_PATH/fluxbench.conf ]]; then
    if [[ $(grep -e "fluxport" $FLUX_BENCH_PATH/fluxbench.conf) != "" ]]; then
      echo -e ""
      echo -e "${ARROW} ${YELLOW}Removing FluxOS UPnP configuration.....${NC}"
      if [[ -n $FLUXOS_VERSION ]]; then
        SUDO_CMD="sudo"
      fi
      $SUDO_CMD sed -i "/$(grep -e "fluxport" $FLUX_BENCH_PATH/fluxbench.conf)/d" $FLUX_BENCH_PATH/fluxbench.conf > /dev/null 2>&1
    else
      echo -e "${ARROW} ${CYAN}UPnP Mode is already disabled...${NC}"
      echo -e ""
      exit
    fi
  else
    echo -e "${ARROW} ${CYAN}UPnP Mode is already disabled...${NC}"
    echo -e ""
    exit
  fi
  if [[ $(cat $FLUXOS_PATH/config/userconfig.js | grep 'apiport' | wc -l) == "1" ]]; then
    RemoveLine "routerIP"
    RemoveLine "apiport"
  fi
  echo -e "${ARROW} ${CYAN}Restarting FluxOS and Benchmark.....${NC}"
  echo -e ""
  if [[ -z $FLUXOS_VERSION ]]; then
    sudo systemctl restart zelcash  > /dev/null 2>&1
    pm2 restart flux  > /dev/null 2>&1
  else
    sudo systemctl restart fluxbenchd  > /dev/null 2>&1
    sudo systemctl restart fluxos  > /dev/null 2>&1
  fi
  sleep 10
}

CHOICE=$(
whiptail --title "UPnP Configuration" --menu "Make your choice" 16 30 9 \
"1)" "Enable UPnP Mode"   \
"2)" "Disable UPnP Mode"  3>&2 2>&1 1>&3
)
case $CHOICE in
  "1)")   
  upnp_enable
  ;;
  "2)")   
  upnp_disable
  ;;
esac

