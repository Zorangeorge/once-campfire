require "application_system_test_case"

class EmojiTest < ApplicationSystemTestCase
  setup do
    sign_in "jz@37signals.com"
    join_room rooms(:designers)
  end

  test "picking an emoji from the picker" do
    composer.send_keys "Hot take "
    find(".composer__emoji-btn").click
    fill_in "Search emoji", with: "fire"
    find(".emoji-picker__emoji[aria-label='fire']").click

    assert_composer_text "Hot take 🔥"
    assert_no_selector ".emoji-picker__panel"

    click_on "send"
    assert_message_text "Hot take 🔥"
  end

  test "picking the first search result with enter" do
    find(".composer__emoji-btn").click
    fill_in "Search emoji", with: "thumbsup\n"

    assert_composer_text "👍"
  end

  test "escape closes the picker" do
    find(".composer__emoji-btn").click
    assert_selector ".emoji-picker__emoji"

    find(".emoji-picker__search").send_keys :escape
    assert_no_selector ".emoji-picker__panel"
  end

  test "arrow keys stay inside the picker" do
    find(".composer__emoji-btn").click
    fill_in "Search emoji", with: "heart"
    assert_selector ".emoji-picker__emoji[aria-label='red heart']"

    find(".emoji-picker__search").send_keys :down, :right, :up
    assert_selector ".emoji-picker__search:focus"
    assert_selector ".emoji-picker__panel"
  end

  test "choosing a suggested shortcode" do
    composer.send_keys ":fir"
    assert_selector "suggestion-option", text: ":fire:"

    composer.send_keys :tab, "hot"
    assert_composer_text "🔥 hot"
  end

  test "space dismisses suggestions without choosing one" do
    composer.send_keys ":fi"
    assert_selector "suggestion-option", text: ":fire:"

    composer.send_keys " later"
    assert_no_selector "suggestion-option"
    assert_composer_text ":fi later"
  end

  test "completed shortcodes turn into emoji as they're typed" do
    composer.send_keys "Ship it :rocket:"
    assert_composer_text "Ship it 🚀"
  end

  test "undoing a conversion keeps the shortcode as typed" do
    composer.send_keys "Ship it :rocket:"
    assert_composer_text "Ship it 🚀"

    composer.send_keys [ :control, "z" ], " now"
    assert_composer_text "Ship it :rocket: now"
  end

  test "times, emoticons and unknown shortcodes stay as typed" do
    composer.send_keys "See you at 10:30 :) :notanemoji:"
    assert_composer_text "See you at 10:30 :) :notanemoji:"
  end

  test "shortcodes work when editing a message" do
    within_message messages(:third) do
      reveal_message_actions
      find(".message__edit-btn").click
      find("trix-editor").send_keys :end, " :tada:"

      assert_selector "trix-editor", text: "🎉"
    end
  end

  private
    def composer
      find("#composer trix-editor")
    end

    def assert_composer_text(text)
      assert_selector "#composer trix-editor", exact_text: text
    end
end
