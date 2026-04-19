class Fumimi::Button
  def self.mark_handled(event)
    return unless event.interaction.button.custom_id == "fumimi_user_report"

    new(event).mark_handled
  end

  def initialize(event)
    @event = event
    @button = event.interaction.button
    @old_embed = event.message.embeds.first
  end

  def mark_handled
    @event.update_message(
      embeds: [build_embed],
      components: build_view
    )
  end

  private

  def build_embed
    embed = Discordrb::Webhooks::Embed.new(
      title: @old_embed.title,
      description: @old_embed.description,
      color: embed_color
    )

    existing_fields.each do |field|
      embed.add_field(
        name: field.name,
        value: field.value,
        inline: field.inline
      )
    end

    if marking_handled?
      embed.add_field(
        name: "Handled by",
        value: "<@#{@event.user.id}>",
        inline: false
      )
    end

    embed
  end

  def build_view
    Discordrb::Webhooks::View.new.tap do |view|
      view.row do |row|
        row.button(
          label: button_label,
          style: button_style,
          custom_id: "user_report"
        )
      end
    end
  end

  def existing_fields
    @old_embed.fields.reject { |field| field.name == "Handled by" }
  end

  def marking_handled?
    @button.label == "Mark as Handled"
  end

  def button_label
    marking_handled? ? "Handled" : "Mark as Handled"
  end

  def button_style
    marking_handled? ? :success : :danger
  end

  def embed_color
    marking_handled? ? Fumimi::Colors::GREEN : Fumimi::Colors::RED
  end
end
