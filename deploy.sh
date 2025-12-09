#!/bin/bash

# testing.mq5をデプロイ
cp ~/my_log/testing.mq5 "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/my_sons/testing.mq5"

# alpha.mq5をデプロイ
cp ~/my_log/alpha.mq5 "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/my_sons/alpha.mq5"

# Includeフォルダ配下のファイルをデプロイ
cp ~/my_log/Include/* "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Include/MyCode/"

# Indicatorsフォルダ配下のファイルをデプロイ
cp ~/my_log/Indicators/* "${HOME}/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Indicators/MyCode/"
