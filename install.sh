#!/usr/bin/env bash
# 把 vbar 以软链接方式安装到 SwiftBar 插件目录：
# 三个插件：单词、朗读按钮、下一个按钮（必须是不同文件，SwiftBar 按真实路径去重）
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
DIR="${1:-${DIR:-$HOME/Library/Application Support/SwiftBar/Plugins}}"

mkdir -p "$DIR"
chmod +x "$HERE"/vbar*.sh
# 清理旧的 vbar 链接（包括旧版带间隔的 vbar.10s.sh）
find "$DIR" -maxdepth 1 -name 'vbar*.sh' -type l -delete
for name in vbar vbar-say vbar-next; do
  ln -s "$HERE/$name.sh" "$DIR/$name.sh"
  echo "已安装：$DIR/$name.sh"
done

open -g "swiftbar://refreshallplugins" 2>/dev/null || true
