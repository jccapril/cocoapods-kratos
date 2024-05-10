require 'tmpdir'
module Pod
  class Command
    class Kratos < Command
      self.summary = 'Short description of cocoapods-kratos.'

      self.description = <<-DESC
        Longer description of cocoapods-kratos.
      DESC

      self.arguments = [
        CLAide::Argument.new('NAME', true)
      ]

      def self.options
        [
          %w[--archs 生成的架构.默认为：`arm64`],
          %w[--local 使用本地版本构建.],
          %w[--mixup 开启构建时代码混淆功能.],
          %w[--old-class-prefix 混淆时修改的类前缀.默认为：`BT`],
          %w[--new-class-prefixes 混淆时要修改的目标类前缀，多个用,隔开.默认为：`MNL`],
          %w[--filter-file-prefixes 混淆时要忽略的文件前缀，多个用,隔开.默认为：`Target_`],
          %w[--no-clean 构建失败不清除构建工程.],
          %w[--clean-cache 构建时清除本地所有的组件缓存.⚠️注意：开启后会重新下载所有组件],
          ['--embedded',  'Generate embedded frameworks.'],
          ['--library',   'Generate static libraries.'],
          ['--dynamic',   'Generate dynamic framework.'],
          %w[--upgrade-swift 升级Swift版本]
        ]
      end

      def initialize(argv)
        @name = argv.shift_argument
        @spec = spec_with_path(@name)
        @is_spec_from_path = true if @spec
        @spec ||= spec_with_name(@name)


        @local = argv.flag?('local', false)
        @archs = argv.option('archs', 'arm64').split(',')
        @clean_sandbox = argv.flag?('clean', true)

        @embedded = argv.flag?('embedded')
        @library = argv.flag?('library')
        @dynamic = argv.flag?('dynamic')

        @package_type = if @embedded
                          :static_framework
                        elsif @dynamic
                          :dynamic_framework
                        elsif @library
                          :static_library
                        else
                          :static_framework
                        end

        # 代码混淆配置项
        @mixup = argv.flag?('mixup', false)
        @old_class_prefix = argv.option('old-class-prefix', 'BT')
        @new_class_prefixes = argv.option('new-class-prefixes', 'MNL').split(',')
        @filter_file_prefixes = argv.option('filter-file-prefixes', 'Target_,').split(',')

        # 更新本地缓存
        @clean_cache = argv.flag?('clean-cache', false)

        # 升级Swift版本
        @upgrade_swift_packager = argv.flag?('upgrade-swift', false)

        @swift_version = local_swift_version

        super
      end

      def local_swift_version
        _, stdout, _ = Open3.popen3('xcrun swift --version')
        stdout.gets.to_s.gsub(/version (\d+(\.\d+)+)/).to_a[0].split(' ')[1]
      end

      def validate!
        super
        help! 'A podspec name or path is required.' unless @spec
        help! '--local option can only be used when a local `.podspec` path is given.' if @local && !@is_spec_from_path
      end

      def run

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
