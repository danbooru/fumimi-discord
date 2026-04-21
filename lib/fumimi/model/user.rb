require "fumimi/model"
require "active_support/core_ext"

class Fumimi::Model::User < Fumimi::Model
  module Levels
    ANONYMOUS = 0
    RESTRICTED = 10
    MEMBER = 20
    GOLD = 30
    PLATINUM = 31
    BUILDER = 32
    CONTRIBUTOR = 35
    APPROVER = 37
    MODERATOR = 40
    ADMIN = 50
    OWNER = 60
  end

  LEVEL_MAP = Levels.constants.to_h do |c|
    [c, Levels.const_get(c)]
  end

  def embed_fields
    embed_fields = []
    embed_fields << { name: "Level", value: level_string, inline: true }
    embed_fields << { name: "Created", value: created_at_relative, inline: true }
    embed_fields << { name: "Feedbacks", value: feedback_string, inline: true }

    embed_fields << { name: "Uploads", value: upload_string, inline: true }
    embed_fields << { name: "Edits", value: edit_string, inline: true }
    embed_fields << { name: "Notes", value: note_string, inline: true }

    embed_fields << { name: "Forum posts", value: forum_string, inline: true }
    embed_fields << { name: "Comments", value: comment_string, inline: true }
    embed_fields << { name: "Wikis", value: wiki_string, inline: true }

    embed_fields
  end

  def embed_timestamp
  end

  def embed_title
    is_banned ? "~~#{at_name}~~" : at_name
  end

  def embed_color # rubocop:disable Metrics/CyclomaticComplexity
    return "0x000000" if is_banned

    case level_string
    in "Member" | "Restricted"
      Fumimi::Colors::BLUE
    in "Gold"
      Fumimi::Colors::YELLOW
    in "Platinum"
      Fumimi::Colors::GREY
    in "Builder" | "Contributor" | "Approver"
      Fumimi::Colors::PURPLE
    in "Moderator"
      Fumimi::Colors::GREEN
    in "Admin" | "Owner"
      Fumimi::Colors::RED
    else
      nil
    end
  end

  def at_name
    "@#{name}"
  end

  def upload_string
    string = post_upload_count.to_fs(:delimited)
    link = "#{base_url}/posts?tags=user:#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def edit_string
    string = post_update_count.to_fs(:delimited)
    link = "#{base_url}/post_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def note_string
    string = note_update_count.to_fs(:delimited)
    link = "#{base_url}/note_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def forum_string
    string = forum_post_count.to_fs(:delimited)
    link = "#{base_url}/forum_posts?search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def comment_string
    string = comment_count.to_fs(:delimited)
    link = "#{base_url}/comments?group_by=comment&search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def wiki_string
    string = wiki_page_version_count.to_fs(:delimited)
    link = "#{base_url}/wiki_page_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def appeal_string
    string = appeal_count.to_fs(:delimited)
    link = "#{base_url}/post_appeals?search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def artist_string
    string = artist_version_count.to_fs(:delimited)
    link = "#{base_url}/artist_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def feedback_string
    string = "#{positive_feedback_count} | #{neutral_feedback_count} | #{negative_feedback_count * -1}"
    link = "#{base_url}/user_feedbacks?search[user_id]=#{id}"
    "[#{string}](#{link})"
  end
end
