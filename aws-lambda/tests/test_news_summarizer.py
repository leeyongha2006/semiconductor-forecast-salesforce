import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import news_summarizer  # noqa: E402

ARTICLE = (
    "글로벌 반도체 패키징 수요가 올해 15% 늘어날 것으로 전망된다. "
    "업계 관계자는 행사장에서 여러 의견을 나눴다. "
    "주요 기업들은 첨단 패키징 라인 증설에 3조원을 투자하기로 했다. "
    "날씨가 좋아 많은 사람이 참석했다. "
    "AI 서버용 칩 공급 부족이 이어지면서 실적 개선 기대도 커지고 있다."
)


class NewsSummarizerTest(unittest.TestCase):

    def test_picks_keyword_and_number_sentences_in_original_order(self):
        summary = news_summarizer.summarize(ARTICLE, max_sentences=3)
        self.assertIn("15%", summary)
        self.assertIn("3조원", summary)
        self.assertNotIn("날씨", summary)
        self.assertLess(summary.index("15%"), summary.index("3조원"))

    def test_respects_max_length(self):
        summary = news_summarizer.summarize(ARTICLE, max_sentences=5, max_length=60)
        self.assertLessEqual(len(summary), 60)
        self.assertTrue(summary)

    def test_empty_text(self):
        self.assertEqual("", news_summarizer.summarize(""))
        self.assertEqual("", news_summarizer.summarize(None))

    def test_html_escapes(self):
        self.assertEqual("<p>A &lt; B &amp; C</p>", news_summarizer.to_html("A < B & C"))


if __name__ == "__main__":
    unittest.main()
