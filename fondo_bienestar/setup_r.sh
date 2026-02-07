#!/bin/bash
# Setup script for R Shiny app - Fondo Bienestar
# Run with: bash setup_r.sh

set -e

echo "=== Installing R and dependencies for Fondo Bienestar ==="

# Update package list
echo "[1/6] Updating apt..."
sudo apt update

# Install prerequisites
echo "[2/6] Installing prerequisites..."
sudo apt install -y software-properties-common dirmngr wget

# Add CRAN GPG key
echo "[3/6] Adding CRAN repository key..."
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc > /dev/null

# Add CRAN repository
echo "[4/6] Adding CRAN repository..."
sudo add-apt-repository -y "deb https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/"
sudo apt update

# Install R
echo "[5/6] Installing R..."
sudo apt install -y r-base r-base-dev

# Install system dependencies for R packages
echo "[6/6] Installing system libraries..."
sudo apt install -y libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev

echo ""
echo "=== R installation complete! ==="
echo ""
echo "Now installing R packages (this may take a few minutes)..."
R -e "install.packages(c('shiny', 'bslib', 'shinyjs', 'plotly', 'dplyr', 'scales'), repos='https://cloud.r-project.org')"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "To run the app:"
echo "  cd /home/andre/seguridad_social/fondo_bienestar"
echo "  R -e \"shiny::runApp(host='0.0.0.0', port=3838)\""
echo ""
echo "Then open http://localhost:3838 in your browser"
