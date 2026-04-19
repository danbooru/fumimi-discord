require "active_support"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/json"
require "ostruct"

class Fumimi::Model
  include Fumimi::HasDiscordEmbed

  attr_reader :url, :attributes, :parent, :api, :resource_name

  delegate_missing_to :attributes

  def initialize(attributes, resource_name, api = nil, parent = nil)
    @api = api
    @parent = parent
    @resource_name = resource_name

    attr_url = attributes.delete("url")
    self.attributes = attributes

    if attr_url.presence
      @url = attr_url
    elsif try(:id)
      @url = "#{api.booru.url}/#{resource_name.pluralize}/#{id}"
    end
  end

  def attributes=(attributes)
    @attributes = cast_attributes(attributes)
  end

  def shortlink
    "#{resource_name.singularize.tr("_", " ")} ##{id}"
  end

  def clickable_shortlink
    "[#{shortlink}](#{url})"
  end

  def created_at_relative
    "<t:#{created_at.to_time.to_i}:R>"
  end

  def as_json(options = {})
    attributes.to_h.transform_values do |value|
      serialize_attribute(value, options)
    end
  end

  def embed_url
    url
  end

  def embed_title
    shortlink
  end

  def embed_timestamp
    try(:created_at)
  end

  def booru
    @api.booru
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
      model = "Fumimi::Model::#{name.singularize.camelize}".safe_constantize || Fumimi::Model
      model.new(value, name, api, self)
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

  def nsfw_channel?
    @parent&.nsfw_channel? || @nsfw_channel
  end
end
