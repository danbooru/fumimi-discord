require "active_support"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/json"
require "active_support/core_ext/string/inflections"
require "addressable/uri"
require "ostruct"
require "time"

class Fumimi::Model
  include Fumimi::HasDiscordEmbed

  attr_reader :url, :attributes, :resource_name, :base_url, :fumimi, :booru

  delegate_missing_to :attributes

  def initialize(attributes:, resource_name:, fumimi:, booru: fumimi.booru)
    @fumimi = fumimi
    @booru = booru
    @resource_name = resource_name
    @base_url = booru.url.to_s

    attr_url = attributes.delete("url")
    @attributes = OpenStruct.new(attributes.to_h { |name, value| [name, cast_attribute(name, value)] })

    if attr_url.presence
      @url = attr_url
    elsif try(:id) && @base_url.present?
      @url = "#{@base_url}/#{resource_name.pluralize}/#{id}"
    end
  end

  def shortlink
    "#{resource_name.singularize.tr("_", " ")} ##{id}"
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

  def cast_attribute(name, value)
    if name =~ /_at$/
      Time.parse(value) rescue nil
    elsif name =~ /(^|_)url$/
      Addressable::URI.parse(value) rescue value
    elsif value.is_a?(Hash)
      name = Danbooru.map_attribute(name) || name
      booru.build_model(attributes: value, resource_name: name, booru: booru)
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
    when Array
      value.map { |item| serialize_attribute(item, options) }
    else
      value.as_json(options)
    end
  end
end
