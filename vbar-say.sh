#!/usr/bin/env bash
# <xbar.title>vbar 朗读</xbar.title>
# <xbar.desc>点击朗读 vbar 当前单词</xbar.desc>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
VBAR_ROLE=say exec "$(dirname "$(readlink -f "$0")")/vbar.sh" "$@"
