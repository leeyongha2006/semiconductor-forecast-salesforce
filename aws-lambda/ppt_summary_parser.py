"""프로젝트 요약 PPT의 목차 표를 Salesforce에 넣을 값으로 바꾼다.

python-pptx 로 표를 읽는 부분은 Lambda 핸들러에 두고, 여기서는 표의 행
(셀 문자열 목록)을 받아 섹션 → 항목 → 값으로 정리하는 부분만 다룬다.
그래서 PPT 파일 없이도 테스트할 수 있다.

표 모양 예시:
    | Project Info |                       |
    |              | Application : Mobile  |
    |              | End user    : TBD     |
    | Sales Info   |                       |
    |              | Final Quote | $1,200  |
"""

import re
from datetime import date

PLACEHOLDERS = {"", "-", "n/a", "na", "tbd", "none", "n.a."}
LABEL_VALUE = re.compile(r"^\s*([^:：]+?)\s*[:：]\s*(.+)$")

# (섹션, 항목) → (Salesforce 필드, 값 종류). 실제 필드 이름은 예시다.
TARGETS = {
    ("project info", "application"): ("Application", "text"),
    ("project info", "end user"): ("EndUser", "text"),
    ("project info", "pkg type"): ("PackageType", "text"),
    ("sales info", "final quote"): ("FinalQuote", "currency"),
    ("sales info", "ship to"): ("ShipTo", "account"),
    ("mp plan", "start date"): ("MassProductionStart", "date"),
}


def norm(value):
    """줄바꿈 · 특수 공백을 한 칸 공백으로 정리한다."""
    if value is None:
        return ""
    text = str(value).replace("\xa0", " ").replace("\u000b", " ")
    return re.sub(r"\s+", " ", text).strip()


def is_placeholder(value):
    return norm(value).lower() in PLACEHOLDERS


def to_date(value):
    """'260315', '2026.03.15', '2026-03-15' → date. 해석할 수 없으면 None."""
    digits = re.sub(r"[^0-9]", "", norm(value))
    try:
        if len(digits) == 6:
            return date(2000 + int(digits[0:2]), int(digits[2:4]), int(digits[4:6]))
        if len(digits) == 8:
            return date(int(digits[0:4]), int(digits[4:6]), int(digits[6:8]))
    except ValueError:
        return None
    return None


def to_currency(value):
    """'$1,200.50' → 1200.5. 숫자가 없으면 None."""
    cleaned = re.sub(r"[^0-9.]", "", norm(value))
    try:
        return float(cleaned) if cleaned else None
    except ValueError:
        return None


def split_label_value(cells):
    """한 행에서 (항목, 값)을 꺼낸다.

    'Label : Value' 가 한 셀에 있으면 그 셀을 나누고,
    아니면 비어 있지 않은 셀 중 첫 번째를 항목, 두 번째를 값으로 본다.
    """
    filled = [norm(c) for c in cells if norm(c)]
    for cell in filled:
        match = LABEL_VALUE.match(cell)
        if match:
            return match.group(1), match.group(2)
    if len(filled) >= 2:
        return filled[0], filled[1]
    return None


def parse_sections(rows, section_names):
    """첫 칸에 섹션 이름이 있는 행을 만나면 섹션을 바꾸고, 그 아래 행을 항목으로 모은다."""
    known = {name.lower() for name in section_names}
    sections = {}
    current = None
    for cells in rows:
        first = norm(cells[0]).lower() if cells else ""
        if first in known:
            current = first
            sections.setdefault(current, {})
            rest = cells[1:]
        else:
            rest = cells
        if current is None:
            continue
        pair = split_label_value(rest)
        if pair:
            sections[current][pair[0].lower()] = pair[1]
    return sections


def to_salesforce_fields(sections, account_ids):
    """TARGETS 에 있는 항목만 형식에 맞춰 바꾸고, 빈 값 · 해석 불가 값은 넣지 않는다.

    account_ids: 고객사 이름(소문자) → Salesforce 거래처 Id
    """
    body = {}
    for (section, label), (field, kind) in TARGETS.items():
        raw = sections.get(section, {}).get(label)
        if raw is None or is_placeholder(raw):
            continue
        if kind == "date":
            value = to_date(raw)
            value = value.isoformat() if value else None
        elif kind == "currency":
            value = to_currency(raw)
        elif kind == "account":
            value = account_ids.get(norm(raw).lower())
        else:
            value = norm(raw)
        if value is not None:
            body[field] = value
    return body


def processing_status(found_file, body):
    """프로젝트마다 남기는 처리 결과: 파일 없음 / 실패 / 성공"""
    if not found_file:
        return "None"
    return "Pass" if body else "Fail"
