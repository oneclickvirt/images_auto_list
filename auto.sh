#!/usr/bin/env bash
set -euo pipefail

REPOS=(
    "oneclickvirt/lxc_amd64_images"
    "oneclickvirt/lxc_arm_images"
    "oneclickvirt/lxd_images"
    "oneclickvirt/incus_images"
    "oneclickvirt/docker"
    "oneclickvirt/pve_kvm_images"
    "oneclickvirt/kvm_images"
    "oneclickvirt/containerd"
    "oneclickvirt/podman"
)

RAW_LIST_SOURCES=(
    "https://raw.githubusercontent.com/ILLKX/Windows/master/README.md"
    "https://raw.githubusercontent.com/ILLKX/Windows-VirtIO/master/README.md"
    "https://raw.githubusercontent.com/oneclickvirt/pve/main/extra_scripts/configure_macos.sh"
    "https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_macos_images.sh"
)

MACOS_INSTALLER_REFS=(
    "https://github.com/oneclickvirt/macos/releases/download/images/high-sierra.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/mojave.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/catalina.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/big-sur.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/monterey.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/ventura.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/sonoma.iso.7z"
    "https://github.com/oneclickvirt/macos/releases/download/images/sequoia.iso.7z"
)

ANDROID_X86_DIRS=(
    "https://mirrors.tuna.tsinghua.edu.cn/osdn/android-x86/71931/"
)

BLISSOS_INSTALLER_REFS=(
    "https://sourceforge.net/projects/blissos-x86/files/Official/BlissOS15/Gapps/Generic/Bliss-v15.9.2-x86_64-OFFICIAL-gapps-20241012.iso/download"
)

API_ENDPOINTS=(
    "https://api.github.com"
    "https://githubapi.spiritlhl.workers.dev"
    "https://githubapi.spiritlhl.top"
)

OUTPUT_FILE="${OUTPUT_FILE:-images.txt}"
USER_AGENT="${USER_AGENT:-GitHub-Releases-Fetcher/1.0}"

EXCLUDE_PATTERNS=(
    "vagrant_2.3.8.dev-1_amd64.deb"
)

EXTRA_IMAGE_REFS=(
    "docker://spiritlhl/wds:10"
    "docker://spiritlhl/wds:2019"
    "docker://spiritlhl/wds:2022"
    "docker://redroid/redroid:8.1.0-latest"
    "docker://redroid/redroid:9.0.0-latest"
    "docker://redroid/redroid:10.0.0-latest"
    "docker://redroid/redroid:11.0.0-latest"
    "docker://redroid/redroid:12.0.0-latest"
    "docker://dockurr/macos:11"
    "docker://dockurr/macos:12"
    "docker://dockurr/macos:13"
    "docker://dockurr/macos:14"
    "docker://dockurr/macos:15"
)

log() {
    printf '[images_auto_list] %s\n' "$*" >&2
}

require_command() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        log "ERROR: missing required command: $name"
        exit 1
    fi
}

test_api_endpoint() {
    local endpoint="$1"
    local test_url="${endpoint}/repos/oneclickvirt/lxc_amd64_images"

    curl -fsSL --connect-timeout 5 --max-time 10 -H "User-Agent: ${USER_AGENT}" "${test_url}" |
        jq -e '.full_name? == "oneclickvirt/lxc_amd64_images" or .name? == "lxc_amd64_images"' >/dev/null
}

get_working_api() {
    local endpoint
    for endpoint in "${API_ENDPOINTS[@]}"; do
        if test_api_endpoint "$endpoint"; then
            printf '%s\n' "$endpoint"
            return 0
        fi
    done
    return 1
}

