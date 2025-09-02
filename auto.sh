#!/bin/bash

REPOS=(
    "oneclickvirt/lxc_amd64_images"
    "oneclickvirt/lxc_arm_images" 
    "oneclickvirt/lxd_images"
    "oneclickvirt/incus_images"
    "oneclickvirt/docker"
    "oneclickvirt/pve_kvm_images"
)

API_ENDPOINTS=(
    "https://api.github.com"
    "https://githubapi.spiritlhl.workers.dev"
    "https://githubapi.spiritlhl.top"
)

OUTPUT_FILE="images.txt"

EXCLUDE_PATTERNS=(
    "win2022.part"
    "builder.tar"
    "vagrant_2.3.8.dev-1_amd64.deb"
)

rm -f "$OUTPUT_FILE"

test_api_endpoint() {
    local endpoint="$1"
    local test_url="${endpoint}/repos/oneclickvirt/lxc_amd64_images"
    
    if curl -s --connect-timeout 5 --max-time 10 "${test_url}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

get_working_api() {
    for endpoint in "${API_ENDPOINTS[@]}"; do
        if test_api_endpoint "$endpoint"; then
            echo "$endpoint"
            return 0
        fi
    done
    return 1
}

should_exclude_url() {
    local url="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$url" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

get_repo_download_urls() {
    local repo="$1"
    local api_base="$2"
    local url="${api_base}/repos/${repo}/releases"
    
    local releases_data
    releases_data=$(curl -s -H "User-Agent: GitHub-Releases-Fetcher/1.0" "$url")
    
    if [ $? -ne 0 ] || [ -z "$releases_data" ]; then
        return 1
    fi
    
    echo "$releases_data" | jq -r '
        .[] | 
        select(.tag_name != "processed" and .tag_name != null) |
        .assets[] | 
        .browser_download_url
    ' 2>/dev/null | while read -r download_url; do
        if [ -n "$download_url" ] && ! should_exclude_url "$download_url"; then
            echo "$download_url"
        fi
    done
}

main() {
    echo "正在测试API端点..."
    
    WORKING_API=$(get_working_api)
    
    if [ $? -ne 0 ]; then
        echo "错误: 所有API端点都不可用"
        exit 1
    fi
    
    echo "使用API端点: $WORKING_API"
    
    if ! command -v curl &> /dev/null; then
        echo "错误: 需要安装 curl"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "错误: 需要安装 jq" 
        exit 1
    fi
    
    echo "正在获取下载链接..."
    
    for repo in "${REPOS[@]}"; do
        echo "处理仓库: $repo"
        
        urls=$(get_repo_download_urls "$repo" "$WORKING_API")
        
        if [ -n "$urls" ]; then
            echo "$urls" >> "$OUTPUT_FILE"
        fi
        
        sleep 1
    done
    
    if [ -f "$OUTPUT_FILE" ]; then
        local url_count
        url_count=$(wc -l < "$OUTPUT_FILE")
        echo "完成! 共获取到 $url_count 个下载链接"
        echo "结果已保存到: $OUTPUT_FILE"
    else
        echo "未获取到任何下载链接"
    fi
}

main
