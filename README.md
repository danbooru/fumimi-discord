# Fumimi

Fumimi is a Danbooru Discord bot.

## Bot Creation

1. Go to https://discordapp.com/developers/applications/me
2. Click 'New App'
3. Choose an app name.
4. Note your client ID and client secret.
5. Add a bot user.
6. Save your bot token.
7. Invite bot to server.

## Manual Installation

1. `git clone https://github.com/danbooru/fumimi-discord.git`
2. Configure `.env` from `.env.local`
3. `bundle install`
4. Run `bin/fumimi`

## Installation with Docker

1. `git clone https://github.com/danbooru/fumimi-discord.git`
2. Configure `.env` from `.env.local`
3. Run `docker build . -t fumimi-discord`
4. Run `docker run --rm --env-file=.env fumimi-discord`


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