should_exclude_url() {
    local url="$1"
    local pattern
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$url" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

emit_repo_download_urls() {
    local repo="$1"
    local api_base="$2"
    local page=1

    while true; do
        local url="${api_base}/repos/${repo}/releases?per_page=100&page=${page}"
        local releases_data
        if ! releases_data=$(curl -fsSL -H "User-Agent: ${USER_AGENT}" "$url"); then
            log "WARN: failed to fetch releases for ${repo} from page ${page}"
            return 1
        fi

        local release_count
        release_count=$(jq 'length' <<<"${releases_data}")
        if [[ ! "$release_count" =~ ^[0-9]+$ ]] || [ "$release_count" -eq 0 ]; then
            break
        fi

        jq -r '
            .[] |
            select(.tag_name != "processed" and .tag_name != null) |
            .assets[]? |
            .browser_download_url // empty
        ' <<<"${releases_data}" | while IFS= read -r download_url; do
            if [ -n "$download_url" ] && ! should_exclude_url "$download_url"; then
                printf '%s\n' "$download_url"
            fi
        done

        page=$((page + 1))
    done
}

emit_urls_from_text_source() {
    local source_url="$1"
    local content

    if ! content=$(curl -fsSL --connect-timeout 10 --max-time 30 -H "User-Agent: ${USER_AGENT}" "$source_url"); then
        log "WARN: failed to fetch raw list source: ${source_url}"
        return 1
    fi

    grep -Eo '(https?://|download\.testip\.xyz/)[^[:space:]<>"'\''\)]*\.(iso|iso\.7z)(/download|\?[^[:space:]<>"'\''\)]*)?' <<<"${content}" |
        sed -E 's#^download\.testip\.xyz/#https://download.testip.xyz/#I'
}

emit_android_x86_urls() {
    local dir_url="$1"
    local content

    if ! content=$(curl -fsSL --connect-timeout 10 --max-time 30 -H "User-Agent: ${USER_AGENT}" "$dir_url"); then
        log "WARN: failed to fetch Android-x86 directory: ${dir_url}"
        return 1
    fi

    grep -Eo 'href="[^"]+\.iso"' <<<"${content}" |
        sed -E 's/^href="//; s/"$//' |
        while IFS= read -r href; do
            if [[ "$href" == http://* || "$href" == https://* ]]; then
                printf '%s\n' "$href"
            else
                printf '%s%s\n' "$dir_url" "$href"
            fi
        done
}

main() {
    require_command curl
    require_command jq
    require_command grep
    require_command sed
    require_command sort

    log "Testing GitHub API endpoints"
    local working_api
    if ! working_api=$(get_working_api); then
        log "ERROR: no GitHub API endpoint is available"
        exit 1
    fi
    log "Using API endpoint: ${working_api}"

    local tmp_file
    tmp_file=$(mktemp)
    trap 'rm -f "${tmp_file}"' EXIT

    local repo
    local failed_repos=0
    for repo in "${REPOS[@]}"; do
        log "Processing repository: ${repo}"
        if ! emit_repo_download_urls "$repo" "$working_api" >>"${tmp_file}"; then
            failed_repos=$((failed_repos + 1))
        fi
        sleep 1
    done

    local source_url
    for source_url in "${RAW_LIST_SOURCES[@]}"; do
        log "Processing raw image source: ${source_url}"
        if ! emit_urls_from_text_source "$source_url" >>"${tmp_file}"; then
            failed_repos=$((failed_repos + 1))
        fi
        sleep 1
    done

    local android_dir
    for android_dir in "${ANDROID_X86_DIRS[@]}"; do
        log "Processing Android-x86 mirror directory: ${android_dir}"
        if ! emit_android_x86_urls "$android_dir" >>"${tmp_file}"; then
            failed_repos=$((failed_repos + 1))
        fi
        sleep 1
    done

    log "Adding installer and special runtime image references"
    printf '%s\n' "${MACOS_INSTALLER_REFS[@]}" >>"${tmp_file}"
    printf '%s\n' "${BLISSOS_INSTALLER_REFS[@]}" >>"${tmp_file}"
    printf '%s\n' "${EXTRA_IMAGE_REFS[@]}" >>"${tmp_file}"

    if [ ! -s "$tmp_file" ]; then
        log "ERROR: no image URLs were generated"
        exit 1
    fi

    sort -u "$tmp_file" >"$OUTPUT_FILE"

    local url_count
    url_count=$(wc -l <"$OUTPUT_FILE" | tr -d ' ')
    local special_count
    special_count=$(grep -c '^docker://' "$OUTPUT_FILE" || true)
    local installer_count
    installer_count=$(grep -Eci '\.(iso|iso\.7z)(/download)?(\?|$)' "$OUTPUT_FILE" || true)

    log "Generated ${url_count} image entries"
    log "Included ${special_count} Docker special runtime entries"
    log "Included ${installer_count} installer ISO entries"
    if [ "$failed_repos" -gt 0 ]; then
        log "WARN: ${failed_repos} repositories failed; generated list still includes available entries"
    fi
    log "Saved result to: ${OUTPUT_FILE}"
}

main "$@"
