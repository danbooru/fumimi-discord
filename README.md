# Fumimi

Fumimi is a Danbooru Discord bot. It can be seen at work in the [official Danbooru discord](https://discord.gg/danbooru).

## Installation

### 1. Discord Bot Creation

1. Go to https://discordapp.com/developers/applications/me
2. Click 'New App'
3. Choose an app name.
4. Note your client ID and client secret.
5. Add a bot user.
6. Save your bot token.
7. Invite bot to server.

### 2. Configure Your Credentials

1. Clone this repository: `git clone https://github.com/danbooru/fumimi-discord.git`
2. Configure `.env` from `.env.example`

### 3a. Run with Docker
1. Run `docker run --rm --env-file=.env ghcr.io/danbooru/fumimi-discord`

### 3b. Run manually
1. Run `bundle install`
2. Run `bin/fumimi`

## Usage

Use `/help` on a server the bot is configured on for a list of commands.

## Development

After cloning this repo, run `bundle install` to install dependencies.
To run the tests use `bundle exec rake test`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/danbooru/fumimi-discord.

## License

This bot is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
