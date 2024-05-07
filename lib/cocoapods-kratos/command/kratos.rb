module Pod
  class Command
    # This is an example of a cocoapods plugin adding a top-level subcommand
    # to the 'pod' command.
    #
    # You can also create subcommands of existing or new commands. Say you
    # wanted to add a subcommand to `list` to show newly deprecated pods,
    # (e.g. `pod list deprecated`), there are a few things that would need
    # to change.
    #
    # - move this file to `lib/pod/command/list/deprecated.rb` and update
    #   the class to exist in the the Pod::Command::List namespace
    # - change this class to extend from `List` instead of `Command`. This
    #   tells the plugin system that it is a subcommand of `list`.
    # - edit `lib/cocoapods_plugins.rb` to require this file
    #
    # @todo Create a PR to add your plugin to CocoaPods/cocoapods.org
    #       in the `plugins.json` file, once your plugin is released.
    #
    class Kratos < Command
      self.summary = 'Short description of cocoapods-kratos.'

      self.description = <<-DESC
        Longer description of cocoapods-kratos.
      DESC

      self.arguments = [
        CLAide::Argument.new('NAME', true),
        CLAide::Argument.new('SOURCE', false)
      ]

      def self.options
        [
          ['--force',     'Overwrite existing files.'],
        ]
      end

      def initialize(argv)
        @name = argv.shift_argument
        @source = argv.shift_argument
        @force = argv.flag?('force')

        @spec = spec_with_path(@name)
        super
      end

      def validate!
        super
        help! 'A Pod name is required.' unless @name
      end

      def run
        UI.puts "Add your implementation for the cocoapods-kratos plugin in #{__FILE__}"
        UI.puts "The name of the Pod is #{@name}"
        UI.puts "The spec of the Pod is #{@spec}"
        if @source
          UI.puts "The source of the Pod is #{@source}"
        end
        if @force
          UI.puts "Overwrite existing files".red
        else
          UI.puts "Not overwrite existing files".blue
        end
      end
    end
  end
end
