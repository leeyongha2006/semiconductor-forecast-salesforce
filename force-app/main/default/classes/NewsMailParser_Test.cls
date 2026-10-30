@IsTest
private class NewsMailParser_Test {

    @IsTest
    static void extractsTitleAndFirstLink() {
        String html = '<ul>'
            + '<li><a href="https://news.example.com/a?id=1"><b>Packaging</b> demand&nbsp;up</a> '
            + '<a href="https://other.example.com">more</a></li>'
            + '<li>Second &amp; <a href=\'https://news.example.com/b\'>story</a></li>'
            + '</ul>';

        List<NewsMailParser.Headline> headlines = NewsMailParser.parse(html);

        Assert.areEqual(2, headlines.size());
        Assert.areEqual('Packaging demand up more', headlines[0].title);
        Assert.areEqual('https://news.example.com/a?id=1', headlines[0].url);
        Assert.areEqual('Second & story', headlines[1].title);
    }

    @IsTest
    static void skipsItemsWithoutLinkOrTitle() {
        String html = '<li>No link here</li><li><a href="https://news.example.com/x"></a></li>';
        Assert.isTrue(NewsMailParser.parse(html).isEmpty());
        Assert.isTrue(NewsMailParser.parse(null).isEmpty());
    }

    @IsTest
    static void cutsLongUrlAtQueryString() {
        String base = 'https://news.example.com/article/2026/10/30';
        String longUrl = base + '?utm=' + 'x'.repeat(300);
        Assert.areEqual(base, NewsMailParser.fitUrl(longUrl));
    }

    @IsTest
    static void dropsUrlThatCannotFit() {
        String longPath = 'https://news.example.com/' + 'a'.repeat(300);
        Assert.isNull(NewsMailParser.fitUrl(longPath));
    }
}
