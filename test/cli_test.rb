require "test_helper"

class CLITest < ApplicationTest
  def cli(*argv, env: {})
    stdout = StringIO.new
    stderr = StringIO.new
    cli = Fumimi::CLI.new(argv, env: env, stdout: stdout, stderr: stderr)
    [cli, stdout, stderr]
  end

  def test_help_flag_prints_usage
    cli, stdout, _stderr = cli("--help")
    success = cli.run!

    assert_equal(true, success)
    assert_match(/Usage:/, stdout.string)
  end

  def test_invalid_option_prints_error
    cli, _stdout, stderr = cli("--invalid-option")
    success = cli.run!

    assert_equal(false, success)
    assert_match(/invalid option/, stderr.string)
  end

  def test_run_returns_error_when_required_env_vars_missing
    cli, _stdout, stderr = cli(env: {})
    success = cli.run!

    assert_equal(false, success)
    assert_match(/Error:/, stderr.string)
  end
end
