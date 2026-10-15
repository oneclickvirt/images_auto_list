#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$repo_root/auto.sh"
curl() {
    if [[ "${!#}" == *'page=1' ]]; then
        cat <<'JSON'
[
 {"tag_name":"ubuntu","draft":false,"prerelease":false,"assets":[
  {"name":"ubuntu.zip","state":"uploaded","size":123,"browser_download_url":"https://example.test/ubuntu.zip"},
  {"name":"ubuntu.zip.ci-stage-42","state":"uploaded","size":123,"browser_download_url":"https://example.test/staged"},
  {"name":"ubuntu.zip.ci-backup-42","state":"uploaded","size":123,"browser_download_url":"https://example.test/backup"},
  {"name":"empty.zip","state":"uploaded","size":0,"browser_download_url":"https://example.test/empty"},
  {"name":"pending.zip","state":"new","size":123,"browser_download_url":"https://example.test/pending"}]},
 {"tag_name":"legacy-archived","assets":[{"name":"old.zip","state":"uploaded","size":123,"browser_download_url":"https://example.test/archived"}]},
 {"tag_name":"processed","assets":[{"name":"old.zip","state":"uploaded","size":123,"browser_download_url":"https://example.test/processed"}]},
 {"tag_name":"next","prerelease":true,"assets":[{"name":"old.zip","state":"uploaded","size":123,"browser_download_url":"https://example.test/prerelease"}]},
 {"tag_name":"draft","draft":true,"assets":[{"name":"old.zip","state":"uploaded","size":123,"browser_download_url":"https://example.test/draft"}]}
]
JSON
    else printf '[]\n'; fi
}
result=$(emit_repo_download_urls oneclickvirt/incus_images https://api.test)
[[ "$result" == https://example.test/ubuntu.zip ]] || { printf 'unsafe release filter: %s\n' "$result" >&2; exit 1; }
# shellcheck disable=SC2154
[[ " ${REPOS[*]} " == *' oneclickvirt/pve_lxc_images '* ]]
echo 'Published release and staging filter tests passed'

curl() { printf '<rss><link>https://sourceforge.net/projects/android-x86/files/Release%%209.0/android-x86_64-9.0-r2.iso/download</link></rss>\n'; }
result=$(emit_urls_from_text_source https://feed.test)
[[ "$result" == https://sourceforge.net/projects/android-x86/files/Release%209.0/android-x86_64-9.0-r2.iso/download ]]
curl() { printf 'valid source without any installer links\n'; }
result=$(emit_urls_from_text_source https://feed.test)
[[ -z "$result" ]]
echo 'Official Android feed and empty-source fallback tests passed'
