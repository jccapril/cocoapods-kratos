require 'tmpdir'
module Pod
  class Command
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
          %w[--mixup 开启构建时代码混淆功能.],
          ['--force',     'Overwrite existing files.']
        ]
      end

      def initialize(argv)
        @name = argv.shift_argument
        @source = argv.shift_argument
        @force = argv.flag?('force')
        @spec = spec_with_path(@name)
        # @is_spec_from_path = true if @spec
        @spec ||= spec_with_name(@name)
        # 代码混淆配置项
        @mixup = argv.flag?('mixup', false)
        @old_class_prefix = argv.option('old-class-prefix', 'BT')
        @new_class_prefixes = argv.option('new-class-prefixes', 'MNL').split(',')
        @filter_file_prefixes = argv.option('filter-file-prefixes', 'Target_,').split(',')

        super
      end

      def validate!
        super
        help! 'A podspec name or path is required.' unless @spec
      end

      def run

        UI.puts "The name of the Pod is #{@name}"
        UI.puts "The spec of the Pod is #{@spec}".red

        build_with_mixup if @mixup

      end


       # 构建时进行代码混淆
       def build_with_mixup

        # JRCodeMixup.new(@spec.name, Dir.pwd, @old_class_prefix, @new_class_prefixes, @filter_file_prefixes, @from_wukong)
        #          .run do |des_path, mixup, new_spec_file|
        #   UI.puts "Mixup: The des_path is #{@des_path}".blue
        #   UI.puts "Mixup: The mixup is #{@mixup}".yellow
        #   UI.puts "Mixup: The new_spec_file is #{@new_spec_file}".green
        # end

        JRCodeMixup.new(@spec.name, Dir.pwd, @old_class_prefix, @new_class_prefixes, @filter_file_prefixes)
                 .run do |des_path, mixup, new_spec_file|
          # 同步更新本地配置文件
          # @spec = spec_with_path(new_spec_file)
          # build_mixup
          # `rm -rf #{des_path}`
          # `rm #{new_spec_file}`
          # `rm -rf .tmp` if Dir.exist?('.tmp')
          # mixup.append_subspec
        end

       end


    end
  end
end
