# SidekiqHerokuScaler

Tool to autoscale sidekiq dynos on Heroku. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-heroku-scaler'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-heroku-scaler

## Usage

### Strategy

Create strategy instance (gem strategy based on latency):
```
scale_strategy = SidekiqHerokuScaler::Strategy::Latency.new(
  min_dynos_count: 1,
  max_dynos_count: 10,
  max_latency: 5.minutes.to_i,
  min_latency: 1.minute.to_i,
  inc_count: 2, # default 1
  dec_count: 2 # default 1
)
```
or

define your own strategy:
```
class CustomStrategy
  def increase?(sidekiq_worker)
    # TODO
  end 
	
  def decrease?(sidekiq_worker)
    # TODO
  end
end
```

methods `increase?/decrease?` are required, these methods provide logic to handle additing or removing sidekiq instance.

### Manager

To run iteration
```
SidekiqHerokuScaler::Manager.new(
  heroku_app_name: HEROKU_APP_NAME,
  heroku_token: HEROKU_TOKEN,
  strategy: scale_strategy,
  workers: SIDEKIQ_AUTOSCALE_WORKERS
).perform
```

where:
- `HEROKU_APP_NAME` - Heroku app name
- `HEROKU_TOKEN` - Heroku token
- `strategy` - scale strategy
- `workers` - array of sidekiq worker names that could be scaled

### Recurring

1) Implement rake task and use [Heroku Scheduler](https://devcenter.heroku.com/articles/scheduler)
2) To more frequently run use [Sidekiq Scheduler](https://github.com/moove-it/sidekiq-scheduler)

###### `config/sidekiq_scheduler.yml`
```
sidekiq_autoscale:
  cron: '0 */5 * * * *'
  class: Scheduling::SidekiqAutoscaleWorker
  queue: autoscale
  description: 'This job autoscale sidekiq Heroku dynos'
```

###### `Scheduling::SidekiqAutoscaleWorker`
```
module Scheduling
  class SidekiqAutoscaleWorker
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform
      SidekiqHerokuScaler::Manager.new(
        heroku_app_name: ENV['HEROKU_APP_NAME'],
        heroku_token: ENV['HEROKU_TOKEN'],
        strategy: scale_strategy,
        workers: %w[worker]
      ).perform
    end
end    
```

## TODO

- Lack of specs
- More documentation

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
