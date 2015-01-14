# Distinguished Name (DN) Converter

Convert multiple X509 DN strings into a consistent format.

## Installation

Add this line to your application's Gemfile:

    gem 'dnc'

And then execute:

    $ bundle

Or install it yourself with:

    $ gem install dnc

## Usage

To create a DN instance:

```ruby
require 'dnc'
dn = DN.new(dn_string: '/C=US/OU=string/O=DN/CN=Some Valid')
# Or:
dn = '/C=US/OU=string/O=DN/CN=Some Valid'.to_dn
dn = '/C=US/OU=string/O=DN/CN=Some Valid'.to_dn!
```

To return a consistently formatted string:

```ruby
dn.to_s
#=> 'CN=SOME VALID,O=DN,OU=STRING,C=US'
```

This is what a basic DN object looks like:

```yaml
puts dn.to_yaml
#=>
--- !ruby/object:DN
dn_string: CN=SOME VALID/O=DN/OU=STRING/C=US
original_dn: "/C=US/OU=string/O=DN/CN=Some Valid"
logger: !ruby/object:Logging::Logger
  [... snipped ...]
transformation: upcase
delimiter: "/"
cn: SOME VALID
o: DN
ou: STRING
c: US
string_order:
- cn
- l
- st
- o
- ou
- c
- street
- dc
- uid
```

There are multiple parameters you can pass in to modify the DN's formatting:

* `dn_string`: **REQUIRED** The DN string you want to parse into a DN object.
* `transformation`: `upcase`, `downcase`, `to_s` (or any valid String method).
* `delimiter`: Custom delimiter, DN auto detects if possible, but this forces it.
* `string_order`: DNC returns RDN elements as per LDAP specs ([RFC4514](http://www.rfc-editor.org/rfc/rfc4514.txt)), but to customize it you can send an array (of strings) to sort your `.to_s` results.  
  The default order is: `%w(cn l st o ou c street dc uid)`
* `logger`: Custom logger, defaults to Rails logger or Logging gem logger.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/dnc/fork )
2. Add specs and make them pass (see 3)
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
