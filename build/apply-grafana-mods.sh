#!/bin/bash

echo "Applying mods to Grafana configuration ..."

cd /usr/share/grafana/conf

# Set default theme to light theme to better match Stratos
sed -i.bak "s/= dark/= light/g" defaults.ini

# Disable gravatar
sed -i.bak "s/disable_gravatar = false/disable_gravatar = true/g" defaults.ini

# Allow embedding
sed -i.bak "s/allow_embedding = false/allow_embedding = true/g" defaults.ini

rm -rf *.bak

# Install plugins

echo "Installing plugins"

set -e
grafana-cli plugins install grafana-clock-panel
grafana-cli plugins install jdbranham-diagram-panel
grafana-cli plugins install mtanda-histogram-panel
grafana-cli plugins install grafana-piechart-panel
grafana-cli plugins install vonage-status-panel
grafana-cli plugins install grafana-worldmap-panel

echo "Applying mods to Grafana configuration DONE"
