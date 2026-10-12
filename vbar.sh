#!/usr/bin/env bash
# <xbar.title>vbar</xbar.title>
# <xbar.version>v0.4.0</xbar.version>
# <xbar.desc>菜单栏显示 "英文单词 · 中文释义"</xbar.desc>
# <xbar.dependencies>bash,awk,curl</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
#
# 三个插件（见 install.sh），按钮插件是调用本脚本的薄包装，用 VBAR_ROLE 区分：
#   vbar.sh       单词 · 释义，下拉菜单切换词库
#   vbar-say.sh   🔊 播放读音（VBAR_ROLE=say）
#   vbar-next.sh  ⏭ 下一个（VBAR_ROLE=next）
# SwiftBar 以软链接解析后的真实路径作为插件 ID，所以每个插件必须是不同的文件。
#
# 词库：words/*.tsv，每行 单词<TAB>中文释义，其余列忽略；"# name: xxx" 为显示名。

export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
HERE="$(dirname "$(readlink -f "$SELF")")"
BOOK_DIR="$HERE/words"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vbar"
AUDIO_DIR="$HOME/Library/Caches/vbar/audio"
mkdir -p "$STATE_DIR/pos"

# ---------- 按钮插件 ----------
if [ -z "$1" ]; then
  case "$VBAR_ROLE" in
    say)  echo " | sfimage=speaker.wave.2 bash='$SELF' param1=say terminal=false"; exit 0 ;;
    next) echo " | sfimage=forward.end bash='$SELF' param1=next terminal=false"; exit 0 ;;
  esac
fi

# ---------- 状态：当前词库 + 每个词库的进度 ----------
book="$(cat "$STATE_DIR/book" 2>/dev/null)"
if [ "$1" = book ]; then
  [ -f "$BOOK_DIR/$2.tsv" ] && echo "$2" >"$STATE_DIR/book"
  exit 0
fi
WORDS="$BOOK_DIR/$book.tsv"
[ -f "$WORDS" ] || WORDS="$BOOK_DIR/common.tsv"
[ -f "$WORDS" ] || WORDS="$(ls "$BOOK_DIR"/*.tsv 2>/dev/null | head -n1)"
POSF="$STATE_DIR/pos/$(basename "$WORDS" .tsv)"
pos=$(cat "$POSF" 2>/dev/null || echo 0)

if [ ! -f "$WORDS" ]; then
  echo "vbar ⚠︎"; echo "---"; echo "找不到词库：$BOOK_DIR/*.tsv"
  exit 0
fi

list="$(awk -F'\t' '!/^[[:space:]]*(#|$)/ && NF >= 2 { print $1 "\t" $2 }' "$WORDS")"
total=$(printf '%s\n' "$list" | grep -c .)
[ "$1" = next ] && pos=$((pos + 1))
pos=$((total > 0 ? pos % total : 0))
echo "$pos" >"$POSF"
line="$(printf '%s\n' "$list" | sed -n "$((pos + 1))p")"
word="${line%%$'\t'*}" meaning="${line#*$'\t'}"

# ---------- 动作 ----------
case "$1" in
  next)
    open -g "swiftbar://refreshplugin?name=vbar" 2>/dev/null
    exit 0 ;;
  say)
    # 有道词典真人发音（美音），缓存到本地；失败时退回系统 say
    f="$AUDIO_DIR/us/$(printf '%s' "$word" | tr '[:upper:]/' '[:lower:]_').mp3"
    if [ ! -s "$f" ]; then
      mkdir -p "$(dirname "$f")"
      ct="$(curl -fsS -G --max-time 5 -o "$f.tmp" -w '%{content_type}' \
        --data-urlencode "audio=$word" -d type=2 https://dict.youdao.com/dictvoice 2>/dev/null)"
      if [[ "$ct" == audio/* ]] && [ -s "$f.tmp" ]; then mv "$f.tmp" "$f"; else rm -f "$f.tmp"; fi
    fi
    if [ -s "$f" ]; then afplay "$f"; else say -v Samantha "$word" 2>/dev/null || say "$word"; fi
    exit 0 ;;
esac

# ---------- 输出 ----------
# SwiftBar 用 | 分隔参数，替换掉文本里的 |
echo "${word//|/／} · ${meaning//|/／} | length=30 emojize=false"
echo "---"
for f in "$BOOK_DIR"/*.tsv; do
  id="$(basename "$f" .tsv)"
  name="$(sed -n 's/^# name: *//p' "$f" | head -n1)"
  checked=false; [ "$f" = "$WORDS" ] && checked=true
  echo "${name:-$id} | checked=$checked bash='$SELF' param1=book param2='$id' terminal=false refresh=true"
done
