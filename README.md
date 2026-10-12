# vbar

macOS 菜单栏背单词，SwiftBar 插件。菜单栏显示 `单词 · 释义`，手动切换，真人发音。

## 安装

```sh
./install.sh            # 软链接到 SwiftBar 插件目录（读取 SwiftBar 的配置）
```

菜单栏出现三个图标：单词（点击展开菜单）、🔊 朗读、⏭ 下一个。⌘+拖动可调整顺序。

插件目录改为 `~/.config/swiftbar`（需先退出 SwiftBar，否则退出时会写回旧值）：

```sh
defaults write com.ameba.SwiftBar PluginDirectory ~/.config/swiftbar
```

## 文件

| 路径 | 说明 |
|---|---|
| `vbar.sh` | 主逻辑；`VBAR_ROLE` 决定输出单词还是按钮 |
| `vbar-say.sh` / `vbar-next.sh` | 按钮插件，薄包装 |
| `words/*.tsv` | 词库，菜单里切换 |
| `tools/build-common.py` | 从 [ECDICT](https://github.com/skywind3000/ECDICT) 生成 `words/common.tsv` |
| `~/.config/vbar/` | 状态：设置、各词库进度、已掌握 |
| `~/Library/Caches/vbar/audio/` | 发音缓存 |

## 词库格式

```
# name: 显示名
单词<TAB>中文释义<TAB>音标（可空）<TAB>提示（可空）
```

## 发音

有道 `dict.youdao.com/dictvoice`（type=2 美音 / 1 英音）下载后缓存，`afplay` 播放；失败退回系统 `say`。该接口无官方文档，可能变动；专有名词（nginx 等）可能是合成音，以提示列为准。

## 踩坑记录

- **软链接被去重**：SwiftBar 以软链接解析后的真实路径作为插件 ID，三个链接指向同一文件只会显示一个。→ 每个插件必须是独立文件。
- **按钮点击直接执行**：标题行带 `bash=` 时左键直接执行，⌥+点击/右键才展开菜单（SwiftBar 源码 `routeForBarItemClick`）。
- **跨插件刷新**：按钮执行后用 `open -g "swiftbar://refreshplugin?name=vbar"` 刷新单词插件；`name` 是文件名第一个 `.` 之前的部分。
- **不要自动轮播**：文件名不带间隔（`vbar.sh` 而非 `vbar.10s.sh`）即只在启动和手动刷新时运行。早期带间隔时，动作触发的 `refresh=true` 会额外前进一次，需按时间戳防抖。
- **`read` 吞空字段**：`IFS=$'\t'` 时制表符属空白字符，连续 Tab 会被合并，空音标列导致提示错位。→ 先把 Tab 换成 `\x1f` 再 `read`。
- **awk 双文件惯用法**：`NR==FNR` 在第一个文件为空时失效（已掌握列表为空 → 整个词库被过滤）。→ 用 `FILENAME == ARGV[1]`。
- **参数引号**：SwiftBar 参数用 `'...'` 包裹，`I'm on it` 这类条目要改用双引号；`dict://` 链接需转义空格和撇号。
- **ECDICT 音标**：多为旧式 DJ 写法（`ei`、`əu`、`'` 表重音），生成时转为现行 IPA；释义去掉 `[计]` `[网络]` 等行并截断。
