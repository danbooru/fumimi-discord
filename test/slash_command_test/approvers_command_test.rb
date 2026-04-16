require "test_helper"

class ApproversCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/approvers", args: { tags: "1girl age:<1d" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Approver Report", report.title
    assert_match(/Requested by <@/, report.description)

    table_lines = table_lines_for(report)

    assert_equal ["Name", "Approvals", "%"], table_lines.first
  end

  def test_no_results
    mock_slash_command("/approvers", args: { tags: ")" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first

    assert_equal "Approver Report", report.title
    assert_equal report.description, <<~EOF.chomp
      -# Tags: `) approver:any`

      No posts under that search!
    EOF

    assert_equal [], table_lines_for(report)
  end
end
