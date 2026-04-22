#!/bin/bash

# testing.mq5をデプロイ
cp ~/my_log/testing.mq5 "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/my_sons/testing.mq5"

# alpha.mq5をデプロイ
cp ~/my_log/alpha.mq5 "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/my_sons/alpha.mq5"

# Includeフォルダ配下のファイルをデプロイ
cp ~/my_log/Include/*.mqh "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Include/MyCode/" 2>/dev/null

# SabaiSystemフォルダをデプロイ
SABAI_DEST="${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Include/MyCode/SabaiSystem"
mkdir -p "${SABAI_DEST}/Drawing"
cp ~/my_log/Include/SabaiSystem/*.mqh "${SABAI_DEST}/"
cp ~/my_log/Include/SabaiSystem/Drawing/*.mqh "${SABAI_DEST}/Drawing/"

# Indicatorsフォルダ配下のファイルをデプロイ
cp ~/my_log/Indicators/* "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Indicators/MyCode/"

# Scriptsをデプロイ
SCRIPTS_DEST="${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Scripts/MyCode"
mkdir -p "${SCRIPTS_DEST}"
cp ~/my_log/delete_all_objects.mq5 "${SCRIPTS_DEST}/"
# cp ~/my_log/close_positions.mq5 "${SCRIPTS_DEST}/"
# cp ~/my_log/cancel_orders.mq5 "${SCRIPTS_DEST}/"
# cp ~/my_log/print_orders_and_positions.mq5 "${SCRIPTS_DEST}/"
