require "test_helper"

class PostEmbedTest < Minitest::Test
  include TestMocks

  def setup
    @booru = setup_booru
    @event = event_mock("test")
    @tags = ["academic_test"]
  end

  def test_approver_report
    report = Fumimi::PostReport::ApproverReport.new(@event, @booru, @tags)

    assert report.table
  end

  def test_deleted_report
    report = Fumimi::PostReport::DeletedReport.new(@event, @booru, @tags)

    assert report.table
  end

  def test_modqueue_report
    report = Fumimi::PostReport::ModqueueReport.new(@event, @booru, @tags)

    assert report.description
  end

  def test_rating_report
    report = Fumimi::PostReport::RatingReport.new(@event, @booru, @tags)

    assert report.table
  end

  def test_upload_report
    report = Fumimi::PostReport::UploadReport.new(@event, @booru, @tags)

    assert report.table
  end

  def test_uploader_report
    report = Fumimi::PostReport::UploaderReport.new(@event, @booru, @tags)

    assert report.table
  end

  def test_search_report
    report = Fumimi::SearchReport.new(@event, @booru, @tags)

    assert report.description
  end
end
