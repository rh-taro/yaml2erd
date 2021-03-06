# Yaml2erd

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/yaml2erd`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yaml2erd'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install yaml2erd

## Usage

### step1. you should install `graphviz` and `fonts`
**〜recommend using docker〜**

ex.

```
apt-get install -y graphviz task-japanese fonts-ipafont fonts-noto-cjk
```

### step2. create yaml (required)
examle: https://github.com/rh-taro/dockerized_yaml2erd#sample

sample path
`erd/table.yaml`

### step3. create conf (not required)
ex: https://github.com/rh-taro/dockerized_yaml2erd/blob/master/config/gv_conf.yaml

sample path
`config/gv_conf.yaml`

### step4. execute
```
mkdir erd
yaml2erd erd/table.yaml -c config/gv_conf.yaml -o erd/table.png
```

- `-c` option is config path
- `-o` option is outputed path

## you can notice the difference between ERD and DDL
- step1. get column info from yaml

```
parser = ErYamlParser.new('erd/table.yaml')
columns_hash_yaml = parser.models[:Post].columns
```

- step2. get column info from ActiveRecord

```
columns_hash_ar = Post.column_names
```

- step3. Write test code to compare these two

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/yaml2erd. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Yaml2erd project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/yaml2erd/blob/master/CODE_OF_CONDUCT.md).
