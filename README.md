# Sidekiq::Sqs

This is a gem that modifies Sidekiq to use Amazon's SQS as a job store.  It
still requires Redis for stats and such, and worker tracking.

It works currently. There's zero tests, and we're not using it in production, so
you might want to be careful.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-sqs'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-sqs

## Usage

Once the gem is required, (and aws-sdk is configured) simply do:

    Sidekiq::Sqs.enable!

That'll turn it all on. Nothing else _should_ have to change.

## Caveats

* Scheduling uses SQS message timers.  The amount of time you can schedule a worker must be 0 to 900 seconds (15 mins).
* ?

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
