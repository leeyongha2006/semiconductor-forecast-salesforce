"""기사 본문에서 중요한 문장 몇 개를 골라 요약한다 (추출 요약).

외부 AI 호출 없이 Lambda 안에서 끝나도록 점수 규칙만 쓴다.
  - 앞쪽 문장일수록 가산 (기사는 결론을 앞에 쓰는 경우가 많다)
  - 관심 키워드가 들어 있으면 가산
  - 숫자(금액, 비율, 수량)가 있으면 가산
고른 문장은 원래 순서대로 이어 붙인다.
"""

import re

SENTENCE_END = re.compile(r"(?<=[.!?。])\s+|(?<=다\.)\s*")
NUMBER = re.compile(r"\d[\d,.]*\s*(%|억|만|조|원|달러|개|대|nm)?")

DEFAULT_KEYWORDS = ("반도체", "패키징", "투자", "수요", "공급", "실적", "증설", "AI")


def split_sentences(text):
    parts = SENTENCE_END.split(re.sub(r"\s+", " ", text or "").strip())
    return [p.strip() for p in parts if p and len(p.strip()) >= 10]


def score_sentence(sentence, index, total, keywords):
    position = 1.0 - (index / total) if total else 0
    keyword_hits = sum(1 for k in keywords if k.lower() in sentence.lower())
    has_number = 1 if NUMBER.search(sentence) else 0
    return position * 2 + keyword_hits * 1.5 + has_number


def summarize(text, max_sentences=3, max_length=500, keywords=DEFAULT_KEYWORDS):
    sentences = split_sentences(text)
    if not sentences:
        return ""
    scored = [
        (score_sentence(s, i, len(sentences), keywords), i, s)
        for i, s in enumerate(sentences)
    ]
    top = sorted(scored, key=lambda item: (-item[0], item[1]))[:max_sentences]
    ordered = [s for _, _, s in sorted(top, key=lambda item: item[1])]

    summary = ""
    for sentence in ordered:
        candidate = (summary + " " + sentence).strip()
        if len(candidate) > max_length:
            break
        summary = candidate
    return summary or ordered[0][:max_length]


def to_html(summary):
    """Salesforce 서식 있는 텍스트 필드에 넣을 HTML"""
    escaped = summary.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return "<p>" + escaped + "</p>" if escaped else ""
