/**
 * 뉴스 메일 본문(HTML)에서 기사 제목과 링크를 뽑는다.
 *
 * 메일은 기사마다 <li> 하나로 오고, 그 안의 첫 번째 링크가 기사 주소다.
 * 링크 저장 필드가 255자라서, 길면 쿼리 문자열을 잘라 보고 그래도 길면 버린다.
 */
public with sharing class NewsMailParser {

    public static final Integer MAX_URL_LENGTH = 255;

    private static final Pattern ITEM = Pattern.compile('(?is)<li[^>]*>(.*?)</li>');
    private static final Pattern HREF = Pattern.compile('(?i)href=["\']([^"\']+)["\']');

    public class Headline {
        public String title;
        public String url;

        public Headline(String title, String url) {
            this.title = title;
            this.url = url;
        }
    }

    public static List<Headline> parse(String html) {
        List<Headline> headlines = new List<Headline>();
        if (String.isBlank(html)) {
            return headlines;
        }
        Matcher items = ITEM.matcher(html);
        while (items.find()) {
            String content = items.group(1);
            Matcher href = HREF.matcher(content);
            String url = href.find() ? href.group(1) : null;
            String title = toPlainText(content);
            if (String.isNotBlank(title) && String.isNotBlank(url)) {
                headlines.add(new Headline(title, fitUrl(url)));
            }
        }
        return headlines;
    }

    /**
     * @return 255자 이하로 맞춘 주소, 맞출 수 없으면 null
     */
    public static String fitUrl(String url) {
        if (url.length() <= MAX_URL_LENGTH) {
            return url;
        }
        Integer queryStart = url.indexOf('?');
        if (queryStart > 0 && queryStart <= MAX_URL_LENGTH) {
            return url.substring(0, queryStart);
        }
        return null;
    }

    private static String toPlainText(String html) {
        return html.replaceAll('(?i)<[^>]+>', '')
            .replace('&nbsp;', ' ')
            .replace('&lt;', '<')
            .replace('&gt;', '>')
            .replace('&amp;', '&')
            .replaceAll('\\s+', ' ')
            .trim();
    }
}
