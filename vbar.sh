#!/usr/bin/env bash
# <xbar.title>vbar</xbar.title>
# <xbar.version>v0.3.0</xbar.version>
# <xbar.desc>菜单栏显示 "英文单词 · 中文释义"，手动切换，真人发音</xbar.desc>
# <xbar.dependencies>bash,awk,curl</xbar.dependencies>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.environment>[VBAR_WORDS=, VBAR_MAXLEN=24]</swiftbar.environment>
#
# 三个插件（见 install.sh），按钮插件是调用本脚本的薄包装，用 VBAR_ROLE 区分：
#   vbar.sh       单词 · 释义，点击打开菜单
#   vbar-say.sh   🔊 按钮，点击朗读当前单词（VBAR_ROLE=say）
#   vbar-next.sh  ⏭ 按钮，点击切换到下一个（VBAR_ROLE=next）
# 注意：SwiftBar 以软链接解析后的真实路径作为插件 ID，所以每个插件必须是不同的文件。
# 文件名不带刷新间隔，所以不会自动轮播。
#
# 词库在 words/*.tsv，格式（# 开头为注释，"# name: xxx" 为词库显示名）：
#   单词<TAB>中文释义[<TAB>音标[<TAB>发音/用法提示]]

export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# 解析软链接，找到脚本真实位置
resolve() {
  local p="$1"
  while [ -L "$p" ]; do
    local t; t="$(readlink "$p")"
    case "$t" in /*) p="$t" ;; *) p="$(dirname "$p")/$t" ;; esac
  done
  echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
}
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
HERE="$(dirname "$(resolve "$SELF")")"

BOOK_DIR="$HERE/words"
MAXLEN="${VBAR_MAXLEN:-24}"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vbar"
STATE="$STATE_DIR/state"
KNOWN="$STATE_DIR/known.txt"
AUDIO_DIR="$HOME/Library/Caches/vbar/audio"
mkdir -p "$STATE_DIR/pos"
touch "$KNOWN"

# ---------- 状态 ----------
# 全局设置在 state，每个词库的进度单独存在 pos/<词库>
book=common shuffle=0 seed=1 accent=us autosay=1
# shellcheck disable=SC1090
[ -f "$STATE" ] && . "$STATE"
save() {
  printf 'book=%s\nshuffle=%d\nseed=%d\naccent=%s\nautosay=%d\n' \
    "$book" "$shuffle" "$seed" "$accent" "$autosay" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

if [ -n "$VBAR_WORDS" ]; then
  WORDS="$VBAR_WORDS"
else
  WORDS="$BOOK_DIR/$book.tsv"
  # 当前词库不存在时退回第一个
  if [ ! -f "$WORDS" ]; then
    WORDS="$(ls "$BOOK_DIR"/*.tsv 2>/dev/null | head -n1)"
    book="$(basename "$WORDS" .tsv)"
  fi
fi
POSF="$STATE_DIR/pos/$(basename "$WORDS" .tsv)"
pos=$(cat "$POSF" 2>/dev/null || echo 0)
save_pos() { echo "$pos" >"$POSF"; }

# 让菜单栏上的单词刷新（按钮插件触发动作后需要）
refresh_main() { open -g "swiftbar://refreshplugin?name=vbar" 2>/dev/null; }

# 朗读：优先用有道词典真人发音（缓存到本地），失败时退回系统 say
speak() {
  local w="$1" type=2 voice=Samantha
  [ "$accent" = uk ] && type=1 voice=Daniel
  local f; f="$AUDIO_DIR/$accent/$(printf '%s' "$w" | tr '[:upper:]/' '[:lower:]_').mp3"
  if [ ! -s "$f" ]; then
    mkdir -p "$(dirname "$f")"
    local ct
    ct="$(curl -fsS -G --max-time 5 -o "$f.tmp" -w '%{content_type}' \
      --data-urlencode "audio=$w" -d "type=$type" https://dict.youdao.com/dictvoice 2>/dev/null)"
    if [[ "$ct" == audio/* ]] && [ -s "$f.tmp" ]; then mv "$f.tmp" "$f"; else rm -f "$f.tmp"; fi
  fi
  if [ -s "$f" ]; then
    afplay "$f"
  else
    say -v "$voice" "$w" 2>/dev/null || say "$w"
  fi
}

# 给 SwiftBar 参数加引号（条目里可能有撇号，如 I'm on it）
q() { case "$1" in *"'"*) printf '"%s"' "$1" ;; *) printf "'%s'" "$1" ;; esac; }

# ---------- 按钮插件 ----------
if [ -z "$1" ]; then
  case "$VBAR_ROLE" in
    say)  echo " | sfimage=speaker.wave.2 bash='$SELF' param1=say terminal=false"; exit 0 ;;
    next) echo " | sfimage=forward.end bash='$SELF' param1=next terminal=false"; exit 0 ;;
  esac
fi

# ---------- 菜单动作（由 SwiftBar 以 param1/param2 调用） ----------
case "$1" in
  next)    pos=$((pos + 1)); save_pos ;;   # 继续往下：刷新菜单栏并按设置自动朗读
  prev)    pos=$((pos - 1)); save_pos ;;
  shuffle) shuffle=$((1 - shuffle)); seed=$RANDOM; pos=0; save; save_pos; exit 0 ;;
  known)   [ -n "$2" ] && echo "$2" >>"$KNOWN"; exit 0 ;;
  reset)   : >"$KNOWN"; exit 0 ;;
  accent)  [ "$accent" = uk ] && accent=us || accent=uk; save; exit 0 ;;
  autosay) autosay=$((1 - autosay)); save; exit 0 ;;
  book)    [ -f "$BOOK_DIR/$2.tsv" ] && book="$2" && save; exit 0 ;;
esac

# ---------- 词库 ----------
if [ ! -f "$WORDS" ]; then
  echo "vbar ⚠︎"
  echo "---"
  echo "找不到词库：${WORDS:-$BOOK_DIR/*.tsv}"
  exit 0
fi

# 过滤注释/空行/已掌握，按需打乱（固定 seed，保证顺序稳定）
list="$(awk -F'\t' '
  FILENAME == ARGV[1] { if ($0 != "") k[tolower($0)]; next }
  /^[[:space:]]*(#|$)/ { next }
  NF >= 2 && !(tolower($1) in k)
' "$KNOWN" "$WORDS")"
if [ "$shuffle" = 1 ]; then
  list="$(printf '%s\n' "$list" | awk -v s="$seed" 'BEGIN { srand(s) } { printf "%.8f\t%s\n", rand(), $0 }' | sort -n | cut -f2-)"
fi

total=$([ -n "$list" ] && printf '%s\n' "$list" | wc -l | tr -d ' ' || echo 0)
known_n=$(grep -c . "$KNOWN")

idx=0
if [ "$total" -gt 0 ]; then
  idx=$(((pos % total + total) % total))
  line="$(printf '%s\n' "$list" | sed -n "$((idx + 1))p")"
  # 制表符是空白字符，read 会合并连续的空字段，先换成非空白分隔符
  IFS=$'\x1f' read -r word meaning phonetic note <<<"${line//$'\t'/$'\x1f'}"
fi

case "$1" in
  say)
    [ -n "$word" ] && speak "$word"; exit 0 ;;
  next|prev)
    [ "$idx" != "$pos" ] && { pos=$idx; save_pos; }
    refresh_main
    [ "$autosay" = 1 ] && [ -n "$word" ] && speak "$word"
    exit 0 ;;
esac

[ "$idx" != "$pos" ] && { pos=$idx; save_pos; }

# ---------- 输出 ----------
if [ "$total" -eq 0 ]; then
  echo "vbar ✓"
  echo "---"
  echo "这个词库里的单词都已掌握 🎉"
else
  # SwiftBar 用 | 分隔参数，替换掉文本里的 |
  word="${word//|/／}"; meaning="${meaning//|/／}"; phonetic="${phonetic//|/／}"; note="${note//|/／}"
  url="${word// /%20}"; url="${url//\'/%27}"

  echo "$word · $meaning | length=$MAXLEN emojize=false"
  echo "---"
  echo "$word | size=16 emojize=false"
  [ -n "$phonetic" ] && echo "$phonetic | color=gray emojize=false"
  echo "$meaning | emojize=false"
  [ -n "$note" ] && echo "$note | sfimage=lightbulb emojize=false"
  echo "---"
  echo "朗读 | sfimage=speaker.wave.2 bash='$SELF' param1=say terminal=false"
  echo "在词典中查看 | sfimage=book href=dict://$url"
  echo "---"
  echo "下一个 | sfimage=chevron.right bash='$SELF' param1=next terminal=false"
  echo "上一个 | sfimage=chevron.left bash='$SELF' param1=prev terminal=false"
  echo "标记为已掌握 | sfimage=checkmark.circle bash='$SELF' param1=known param2=$(q "$word") terminal=false refresh=true"
fi
echo "---"

# 词库子菜单
book_name() { sed -n 's/^# name: *//p' "$1" | head -n1; }
echo "词库：$(book_name "$WORDS" || true) | sfimage=books.vertical"
for f in "$BOOK_DIR"/*.tsv; do
  [ -f "$f" ] || continue
  id="$(basename "$f" .tsv)"; name="$(book_name "$f")"
  checked=false; [ "$f" = "$WORDS" ] && checked=true
  echo "--${name:-$id} | checked=$checked bash='$SELF' param1=book param2='$id' terminal=false refresh=true"
done

if [ "$shuffle" = 1 ]; then
  echo "顺序：随机（点击切换为顺序） | sfimage=shuffle bash='$SELF' param1=shuffle terminal=false refresh=true"
else
  echo "顺序：按词库（点击切换为随机） | sfimage=list.number bash='$SELF' param1=shuffle terminal=false refresh=true"
fi
if [ "$accent" = uk ]; then
  echo "发音：英音（点击切换为美音） | sfimage=waveform bash='$SELF' param1=accent terminal=false refresh=true"
else
  echo "发音：美音（点击切换为英音） | sfimage=waveform bash='$SELF' param1=accent terminal=false refresh=true"
fi
echo "切换时自动朗读 | checked=$([ "$autosay" = 1 ] && echo true || echo false) bash='$SELF' param1=autosay terminal=false refresh=true"
echo "进度 $((idx + 1))/$total · 已掌握 $known_n | color=gray"
echo "编辑词库 | sfimage=square.and.pencil bash=/usr/bin/open param1=-t param2='$WORDS' terminal=false"
echo "查看已掌握 | bash=/usr/bin/open param1=-t param2='$KNOWN' terminal=false"
[ "$known_n" -gt 0 ] && echo "重置已掌握 | bash='$SELF' param1=reset terminal=false refresh=true"
exit 0
