# Fumimi

Fumimi is a Danbooru Discord bot.

## Installation

1. Go to https://discordapp.com/developers/applications/me
2. Click 'New App'
3. Choose an app name.
4. Note your client ID and client secret.
5. Add a bot user.
6. Save your bot token.
7. Invite bot to server.

1. `git clone https://github.com/evazion/fumimi-discord.git`
2. `bundle install`
3. Configure `.env`.
4. Run `bin/fumimi`

#### Big Query

1. https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud/v0.28.0/guides/authentication
2. https://console.developers.google.com/project
3. Create new project.
4. Go to API manager.
5. Find and enable the Big Query API.
6. Click Credentials in the sidebar.
7. Create service account and download .json keyfile.
8. Set GOOGLE_CLOUD_PROJECT in .env.
9. Set GOOGLE_CLOUD_KEYFILE_CONTENTS in .env.

gcloud auth application-default login

## Usage

Run `bin/fumimi` to start the bot. Use `/help` for a list of commands.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake test` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/danbooru/fumimi-discord.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
