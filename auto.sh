#!/bin/bash

# GitHub仓库列表
REPOS=(
    "oneclickvirt/lxc_amd64_images"
    "oneclickvirt/lxc_arm_images" 
    "oneclickvirt/lxd_images"
    "oneclickvirt/incus_images"
    "oneclickvirt/docker"
    "oneclickvirt/pve_kvm_images"
)

# API端点列表
API_ENDPOINTS=(
    "https://api.github.com"
    "https://githubapi.spiritlhl.workers.dev"
    "https://githubapi.spiritlhl.top"
)

# 输出文件
OUTPUT_FILE="images.txt"

# 删除旧文件
rm -f "$OUTPUT_FILE"

# 测试API端点可用性
test_api_endpoint() {
    local endpoint="$1"
    local test_url="${endpoint}/repos/oneclickvirt/lxc_amd64_images"
    
    if curl -s --connect-timeout 5 --max-time 10 "${test_url}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 获取可用的API端点
get_working_api() {
    for endpoint in "${API_ENDPOINTS[@]}"; do
        if test_api_endpoint "$endpoint"; then
            echo "$endpoint"
            return 0
        fi
    done
    return 1
}

# 获取仓库的所有releases下载链接
get_repo_download_urls() {
    local repo="$1"
    local api_base="$2"
    local url="${api_base}/repos/${repo}/releases"
    
    # 获取releases数据
    local releases_data
    releases_data=$(curl -s -H "User-Agent: GitHub-Releases-Fetcher/1.0" "$url")
    
    if [ $? -ne 0 ] || [ -z "$releases_data" ]; then
        return 1
    fi
    
    # 提取非"processed"标签的下载链接
    echo "$releases_data" | jq -r '
        .[] | 
        select(.tag_name != "processed" and .tag_name != null) |
        .assets[] | 
        .browser_download_url
    ' 2>/dev/null
}

# 主函数
main() {
    echo "正在测试API端点..."
    
    # 获取可用的API端点
    WORKING_API=$(get_working_api)
    
    if [ $? -ne 0 ]; then
        echo "错误: 所有API端点都不可用"
        exit 1
    fi
    
    echo "使用API端点: $WORKING_API"
    
    # 检查依赖
    if ! command -v curl &> /dev/null; then
        echo "错误: 需要安装 curl"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "错误: 需要安装 jq" 
        exit 1
    fi
    
    echo "正在获取下载链接..."
    
    # 处理每个仓库
    for repo in "${REPOS[@]}"; do
        echo "处理仓库: $repo"
        
        urls=$(get_repo_download_urls "$repo" "$WORKING_API")
        
        if [ -n "$urls" ]; then
            echo "$urls" >> "$OUTPUT_FILE"
        fi
        
        sleep 1  # 避免API限制
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

# 运行主函数
main
