require "test_helper"

class ReportMonitorTest < ApplicationTest
  def test_send_report_truncates_overlong_reason_field
    report = moderation_report(id: 77, model_type: "Post", model_id: 123, reason: "a" * 1200)

    reason_field = report.embed_fields.find { |field| field[:name] == "Reason" }
    assert reason_field
    assert_equal 1000, reason_field[:value].length
    assert reason_field[:value].end_with?("[…]")
  end

  def test_send_report_includes_reporter_and_reported_user_links
    report = moderation_report(
      id: 88,
      model_type: "Comment",
      model_id: 999,
      creator_id: 10,
      creator_name: "reporter_name",
      reported_user_id: 20,
      reported_user_name: "reported_name",
    )

    fields = report.embed_fields
    reported_user_field = fields.find { |f| f[:name] == "Reported user" }
    reporter_field = fields.find { |f| f[:name] == "Reporter" }

    assert_equal "[@reported_name](https://danbooru.donmai.us/users/20)", reported_user_field[:value]
    assert_equal "[@reporter_name](https://danbooru.donmai.us/users/10)", reporter_field[:value]
  end

  def test_send_report_includes_reported_content_link_for_forum_posts
    report = moderation_report(id: 99, model_type: "ForumPost", model_id: 123)

    reported_content_field = report.embed_fields.find { |field| field[:name] == "Reported Content" }

    assert_equal "[forum #123](https://danbooru.donmai.us/forum_posts/123)", reported_content_field[:value]
  end

  def test_send_report_includes_reported_content_link_for_comments
    report = moderation_report(id: 100, model_type: "Comment", model_id: 456)

    reported_content_field = report.embed_fields.find { |field| field[:name] == "Reported Content" }

    assert_equal "[comment #456](https://danbooru.donmai.us/comments/456)", reported_content_field[:value]
  end

  def moderation_report(id:,
                        model_type:,
                        model_id:,
                        reason: "ok",
                        creator_id: 1,
                        creator_name: "reporter",
                        reported_user_id: 2,
                        reported_user_name: "reported_user")
    Fumimi::Model::ModerationReport.new(
      attributes: {
        "id" => id,
        "created_at" => "2026-04-20T00:00:00Z",
        "model_type" => model_type,
        "model_id" => model_id,
        "reason" => reason,
        "creator" => { "id" => creator_id, "name" => creator_name },
        "model" => { "creator" => { "id" => reported_user_id, "name" => reported_user_name } },
      },
      resource_name: "moderation_report",
      fumimi: default_fumimi,
    )
  end
end
