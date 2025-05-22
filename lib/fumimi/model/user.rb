require "fumimi/model"
require "active_support/core_ext"

class Fumimi::Model::User < Fumimi::Model
  def embed(embed, channel) # rubocop:disable Lint/UnusedMethodArgument
    embed.title = at_name
    embed.url = url
    embed.color = discord_color

    embed.fields << embed_field_for("Level", is_banned ? "Banned" : level_string)
    embed.fields << embed_field_for("Created", "<t:#{created_at.to_time.to_i}:R>")
    embed.fields << embed_field_for("", "")

    embed.fields << embed_field_for("Uploads", upload_string)
    embed.fields << embed_field_for("Edits", edit_string)
    embed.fields << embed_field_for("Notes", note_string)

    embed.fields << embed_field_for("Forum posts", forum_string)
    embed.fields << embed_field_for("Comments", comment_string)

    embed
  end

  def at_name
    at_name = "@#{name}"
    at_name = "~~#{at_name}~~" if is_banned
    at_name
  end

  def feedback_string
    string = "#{positive_feedback_count}⇧ | #{neutral_feedback_count} | #{negative_feedback_count}⇩"
    link = "#{api.booru.url}/user_feedbacks?search[user_id]=#{id}"
    "[#{string}](#{link})"
  end

  def upload_string
    string = post_upload_count.to_fs(:delimited)
    link = "#{api.booru.url}/posts?tags=user:#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def edit_string
    string = post_update_count.to_fs(:delimited)
    link = "#{api.booru.url}/post_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def note_string
    string = note_update_count.to_fs(:delimited)
    link = "#{api.booru.url}/note_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def appeal_string
    string = appeal_count.to_fs(:delimited)
    link = "#{api.booru.url}/post_appeals?search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def flag_string
    string = flag_count.to_fs(:delimited)
    link = "#{api.booru.url}/post_flags?search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def wiki_string
    string = wiki_page_version_count.to_fs(:delimited)
    link = "#{api.booru.url}/wiki_page_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def artist_string
    string = artist_version_count.to_fs(:delimited)
    link = "#{api.booru.url}/artist_versions?search[updater_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def forum_string
    string = forum_post_count.to_fs(:delimited)
    link = "#{api.booru.url}/forum_posts?search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def comment_string
    string = comment_count.to_fs(:delimited)
    link = "#{api.booru.url}/comments?group_by=comment&search[creator_name]=#{CGI.escape(name)}"
    "[#{string}](#{link})"
  end

  def discord_color # rubocop:disable Metrics/CyclomaticComplexity
    return "0x000000" if is_banned

    case level_string
    in "Member" | "Restricted"
      0x0075F8
    in "Gold"
      0xFD9200
    in "Platinum"
      0x777892
    in "Builder" | "Contributor" | "Approver"
      0x6a09bf
    in "Moderator"
      0x00AB2C
    in "Admin" | "Owner"
      0xED2426
    else
      nil
    end
  end
end
