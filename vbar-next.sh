#!/usr/bin/env bash
# <xbar.title>vbar 下一个</xbar.title>
# <xbar.desc>点击切换到 vbar 的下一个单词</xbar.desc>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
VBAR_ROLE=next exec "$(dirname "$(readlink -f "$0")")/vbar.sh" "$@"
