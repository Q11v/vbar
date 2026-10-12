# vbar

macOS 菜单栏背单词，SwiftBar 插件。

## 功能

- 菜单栏直接显示 `单词 · 释义`
- 两个独立的菜单栏按钮：🔊 播放读音、⏭ 下一个
- 下拉菜单：切换词库

## 安装

```sh
./install.sh   # 软链接到 SwiftBar 插件目录（读取 SwiftBar 的配置）
```

⌘+拖动可调整三个图标的顺序。修改插件目录需先退出 SwiftBar，否则退出时会写回旧值：

```sh
defaults write com.ameba.SwiftBar PluginDirectory ~/.config/swiftbar
```

## 文件

| 路径 | 说明 |
|---|---|
| `vbar.sh` | 主逻辑；`VBAR_ROLE` 决定输出单词还是按钮 |
| `vbar-say.sh` / `vbar-next.sh` | 按钮插件，薄包装（SwiftBar 按真实路径区分插件，必须是独立文件） |
| `words/*.tsv` | 词库，每行 `单词<TAB>释义`，其余列忽略；`# name: xxx` 为显示名 |
| `tools/build-common.py` | 从 [ECDICT](https://github.com/skywind3000/ECDICT) 生成 `words/common.tsv` |
| `~/.config/vbar/` | 当前词库、各词库进度 |
| `~/Library/Caches/vbar/audio/` | 发音缓存 |

读音来自有道词典（美音；接口无官方文档），失败时退回系统 `say`。

## TODO

- [x] 直接展示单词、释义
- [x] 两个显式操作：播放读音、切换到下一个
- [x] 下拉菜单只保留切换词库
