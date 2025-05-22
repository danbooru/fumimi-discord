require "active_support"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/json"
require "ostruct"
require "pp"

class Fumimi::Model
  attr_reader :api, :attributes

  delegate_missing_to :attributes

  def initialize(attributes, api = nil)
    @api = api
    self.attributes = attributes
  end

  def attributes=(attributes)
    @attributes = cast_attributes(attributes)
  end

  def resource_name
    api.name.singularize
  end

  def url
    "#{api.url}/#{id}"
  end

  def shortlink
    "#{resource_name} ##{id}"
  end

  def as_json(options = {})
    attributes.to_h.transform_values do |value|
      serialize_attribute(value, options)
    end
  end

  def embed_field_for(name, value, inline: true)
    Discordrb::Webhooks::EmbedField.new(inline: inline, name: name, value: value)
  end

  def embed_footer
    timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"
    Discordrb::Webhooks::EmbedFooter.new(text: timestamp)
  end

  def booru
    api.booru
  end

  alias_method :inspect, :pretty_inspect
  def pretty_print(printer)
    printer.pp("#<#{self.class.name}:0x#{object_id.to_s(16)}>" => attributes.to_h)
  end

  protected

  def cast_attributes(attributes)
    OpenStruct.new(attributes.map do |name, value|
      [name, cast_attribute(name, value)]
    end.to_h)
  end

  def cast_attribute(name, value)
    if name =~ /_at$/
      Time.parse(value) rescue nil
    elsif name =~ /(^|_)url$/
      Addressable::URI.parse(value) rescue value
    elsif value.is_a?(Hash)
      name = Danbooru.map_attribute(name) || name
      model = api.booru.factory[name.pluralize] || "Fumimi::Model::#{name.singularize.capitalize}".safe_constantize || Fumimi::Model
      model.new(value, api)
    elsif value.is_a?(Array)
      value.map { |item| cast_attribute(name, item) }
    else
      value
    end
  end

  def serialize_attribute(value, options = {})
    case value
    when Time
      value.iso8601(3)
    when Addressable::URI
      value.to_s
    when Fumimi::Model
      value.as_json(options)
    when Array
      value.map { |item| serialize_attribute(item, options) }
    else
      value.as_json(options)
    end
  end
end
