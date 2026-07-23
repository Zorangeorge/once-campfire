require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  test "message presentation renders markdown for plain text messages" do
    message = Message.new(body: <<~MARKDOWN)
      :rocket: *New Release* - App v2

      *Release Date:* 2026-07-22T15:27:49Z

      *Download*
      Direct: https://localhost/download

      *Changelog*
      ## 🚀 Features
      - New feat 1
      - New feat 2
    MARKDOWN

    html = message_presentation(message)

    assert_includes html, '<div class="trix-content message__markdown">'
    assert_includes html, "<em>New Release</em>"
    assert_includes html, "<em>Release Date:</em> 2026-07-22T15:27:49Z"
    assert_includes html, '<a href="https://localhost/download" target="_blank" rel="noopener">https://localhost/download</a>'
    assert_includes html, "<h2>🚀 Features</h2>"
    assert_includes html, "<ul><li>New feat 1</li><li>New feat 2</li></ul>"
  end

  test "message presentation strips unsafe html before rendering markdown" do
    message = Message.new(body: 'Hello <img src=x onerror="alert(1)"> **World**')

    html = message_presentation(message)

    assert_includes html, "Hello  <strong>World</strong>"
    assert_no_match(/<img/i, html)
    assert_no_match(/onerror/i, html)
  end

  test "message presentation renders markdown code without linking or emphasizing it" do
    message = Message.new(body: <<~MARKDOWN)
      Run `https://example.com/*not-emphasis*`.

      ```
      **not strong**
      ```
    MARKDOWN

    html = message_presentation(message)

    assert_includes html, "<code>https://example.com/*not-emphasis*</code>"
    assert_includes html, "<pre>**not strong**</pre>"
    assert_no_match(%r{<code><a href="https://example\.com/}, html)
  end

  test "message presentation keeps rich text messages on the action text path" do
    message = Message.new(body: "<div>Hey #{mention_attachment_for(:david)}</div>")

    html = message_presentation(message)

    assert_includes html, '<div class="trix-content">'
    assert_includes html, '<div class="mention">'
    assert_includes html, "David"
    assert_no_match(/message__markdown/, html)
  end
end
