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

      { name: "Reported user", value: "[#{model.creator.at_name}](#{creator.url})", inline: true },
      { name: "Reporter", value: "[#{creator.at_name}](#{creator.url})", inline: true },

      { name: "", value: "", inline: false },
      { name: "Reason", value: reason.truncate(1000, omission: "[…]") },
    ]
  end

  def model_clickable_shortlink
    "[#{reported_content_shortlink}](#{reported_content_url})"
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
    "#{api.booru.url}/#{resource_name.pluralize}/#{id}"
  end

  def embed_timestamp
  end

  def buttons
    Discordrb::Webhooks::View.new.tap do |view|
      view.row do |row|
        row.button(
          label: "Mark as Handled",
          style: :danger,
          custom_id: "fumimi_moderation_report"
        )
      end
    end
  end
end
