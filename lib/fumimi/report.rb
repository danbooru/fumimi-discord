class Fumimi::Report
  include Fumimi::HasDiscordEmbed

  def initialize(booru:, log:)
    @booru = booru
    @log = log
  end

  def embed_timestamp
    Time.now
  end

  def embed_footer
    # TODO: Figure out how to detect if results ARE cached
    # "Results may be cached."
  end
end
