#!/bin/bash

rlwrap monero-wallet-cli --wallet-file wallet_m --password "" --testnet --trusted-daemon --daemon-address localhost:17566  --log-file wallet_miner.log stop_mining

