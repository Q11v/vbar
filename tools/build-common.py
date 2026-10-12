#!/usr/bin/env python3
"""从 ECDICT 生成 words/common.tsv：牛津 3000 核心词，去掉中考词汇，按 COCA 词频排序。

用法：
    python3 tools/build-common.py [ecdict.csv]

不传路径时自动下载 ECDICT（约 63MB，MIT 协议，https://github.com/skywind3000/ECDICT）。
"""
import csv
import os
import re
import sys
import tempfile
import urllib.request

ECDICT_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "words", "common.tsv")

MAX_POS_LINES = 2   # 最多保留几个词性
MAX_SENSES = 3      # 每个词性最多保留几个义项
POS_ALIAS = {"a.": "adj.", "ad.": "adv.", "vt.": "v.", "vi.": "v."}


def phonetic(p):
    """ECDICT 的音标：' 表示重音，. 或 , 表示次重音，ә 是西里尔字母，: 表示长音。"""
    if not p:
        return ""
    p = p.replace("'", "ˈ").replace("ә", "ə").replace(":", "ː")
    p = re.sub(r"^[.,]|(?<=\s)[.,]", "ˌ", p)
    # ECDICT 多为旧式 DJ 音标，转成现在通行的 IPA（双元音先换，再换短元音 i/u）
    for a, b in (("ei", "eɪ"), ("ai", "aɪ"), ("ɔi", "ɔɪ"), ("au", "aʊ"), ("əu", "əʊ"),
                 ("iə", "ɪə"), ("uə", "ʊə"), ("εə", "eə"), ("ɛə", "eə"), ("g", "ɡ")):
        p = p.replace(a, b)
    p = re.sub(r"i(?!ː)", "ɪ", p)
    p = re.sub(r"u(?!ː)", "ʊ", p)
    p = p.replace("əː", "ɜː")
    p = re.sub(r"ɪ(?=$|\s)", "i", p)  # 词尾非重读 i（happy）
    return f"/{p}/"


def translation(t):
    lines = [l.strip() for l in t.replace("\\r", "").split("\\n")]
    # 去掉 [计] [医] [网络] 这类专业/网络释义
    lines = [l for l in lines if l and not l.startswith("[")]
    out, seen = [], set()
    for l in lines:
        m = re.match(r"^([a-z]+\.)\s*(.*)$", l)
        pos, body = (m.group(1), m.group(2)) if m else ("", l)
        pos = POS_ALIAS.get(pos, pos)
        senses = [s.strip() for s in re.split(r"[,，;；]", body) if s.strip()][:MAX_SENSES]
        if not senses:
            continue
        if pos in seen:  # vt./vi. 合并成 v. 后可能重复
            continue
        seen.add(pos)
        out.append(f"{pos} {'，'.join(senses)}".strip())
        if len(out) >= MAX_POS_LINES:
            break
    return "；".join(out)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else None
    if not src:
        src = os.path.join(tempfile.mkdtemp(), "ecdict.csv")
        print(f"下载 ECDICT -> {src}", file=sys.stderr)
        urllib.request.urlretrieve(ECDICT_URL, src)

    rows = []
    with open(src, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r["oxford"] != "1" or "zk" in r["tag"].split():
                continue
            # 跳过词组（多为 look at 这类无词频的初级搭配）和 Mr、TV 这类专有/缩写
            if not re.fullmatch(r"[a-z][a-z'-]*", r["word"]):
                continue
            meaning = translation(r["translation"])
            if not meaning:
                continue
            frq = int(r["frq"] or 0)
            rows.append((frq == 0, frq, r["word"], meaning, phonetic(r["phonetic"])))
    rows.sort()

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# name: 常用词汇\n")
        f.write("# 牛津 3000 核心词（去掉中考词汇），按 COCA 词频从常用到生僻排序。\n")
        f.write("# 由 tools/build-common.py 从 ECDICT 生成，数据 MIT 协议：https://github.com/skywind3000/ECDICT\n")
        for *_, word, meaning, ph in rows:
            f.write(f"{word}\t{meaning}\t{ph}\n")
    print(f"写入 {len(rows)} 个词 -> {os.path.normpath(OUT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
