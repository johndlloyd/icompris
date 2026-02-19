#!/usr/bin/env bash
# Build an arm64 macOS GCompris app bundle and DMG for internal distribution.
#
# SPDX-FileCopyrightText: 2026
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build-macos-arm64-release"
DIST_DIR="${ROOT_DIR}/dist"
DMG_STAGE_DIR="${ROOT_DIR}/dmg-stage"
QT_ROOT="${QT_ROOT:-}"
ALLOW_HOMEBREW_QT="${ALLOW_HOMEBREW_QT:-0}"
WITH_TRANSLATIONS="${WITH_TRANSLATIONS:-0}"
BUILD_SERVER="${BUILD_SERVER:-0}"
RUN_SELF_CHECKS="${RUN_SELF_CHECKS:-1}"

usage() {
  cat <<'EOF'
Usage: tools/macos_build_dmg.sh [--qt-root /path/to/Qt/6.x.x/macos] [--with-translations] [--with-server]

Environment overrides:
  QT_ROOT=/path/to/Qt/6.x.x/macos   Same as --qt-root
  ALLOW_HOMEBREW_QT=1               Allow Homebrew Qt (known to be unstable with macdeployqt)
  WITH_TRANSLATIONS=1               Build translations (requires gettext msgfmt)
  BUILD_SERVER=1                    Build teacher server too
  RUN_SELF_CHECKS=0                 Disable post-build app verification checks

Examples:
  tools/macos_build_dmg.sh
  tools/macos_build_dmg.sh --qt-root "$HOME/Qt/6.10.0/macos"
EOF
}

log() {
  printf '[macos-build] %s\n' "$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf 'ERROR: missing required command: %s\n' "${cmd}" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --qt-root)
        QT_ROOT="$2"
        shift 2
        ;;
      --with-translations)
        WITH_TRANSLATIONS=1
        shift
        ;;
      --with-server)
        BUILD_SERVER=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'ERROR: unknown option: %s\n' "$1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

