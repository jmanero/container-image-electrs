#!/usr/bin/bash -ex

arguments=($ELECTRS_ARGS)

## Build electrs arguments from environment variables
arguments+=(--db-dir "${ELECTRS_DATA_DIR}")
arguments+=(--electrum-banner "${ELECTRS_BANNER}")
arguments+=(--electrum-rpc-addr "${ELECTRS_RPC_ADDR}")
arguments+=(--http-addr "${ELECTRS_HTTP_ADDR}")
arguments+=(--monitoring-addr "${ELECTRS_MONITORING_ADDR}")
arguments+=(--network "${ELECTRS_NETWORK}")
arguments+=(--daemon-rpc-addr "${BITCOIND_RPC_ADDR}")
arguments+=(--cookie "${BITCOIND_RPC_USER}:${BITCOIND_RPC_PASS}")
arguments+=(--daemon-dir "${BITCOIND_DIR}")

exec /usr/bin/electrs "${arguments[@]}"
