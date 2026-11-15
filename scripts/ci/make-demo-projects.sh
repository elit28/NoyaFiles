#!/usr/bin/env bash
# Creates a folder of code projects, most of them Git repositories, for the developer tools screenshots.
# Usage: scripts/ci/make-demo-projects.sh <folder>
set -euo pipefail

root="${1:?usage: make-demo-projects.sh <folder>}"
mkdir -p "$root"
cd "$root"

export GIT_AUTHOR_NAME="NOYA Files CI" GIT_AUTHOR_EMAIL="ci@noya360.invalid"
export GIT_COMMITTER_NAME="NOYA Files CI" GIT_COMMITTER_EMAIL="ci@noya360.invalid"

# Writes a file of the given size in kilobytes.
file() { mkdir -p "$(dirname "$1")"; head -c "$(( $2 * 1024 ))" /dev/zero > "$1"; }

# Commits everything in a repository, dated a number of seconds ago.
commit() {
  local date="$(( $(date +%s) - $3 )) +0000"
  git -C "$1" add -A
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git -C "$1" commit -q -m "$2"
}

new_repo() {
  git init -q -b "$2" "$1"
  printf '.build/\nnode_modules/\nbuild/\nDerivedData/\n' > "$1/.gitignore"
}

# A Swift app, up to date.
new_repo noya-files main
printf '// swift-tools-version: 6.0\nimport PackageDescription\n' > noya-files/Package.swift
file noya-files/Sources/App/App.swift 40
commit noya-files "Ajouter l'assistant" 7200
git -C noya-files remote add origin https://github.com/noya360/noya-files.git
file noya-files/.build/debug/App 9000

# A website, with work in progress on a branch.
new_repo site-web main
printf '{ "name": "site-web", "private": true }\n' > site-web/package.json
printf '{ "compilerOptions": { "strict": true } }\n' > site-web/tsconfig.json
mkdir -p site-web/src/components
printf 'export function Hero() { return null }\n' > site-web/src/components/Hero.tsx
commit site-web "Première version" 172800
git -C site-web checkout -q -b feature/hero
printf '// Nouvelle bannière\n' >> site-web/src/components/Hero.tsx
commit site-web "Nouvelle bannière d'accueil" 86400
git -C site-web remote add origin git@github.com:noya360/site-web.git
printf '// Couleurs\n' >> site-web/src/components/Hero.tsx
printf '{ "name": "site-web", "private": true, "version": "1.1.0" }\n' > site-web/package.json
printf 'Idées pour la page d’accueil\n' > site-web/notes.txt
file site-web/node_modules/react/index.js 24000

# A mobile app, ahead of and behind its remote.
new_repo app-mobile develop
printf 'plugins { kotlin("android") }\n' > app-mobile/build.gradle.kts
file app-mobile/app/src/Main.kt 12
commit app-mobile "Écran de connexion" 864000
remotes="$root/.remotes"
mkdir -p "$remotes"
git init -q --bare "$remotes/app-mobile.git"
git -C app-mobile remote add origin "$remotes/app-mobile.git"
git -C app-mobile push -q -u origin develop
other="$(mktemp -d)/app-mobile"
git clone -q -b develop "$remotes/app-mobile.git" "$other"
printf 'Notes de version\n' > "$other/CHANGELOG.md"
commit "$other" "Notes de version" 600000
git -C "$other" push -q origin develop
printf '// Thème sombre\n' >> app-mobile/app/src/Main.kt
commit app-mobile "Thème sombre" 500000
printf '// Notifications\n' >> app-mobile/app/src/Main.kt
commit app-mobile "Notifications" 450000
git -C app-mobile fetch -q origin
file app-mobile/build/outputs/app.apk 14000

# A Go service, up to date.
new_repo api-facturation main
printf 'module noya360/api-facturation\n\ngo 1.23\n' > api-facturation/go.mod
file api-facturation/main.go 6
commit api-facturation "Export des factures en PDF" 1600000
git -C api-facturation remote add origin https://github.com/noya360/api-facturation.git

# Scripts that are not in a repository.
mkdir -p scripts
printf '#!/bin/sh\necho deploy\n' > scripts/deploy.sh
printf '#!/bin/sh\necho backup\n' > scripts/backup.sh
