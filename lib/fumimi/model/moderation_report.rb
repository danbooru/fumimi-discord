require "fumimi/model"
require "active_support/core_ext/string/inflections"

class Fumimi::Model::ModerationReport < Fumimi::Model
  def embed_title
    "Danbooru Report ##{id}"
  end

  def embed_color
    Fumimi::Colors::RED
  end

  def embed_fields
    [
      { name: "Submitted at", value: created_at_relative, inline: true },
      { name: "Reported Content", value: model_clickable_shortlink, inline: true },

      { name: "", value: "", inline: false },
      { name: "Reported user", value: reported_user_clickable_shortlink, inline: true },
      { name: "Reporter", value: "[#{creator.at_name}](#{creator.url})", inline: true },

      { name: "", value: "", inline: false },
      { name: "Reason", value: reason.truncate(1000, omission: "[…]") },
    ]
  end

  def model_clickable_shortlink
    if model_type == "Dmail"
      "Dmail"
    else
      "[#{reported_content_shortlink}](#{reported_content_url})"
    end
  end

  def reported_user_clickable_shortlink
    if model.try(:creator).present? # missing for dmails
      "[#{model.creator.at_name}](#{model.creator.url})"
    else
      "Unknown"
    end
  end

  def reported_content_shortlink
    case model_type
    when "ForumPost"
      "forum ##{model_id}"
    else
      "#{model_type.underscore.tr("_", " ")} ##{model_id}"
    end
  end

  def reported_content_url
    "#{base_url}/#{model_type.underscore.pluralize}/#{model_id}"
  end

  def embed_timestamp
  end

  def buttons
    Discordrb::Webhooks::View.new.tap do |view|
      view.row do |row|
        row.button(
          label: "Mark as Handled",
          style: :danger,
          custom_id: "fumimi_moderation_report",
        )
      end
    end
  end
end
