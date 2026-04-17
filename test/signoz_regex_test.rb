# frozen_string_literal: true

require "test_helper"

class SignozRegexTest < Minitest::Test
  include TestMocks

  # these must follow re2-compatible syntax
  TAG_PRESENCE_REGEX = SigNozClient.positive_tag_regex("touhou")
  TAG_EXCLUSION_REGEX = SigNozClient.negative_tag_regex("touhou")

  POSITIVE_CASES = [
    "touhou",
    "touhou",
    " touhou",
    "touhou ",
    " (touhou) ",
    "(touhou 1girl_(solo))",
    "(1girl_(solo) touhou)",
    "(1girl_(solo) touhou solo_(1girl))",
    "(1girl or touhou)",
    "touhou 1girl",
    "1girl touhou",
    "1girl touhou solo",
    "-1girl touhou",
    "touhou -1girl",
    "-1girl touhou -2girls",
    "(other tags) touhou (other tags)",
    # "-(other tags) touhou -(other tags)", # too complex to catch
    "solo -1girl -bara (1other or touhou)",
  ].freeze

  NEGATIVE_CASES = [
    "-touhou",
    "-(touhou)",
    "1girl -touhou",
    "-touhou 1girl",
    "1girl -touhou solo",
    "-(1girl or touhou)",
    "solo -(1girl or touhou)",
    # "solo -(1boy touhou or 1girl)", # too complex to catch
    "solo -(touhou or 1girl)",
    "solo -touhou -1girl -bara (1other or 1boy)",
  ].freeze

  WILD_CARD_CASES = [
    "*touhou*",
    "-*touhou*",
  ].freeze

  SUBSTRING_CASES = [
    "1girl_(touhou)",
    "1girl_(_touhou_)",
    "-1girl_(touhou)",
    "-1girl_(_touhou_)",
    "test 1girl_(touhou) test",
    "test -1girl_(touhou) test",
    "test touhou_tag test",
    "test -touhou_tag test",
    "test a_touhou_tag test",
    "test -a_touhou_tag test",
  ].freeze

  POSITIVE_CASES.each_with_index do |match_case, index|
    urlencoded = URI.encode_www_form_component(match_case).force_encoding("UTF-8")

    define_method("test_positive_regex_matches_positive_case_#{index}") do
      assert_match TAG_PRESENCE_REGEX, urlencoded, "On '#{match_case}'"
    end

    define_method("test_exclusion_regex_not_matches_positive_case_#{index}") do
      refute_match TAG_EXCLUSION_REGEX, urlencoded, "On '#{match_case}'"
    end
  end

  NEGATIVE_CASES.each_with_index do |match_case, index|
    urlencoded = URI.encode_www_form_component(match_case).force_encoding("UTF-8")

    define_method("test_positive_regex_not_matches_negative_case_#{index}") do
      refute_match TAG_PRESENCE_REGEX, urlencoded, "On '#{match_case}'"
    end

    define_method("test_exclusion_regex_matches_negative_case_#{index}") do
      assert_match TAG_EXCLUSION_REGEX, urlencoded, "On '#{match_case}'"
    end
  end

  WILD_CARD_CASES.each_with_index do |match_case, index|
    urlencoded = URI.encode_www_form_component(match_case).force_encoding("UTF-8")

    define_method("test_positive_regex_not_matches_wildcard_case_#{index}") do
      refute_match TAG_PRESENCE_REGEX, urlencoded, "On '#{match_case}'"
    end

    define_method("test_exclusion_regex_not_matches_wildcard_case_#{index}") do
      refute_match TAG_EXCLUSION_REGEX, urlencoded, "On '#{match_case}'"
    end
  end

  SUBSTRING_CASES.each_with_index do |match_case, index|
    urlencoded = URI.encode_www_form_component(match_case).force_encoding("UTF-8")

    define_method("test_positive_regex_not_matches_substring_case_#{index}") do
      refute_match TAG_PRESENCE_REGEX, urlencoded, "On '#{match_case}'"
    end

    define_method("test_exclusion_regex_not_matches_substring_case_#{index}") do
      refute_match TAG_EXCLUSION_REGEX, urlencoded, "On '#{match_case}'"
    end
  end
end
