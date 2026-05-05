require "test_helper"

class ReportCommandTest < ApplicationTest
  def test_submits_report_to_mod_channel
    fumimi = default_fumimi
    event_channel = ChannelMock.new(name: "#test")
    fumimi.define_singleton_method(:report_channel) { event_channel }

    response = mock_slash_command("/report", args: { reason: "spam links" }, fumimi:)
    response => { replies:, embeds:, ** }

    assert_equal ["Your report has been submitted."], replies
    assert_equal [""], event_channel.messages

    assert_equal 1, event_channel.embeds.length
    report = event_channel.embeds.first
    assert_equal "Discord Report", report.title

    fields = report.fields.index_by(&:name)
    assert_equal "<@123>", fields.fetch("Reporter").value
    assert_equal "spam links", fields.fetch("Reason").value
  end

  def test_rejects_reason_over_1000_characters
    mock_slash_command("/report", args: { user_id: 42, reason: "a" * 1001 }) => { reply_embeds:, messages: }

    assert_equal [], messages
    assert_equal 1, reply_embeds.length

    error = reply_embeds.first
    assert_equal "Bad Argument!", error.title
    assert_equal "Reason must be below 1000 characters.", error.description.to_s
  end
end