find_qt_root() {
  if [[ -n "${QT_ROOT}" ]]; then
    return
  fi

  # Prefer the exact Homebrew Cellar Qt version known to work in this setup.
  if [[ -d "/opt/homebrew/Cellar/qt/6.10.2/lib/cmake/Qt6" ]]; then
    QT_ROOT="/opt/homebrew/Cellar/qt/6.10.2"
    ALLOW_HOMEBREW_QT=1
    return
  fi

  local candidates=()
  while IFS= read -r path; do
    candidates+=("${path}")
  done < <(find "${HOME}/Qt" -maxdepth 3 -type d -path "*/macos" 2>/dev/null | sort -V)

  if [[ ${#candidates[@]} -gt 0 ]]; then
    QT_ROOT="${candidates[-1]}"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    local brew_qt_prefix
    brew_qt_prefix="$(brew --prefix --installed qt 2>/dev/null || true)"
    if [[ -n "${brew_qt_prefix}" ]] && [[ -d "${brew_qt_prefix}/lib/cmake/Qt6" ]]; then
      QT_ROOT="${brew_qt_prefix}"
      return
    fi
  fi

  printf 'ERROR: Qt macOS kit not found.\n' >&2
  printf 'Install Qt 6.5+ via Qt Installer (~/%s) or Homebrew (`brew install qt`).\n' "Qt/<version>/macos" >&2
  printf 'Then rerun, or pass --qt-root explicitly.\n' >&2
  exit 1
}

self_check_app() {
  local app="$1"
  local main_bin="${app}/Contents/MacOS/gcompris-qt"

  log "Running self-checks on staged app"
  codesign -vvv --deep --strict "${app}" >/dev/null

  # Ensure we do not leave absolute Homebrew references in Mach-O load commands.
  local leaks=0
  while IFS= read -r -d '' f; do
    if otool -L "${f}" 2>/dev/null | awk '/^\t\/opt\/homebrew\// {exit 0} END {exit 1}'; then
      leaks=1
      printf 'ERROR: absolute Homebrew dependency remains in %s\n' "${f}" >&2
    fi
  done < <(find "${app}/Contents" -type f \( -name '*.dylib' -o -name '*.so' -o -perm -111 \) -print0)

  if [[ "${leaks}" -ne 0 ]]; then
    printf 'ERROR: self-check failed due to unresolved absolute dependencies\n' >&2
    exit 1
  fi

  if [[ -x "${main_bin}" ]]; then
    if ! "${main_bin}" --help >/dev/null 2>&1; then
      printf 'WARNING: app smoke test failed (non-fatal): %s --help\n' "${main_bin}" >&2
    fi
  fi
}

ensure_box2d_source() {
  local box2d_dir="${ROOT_DIR}/external/qml-box2d"
  if [[ -d "${box2d_dir}" ]] && [[ -n "$(ls -A "${box2d_dir}" 2>/dev/null)" ]]; then
    return
  fi

  log "qml-box2d source missing; downloading to external/qml-box2d"
  rm -rf "${box2d_dir}"
  git clone --depth 1 https://github.com/qml-box2d/qml-box2d.git "${box2d_dir}"
}

main() {
  parse_args "$@"

  require_cmd xcodebuild
  require_cmd cmake
  require_cmd hdiutil
  require_cmd git

  find_qt_root
  local qt_cmake_dir="${QT_ROOT}/lib/cmake"
  if [[ ! -d "${qt_cmake_dir}" ]]; then
    printf 'ERROR: Qt CMake directory not found: %s\n' "${qt_cmake_dir}" >&2
    exit 1
  fi
  if [[ "${QT_ROOT}" == /opt/homebrew/* ]] && [[ "${ALLOW_HOMEBREW_QT}" != "1" ]]; then
    printf 'ERROR: Homebrew Qt at %s is not supported by this script because macdeployqt fails on Homebrew-symlinked frameworks.\n' "${QT_ROOT}" >&2
    printf 'Use Qt online installer (example: ~/Qt/6.10.0/macos), then rerun with --qt-root.\n' >&2
    printf 'If you still want to try Homebrew Qt anyway, rerun with ALLOW_HOMEBREW_QT=1.\n' >&2
    exit 1
  fi
  local macdeployqt="${QT_ROOT}/bin/macdeployqt"
  if [[ ! -x "${macdeployqt}" ]]; then
    printf 'ERROR: macdeployqt not found at %s\n' "${macdeployqt}" >&2
    printf 'Install full Qt tools, then rerun.\n' >&2
    exit 1
  fi

  local generator_opts=()
  if command -v ninja >/dev/null 2>&1; then
    generator_opts=(-G Ninja)
  fi

  ensure_box2d_source

  mkdir -p "${BUILD_DIR}" "${DIST_DIR}"
  rm -rf "${DMG_STAGE_DIR}"
  mkdir -p "${DMG_STAGE_DIR}"

  local skip_translations=ON
  if [[ "${WITH_TRANSLATIONS}" == "1" ]]; then
    skip_translations=OFF
  fi

  local build_server=OFF
  if [[ "${BUILD_SERVER}" == "1" ]]; then
    build_server=ON
  fi

  log "Using Qt root: ${QT_ROOT}"
  log "Configuring build directory: ${BUILD_DIR}"

  cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" "${generator_opts[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="${qt_cmake_dir}" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DBUILD_STANDALONE=OFF \
    -DQML_BOX2D_MODULE=submodule \
    -DSKIP_TRANSLATIONS="${skip_translations}" \
    -DBUILD_SERVER="${build_server}" \
    -DPACKAGE_GCOMPRIS=OFF \
    -DPACKAGE_SERVER=OFF

  log "Building app bundle target"
  cmake --build "${BUILD_DIR}" --parallel --target gcompris-qt

  local app_path="${BUILD_DIR}/bin/gcompris-qt.app"
  if [[ ! -d "${app_path}" ]]; then
    printf 'ERROR: app bundle not found: %s\n' "${app_path}" >&2
    exit 1
  fi

  chmod -R u+w "${app_path}"

  log "Deploying Qt frameworks/plugins with macdeployqt"
  local deploy_args=("${macdeployqt}" "${app_path}" -always-overwrite -qmldir="${ROOT_DIR}/src")
  if command -v brew >/dev/null 2>&1; then
    # Homebrew splits Qt modules into multiple kegs. Add all available qt*/lib
    # paths so macdeployqt can resolve transitive framework dependencies.
    local qt_lib_dirs=()
    while IFS= read -r d; do
      qt_lib_dirs+=("${d}")
    done < <(find /opt/homebrew/opt -maxdepth 2 -type d -path "/opt/homebrew/opt/qt*/lib" 2>/dev/null | sort -u)

    local libdir
    for libdir in "${qt_lib_dirs[@]-}"; do
      deploy_args+=("-libpath=${libdir}")
    done
  fi
  set +e
  "${deploy_args[@]}"
  local macdeploy_status=$?
  set -e
  if [[ ${macdeploy_status} -ne 0 ]]; then
    log "macdeployqt returned ${macdeploy_status}; applying manual install-name fixups and continuing"
  fi

  # Homebrew builds can leave absolute references (for example brotli).
  # Rewrite any /opt/homebrew dylib references that are also present in
  # the app Frameworks folder.
  local frameworks_dir="${app_path}/Contents/Frameworks"
  while IFS= read -r -d '' bin; do
    while IFS= read -r dep; do
      local dep_name
      dep_name="$(basename "${dep}")"
      local bundled_dep="${frameworks_dir}/${dep_name}"
      if [[ -f "${bundled_dep}" ]]; then
        chmod u+w "${bin}" "${bundled_dep}" 2>/dev/null || true
        install_name_tool -change "${dep}" "@executable_path/../Frameworks/${dep_name}" "${bin}" 2>/dev/null || true
      fi
    done < <(otool -L "${bin}" 2>/dev/null | awk '/^\t\/opt\/homebrew\// {print $1}')
  done < <(find "${app_path}/Contents" -type f \( -name '*.dylib' -o -name '*.so' -o -perm -111 \) -print0)

  cp -R "${app_path}" "${DMG_STAGE_DIR}/"
  local staged_app="${DMG_STAGE_DIR}/gcompris-qt.app"
  chmod -R u+w "${staged_app}"
  log "Ad-hoc signing staged app for internal distribution"
  codesign --force --sign - --timestamp=none --deep "${staged_app}"
  codesign -vvv --deep --strict "${staged_app}" >/dev/null
  if [[ "${RUN_SELF_CHECKS}" == "1" ]]; then
    self_check_app "${staged_app}"
  fi

  ln -s /Applications "${DMG_STAGE_DIR}/Applications"

  local version
  version="$(sed -n -E 's/set\(GCOMPRIS_MAJOR_VERSION ([0-9]+)\).*/\1/p' "${ROOT_DIR}/CMakeLists.txt")"
  local minor
  minor="$(sed -n -E 's/set\(GCOMPRIS_MINOR_VERSION ([0-9]+)\).*/\1/p' "${ROOT_DIR}/CMakeLists.txt")"
  local out_dmg="${DIST_DIR}/gcompris-qt-${version}.${minor}-macos-arm64-internal.dmg"
  rm -f "${out_dmg}"

  log "Creating DMG"
  hdiutil create -volname "GCompris" -srcfolder "${DMG_STAGE_DIR}" -ov -format UDZO "${out_dmg}" >/dev/null

  log "DMG ready: ${out_dmg}"
  log "Install by opening the DMG and dragging gcompris-qt.app to /Applications."
  log "For internal use, expect a Gatekeeper warning on first run because this build is unsigned."
}

main "$@"
