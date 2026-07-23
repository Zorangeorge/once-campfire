class Messages::MarkdownPresentation
  def initialize(text, context:)
    @text, @context = text.to_s, context
  end

  def render
    return "" if text.blank?

    context.tag.div render_blocks.html_safe, class: "trix-content message__markdown"
  end

  private
    attr_reader :text, :context

    FENCE_PATTERN = /\A```.*\z/
    HEADING_PATTERN = /\A(\#{1,6})\s+(.+)\z/
    UNORDERED_LIST_PATTERN = /\A\s*[-+*]\s+(.+)\z/
    ORDERED_LIST_PATTERN = /\A\s*\d+[.)]\s+(.+)\z/
    BLOCKQUOTE_PATTERN = /\A>\s?(.*)\z/
    HORIZONTAL_RULE_PATTERN = /\A\s{0,3}([-*_])(?:\s*\1){2,}\s*\z/
    RAW_URL_PATTERN = %r{\bhttps?://[^\s<]+}
    MARKDOWN_LINK_PATTERN = /\[([^\]\n]+)\]\(([^)\s]+)\)/
    CODE_SPAN_PATTERN = /`([^`\n]+)`/
    TOKEN_PATTERN = "CAMPFIREMARKDOWNTOKEN%d"

    def render_blocks
      lines = normalized_lines
      blocks = []
      index = 0

      while index < lines.length
        line = lines[index]

        case
        when line.blank?
          index += 1
        when fenced_code_block?(line)
          block, index = render_fenced_code_block(lines, index)
          blocks << block
        when heading?(line)
          blocks << render_heading(line)
          index += 1
        when horizontal_rule?(line)
          blocks << "<hr>"
          index += 1
        when unordered_list_item?(line)
          block, index = render_list(lines, index, :unordered)
          blocks << block
        when ordered_list_item?(line)
          block, index = render_list(lines, index, :ordered)
          blocks << block
        when blockquote?(line)
          block, index = render_blockquote(lines, index)
          blocks << block
        else
          block, index = render_paragraph(lines, index)
          blocks << block
        end
      end

      blocks.join
    end

    def normalized_lines
      text.gsub("\r\n", "\n").gsub("\r", "\n").lines(chomp: true)
    end

    def render_fenced_code_block(lines, index)
      index += 1
      code_lines = []

      while index < lines.length && !fenced_code_block?(lines[index])
        code_lines << lines[index]
        index += 1
      end

      index += 1 if index < lines.length

      [ "<pre>#{escape_html(code_lines.join("\n"))}</pre>", index ]
    end

    def render_heading(line)
      match = line.match(HEADING_PATTERN)
      level = match[1].length

      "<h#{level}>#{render_inline(match[2].strip)}</h#{level}>"
    end

    def render_list(lines, index, type)
      tag_name = type == :ordered ? "ol" : "ul"
      item_pattern = type == :ordered ? ORDERED_LIST_PATTERN : UNORDERED_LIST_PATTERN
      items = []

      while index < lines.length && lines[index].match?(item_pattern)
        item_lines = [ lines[index].sub(item_pattern, "\\1") ]
        index += 1

        while index < lines.length && list_continuation_line?(lines[index])
          item_lines << lines[index].sub(/\A\s{2,4}/, "")
          index += 1
        end

        items << "<li>#{render_inline(item_lines.join("\n")).gsub("\n", "<br>")}</li>"
      end

      [ "<#{tag_name}>#{items.join}</#{tag_name}>", index ]
    end

    def render_blockquote(lines, index)
      quote_lines = []

      while index < lines.length && blockquote?(lines[index])
        quote_lines << lines[index].sub(BLOCKQUOTE_PATTERN, "\\1")
        index += 1
      end

      [ "<blockquote>#{render_inline(quote_lines.join("\n")).gsub("\n", "<br>")}</blockquote>", index ]
    end

    def render_paragraph(lines, index)
      paragraph_lines = []

      while index < lines.length && paragraph_line?(lines[index])
        paragraph_lines << lines[index]
        index += 1
      end

      [ "<p>#{render_inline(paragraph_lines.join("\n")).gsub("\n", "<br>")}</p>", index ]
    end

    def paragraph_line?(line)
      line.present? && !block_start?(line)
    end

    def block_start?(line)
      fenced_code_block?(line) || heading?(line) || horizontal_rule?(line) ||
        unordered_list_item?(line) || ordered_list_item?(line) || blockquote?(line)
    end

    def list_continuation_line?(line)
      line.present? && !block_start?(line)
    end

    def render_inline(value)
      tokens = []
      html = escape_html(value)

      html = replace_with_token(html, tokens, CODE_SPAN_PATTERN) do |match|
        "<code>#{match[1]}</code>"
      end

      html = replace_with_token(html, tokens, MARKDOWN_LINK_PATTERN) do |match|
        link_to_url(match[2], match[1]) || match[0]
      end

      html = replace_with_token(html, tokens, RAW_URL_PATTERN) do |match|
        escaped_url = match[0]
        raw_url = CGI.unescapeHTML(escaped_url)
        trailing_punctuation = raw_url.slice!(/[.,!?;:]+\z/) || ""

        if (link = link_to_url(raw_url, escape_html(raw_url)))
          link + escape_html(trailing_punctuation)
        else
          escaped_url
        end
      end

      html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
      html = html.gsub(/__(.+?)__/, '<strong>\1</strong>')
      html = html.gsub(/(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)/, '<em>\1</em>')
      html = html.gsub(/(?<!_)_(?!\s)(.+?)(?<!\s)_(?!_)/, '<em>\1</em>')

      restore_tokens(html, tokens)
    end

    def replace_with_token(html, tokens, pattern)
      html.gsub(pattern) do
        replacement = yield Regexp.last_match
        tokens << replacement

        TOKEN_PATTERN % (tokens.length - 1)
      end
    end

    def restore_tokens(html, tokens)
      tokens.each_with_index do |token, index|
        html = html.gsub(TOKEN_PATTERN % index, token)
      end

      html
    end

    def link_to_url(url, label)
      raw_url = CGI.unescapeHTML(url.to_s)
      return unless safe_url?(raw_url)

      escaped_url = escape_html(raw_url)
      %(<a href="#{escaped_url}" target="_blank" rel="noopener">#{label}</a>)
    end

    def safe_url?(url)
      uri = URI.parse(url)
      uri.scheme.in?(%w[ http https mailto ])
    rescue URI::Error
      false
    end

    def fenced_code_block?(line)
      line.match?(FENCE_PATTERN)
    end

    def heading?(line)
      line.match?(HEADING_PATTERN)
    end

    def unordered_list_item?(line)
      line.match?(UNORDERED_LIST_PATTERN)
    end

    def ordered_list_item?(line)
      line.match?(ORDERED_LIST_PATTERN)
    end

    def blockquote?(line)
      line.match?(BLOCKQUOTE_PATTERN)
    end

    def horizontal_rule?(line)
      line.match?(HORIZONTAL_RULE_PATTERN)
    end

    def escape_html(value)
      ERB::Util.html_escape(value).to_s
    end
end
