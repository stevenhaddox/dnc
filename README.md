# Distinguished Name (DN) Converter

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dnc'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dnc

## Usage

```ruby
require 'dnc'
dn_string = 'CN=Some Valid, O=DN, OU=string'
dn = DN.new(dn_string: dn_string)
# Or:
dn_string.to_dn
# And:
dn_string.to_dn.to_s
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/dnc/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
