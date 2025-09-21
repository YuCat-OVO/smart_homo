# --- 构建阶段 ---
FROM alpine:latest AS builder

ARG TARGETPLATFORM="linux/amd64"
ARG REPO="vernesong/mihomo"
ARG TAG="Prerelease-Alpha"

RUN apk add --no-cache curl jq ca-certificates

WORKDIR /app

RUN \
    # --- 下载并准备 Mihomo 二进制文件 ---
    case ${TARGETPLATFORM} in \
        "linux/amd64")   arch="amd64" ;; \
        "linux/386")     arch="386"      ;; \
        "linux/arm64")   arch="arm64"    ;; \
        "linux/arm/v7")  arch="armv7"    ;; \
        "linux/riscv64") arch="riscv64"  ;; \
        *) echo "错误：不支持的架构 '${TARGETPLATFORM}'" >&2 && exit 1 ;; \
    esac && \
    \
    FILE_PATTERN="mihomo-linux-${arch}-alpha-smart-.*\.gz" && \
    \
    API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}" && \
    \
    DOWNLOAD_URL=$(curl -sL "${API_URL}" | jq -r --arg pattern "${FILE_PATTERN}" '.assets[] | select(.name | test($pattern)) | .browser_download_url') && \
    \
    if [ -z "${DOWNLOAD_URL}" ]; then \
        echo "错误：无法为模式 '${FILE_PATTERN}' 找到下载链接" >&2 && \
        exit 1; \
    fi && \
    \
    curl -sL -o mihomo.gz "${DOWNLOAD_URL}" && \
    gunzip mihomo.gz && \
    chmod +x mihomo && \
    \
    # ---下载 Geo 数据文件 ---
    mkdir /mihomo-config && \
    \
    curl -sL -o /mihomo-config/geoip.metadb https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb && \
    curl -sL -o /mihomo-config/geosite.dat https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat && \
    curl -sL -o /mihomo-config/geoip.dat https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat

# --- 最终阶段 ---
# 此阶段创建最终的、精简的运行镜像。
FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/vernesong/mihomo"

RUN apk add --no-cache ca-certificates tzdata iptables

VOLUME ["/root/.config/mihomo/"]

COPY --from=builder /mihomo-config/ /root/.config/mihomo/
COPY --from=builder /mihomo/mihomo /mihomo
ENTRYPOINT [ "/mihomo" ]

