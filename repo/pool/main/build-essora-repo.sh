#!/bin/bash
# build-essora-repo.sh
# Genera el repositorio APT de Essora Linux
# Lee los .deb de pool/main/, genera índices y firma con GPG
# Copyright (C) 2025 josejp2424 — GPL-3.0
#
# Uso: sudo bash build-essora-repo.sh
# Requisitos: dpkg-dev, gpg, gzip
# git config --global user.name "josejp2424"
# git config --global user.email "josejp2424@gmail.com"
# git config --global --list
set -euo pipefail

GPG_KEY_ID="86C03ACBC5FD1162"
REPO_NAME="essora"
COMPONENT="main"
ARCH="amd64"
ORIGIN="Essora Linux"
LABEL="Essora"
DESCRIPTION="Official Essora Linux package repository"

REPO_DIR="/root/essora-linux/repo"
POOL_DIR="$REPO_DIR/pool/$COMPONENT"
DISTS_DIR="$REPO_DIR/dists/$REPO_NAME/$COMPONENT/binary-$ARCH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}== Essora Linux — APT Repo Builder ==${NC}"
echo ""

for cmd in gpg dpkg-scanpackages gzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: '$cmd' no está instalado.${NC}"
    exit 1
  fi
done

mkdir -p "$POOL_DIR" "$DISTS_DIR"

if [[ -z "$(ls "$POOL_DIR"/*.deb 2>/dev/null)" ]]; then
  echo -e "${RED}ERROR: No hay .deb en $POOL_DIR${NC}"
  exit 1
fi

total=$(ls "$POOL_DIR"/*.deb | wc -l)
echo -e "   ${GREEN}✓ $total paquetes en pool/main/${NC}"
echo ""

echo -e "${YELLOW}► Generando índice de paquetes...${NC}"
cd "$REPO_DIR"
dpkg-scanpackages --arch "$ARCH" "pool/$COMPONENT" > "dists/$REPO_NAME/$COMPONENT/binary-$ARCH/Packages"
gzip -9 -k -f "dists/$REPO_NAME/$COMPONENT/binary-$ARCH/Packages"
echo -e "   ${GREEN}✓ Packages y Packages.gz generados${NC}"

echo -e "${YELLOW}► Generando Release...${NC}"

TODAY=$(date -u -R)
PACKAGES_FILE="dists/$REPO_NAME/$COMPONENT/binary-$ARCH/Packages"
PACKAGESGZ_FILE="dists/$REPO_NAME/$COMPONENT/binary-$ARCH/Packages.gz"

PKG_SIZE=$(wc -c < "$PACKAGES_FILE")
PKGGZ_SIZE=$(wc -c < "$PACKAGESGZ_FILE")
PKG_MD5=$(md5sum "$PACKAGES_FILE" | cut -d' ' -f1)
PKGGZ_MD5=$(md5sum "$PACKAGESGZ_FILE" | cut -d' ' -f1)
PKG_SHA256=$(sha256sum "$PACKAGES_FILE" | cut -d' ' -f1)
PKGGZ_SHA256=$(sha256sum "$PACKAGESGZ_FILE" | cut -d' ' -f1)
PKG_SHA512=$(sha512sum "$PACKAGES_FILE" | cut -d' ' -f1)
PKGGZ_SHA512=$(sha512sum "$PACKAGESGZ_FILE" | cut -d' ' -f1)

cat > "dists/$REPO_NAME/Release" <<EOF
Origin: $ORIGIN
Label: $LABEL
Suite: $REPO_NAME
Codename: $REPO_NAME
Version: 1.0
Architectures: $ARCH
Components: $COMPONENT
Description: $DESCRIPTION
Date: $TODAY
MD5Sum:
 $PKG_MD5 $PKG_SIZE $COMPONENT/binary-$ARCH/Packages
 $PKGGZ_MD5 $PKGGZ_SIZE $COMPONENT/binary-$ARCH/Packages.gz
SHA256:
 $PKG_SHA256 $PKG_SIZE $COMPONENT/binary-$ARCH/Packages
 $PKGGZ_SHA256 $PKGGZ_SIZE $COMPONENT/binary-$ARCH/Packages.gz
SHA512:
 $PKG_SHA512 $PKG_SIZE $COMPONENT/binary-$ARCH/Packages
 $PKGGZ_SHA512 $PKGGZ_SIZE $COMPONENT/binary-$ARCH/Packages.gz
EOF

echo -e "   ${GREEN}✓ Release generado${NC}"

echo -e "${YELLOW}► Firmando con GPG...${NC}"

gpg --default-key "$GPG_KEY_ID" --yes --clearsign --armor \
    -o "dists/$REPO_NAME/InRelease" "dists/$REPO_NAME/Release"

gpg --default-key "$GPG_KEY_ID" --yes --detach-sign --armor \
    -o "dists/$REPO_NAME/Release.gpg" "dists/$REPO_NAME/Release"

echo -e "   ${GREEN}✓ Firmado${NC}"

echo -e "${YELLOW}► Exportando clave pública...${NC}"
gpg --armor --export "$GPG_KEY_ID" > "$REPO_DIR/essora.gpg"
echo -e "   ${GREEN}✓ repo/essora.gpg${NC}"

echo ""
echo -e "${GREEN}✔ Listo — $total paquetes procesados${NC}"
echo ""
echo "  cd /root/essora-linux"
echo "  git add repo/"
echo "  git commit -m 'update packages'"
echo "  git push"
