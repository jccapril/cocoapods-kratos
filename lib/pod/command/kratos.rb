require 'tmpdir'
module Pod
  class Command
    class Kratos < Command
      self.summary = '混淆、制作二进制库.'

      self.description = <<-DESC
        混淆、制作二进制库.
      DESC

      self.arguments = [
        CLAide::Argument.new('NAME', true),
        CLAide::Argument.new('SOURCE', true)
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
          %w[--beta 构建beta组件],
          %w[--force 强制覆盖已存在的文件.],
          %w[--use-framework 基于framework仓库构建],
          %w[--spec-sources 依赖组件的第三方仓库.默认为：https://cdn.cocoapods.org/],
          ['--embedded',  'Generate embedded frameworks.'],
          ['--library',   'Generate static libraries.'],
          ['--dynamic',   'Generate dynamic framework.'],
          %w[--upgrade-swift 升级Swift版本]
        ]
      end

      def initialize(argv)
        @name = argv.shift_argument
        @source = argv.shift_argument
        @spec_sources = argv.option('spec-sources', 'https://cdn.cocoapods.org/').split(',')

        @source_dir = Dir.pwd
        @is_spec_from_path = false
        @spec = spec_with_path(@name)
        @is_spec_from_path = true if @spec
        @spec ||= spec_with_name(@name)
        @force = argv.flag?('force', false)
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

        @use_framework = argv.flag?('use-framework', false)

        @beta_version_packager = argv.flag?('beta', false)

        # # 升级Swift版本
        @upgrade_swift_packager = argv.flag?('upgrade-swift', false)

        @swift_version = local_swift_version

        super
      end

      def local_swift_version
        _, stdout, _ = Open3.popen3('xcrun swift --version')
        stdout.gets.to_s.gsub(/version (\d+(\.\d+)+)/).to_a[0].split(' ')[1]
      end


      def swift_version_support?
        @swift_version.gsub(/\d+\.\d+/).to_a[0].gsub('.', '').to_i >= 59
      end

      def is_swift_library?
        content = File.open(@name).read.to_s
        !content.gsub(/source_files.*=.*.swift/).to_a.empty?
      end

      def validate!
        super
        help! 'A podspec name or path is required.' unless @spec
        help! '--local option can only be used when a local `.podspec` path is given.' if @local && !@is_spec_from_path
      end

      def run

        begin_time = (Time.now.to_f * 1000).to_i

        @zip_files = []

        version = @spec.attributes_hash['version']
        version = version.split('.swift')[0] if version.include?('.swift')

        if @upgrade_swift_packager && swift_version_support? && is_swift_library?
          @version = version
        else
          # 自增版本号
          @version = increase_number(version)
        end

        # 处理Swift版本
        @version = "#{@version}.swift-#{@swift_version}" if swift_version_support? && is_swift_library?

        UI.puts "-> current version is [#{@version}]".red

        unless @mixup
          build
        end
        build_with_mixup if @mixup

        end_time = (Time.now.to_f * 1000).to_i
        duration = end_time - begin_time
        UI.puts "-> 组件构建完成 [#{duration / 1000.0} sec]".green

      end


      # 构建时进行代码混淆
      def build_with_mixup

        JRCodeMixup.new(@spec.name, Dir.pwd, @old_class_prefix, @new_class_prefixes, @filter_file_prefixes)
                 .run do |des_path, mixup, new_spec_file|
          # 同步更新本地配置文件
          @spec = spec_with_path(new_spec_file)
          build
          `rm -rf #{des_path}`
          `rm #{new_spec_file}`
          `rm -rf .tmp` if Dir.exist?('.tmp')
          # mixup.append_subspec
        end

      end

      # 版本号自增
      def increase_number(number)
        # beta
        # e.g. 100.b1 自增为 100.b2
        if @beta_version_packager
          new_version = "#{number}.b1"
          if number.include?('.b')
            v = number.split('.b')[0]
            b_v = number.split('.b')[1].to_i
            b_v += 1
            new_version = "#{v}.b#{b_v}"
          end
          return new_version
        end

        # 先转 int ，对其+1，再转为字符串
        number = number.split('.b')[0] if number.include?('.b')

        numbers = number.split('.')
        count = numbers.length
        case count
        when 1 then (number.to_i + 1).to_s
        else (numbers.join('').to_i + 1).to_s.split('').join('.')
        end
      end

      # 构建
      def build
        @target_dir, @work_dir = create_working_directory
        return if @target_dir.nil?

        build_package
        `mv "#{@work_dir}" "#{@target_dir}"`
        Dir.chdir(@source_dir)
      end

      def create_target_directory
        target_dir = "#{@source_dir}/#{@spec.name}-#{@spec.version}"
        if File.exist? target_dir
          if @force
            Pathname.new(target_dir).rmtree
          else
            UI.puts "Target directory '#{target_dir}' already exists."
            return nil
          end
        end
        target_dir
      end

      def create_working_directory
        target_dir = create_target_directory
        return if target_dir.nil?

        work_dir = Dir.tmpdir + '/cocoapods-' + Array.new(8) { rand(36).to_s(36) }.join
        Pathname.new(work_dir).mkdir
        Dir.chdir(work_dir)

        [target_dir, work_dir]
      end

      def build_package
        builder = SpecBuilder.new(@spec, @source, @embedded, @dynamic)
        newspec = builder.spec_metadata

        @spec.available_platforms.each do |platform|
          build_in_sandbox(platform)

          newspec += builder.spec_platform(platform)
        end

        newspec += builder.spec_close
        File.open(@spec.name + '_Framework.podspec', 'w') { |file| file.write(newspec) }
      end


      def build_in_sandbox(platform)
        config.installation_root  = Pathname.new(Dir.pwd)
        config.sandbox_root       = 'Pods'

        UI.puts "-> 依赖检查...".yellow
        begin_time = (Time.now.to_f * 1000).to_i
        static_sandbox = build_static_sandbox(@dynamic)
        config.silent = true
        static_installer = install_pod(platform.name, static_sandbox, @use_framework)

        if @dynamic
          dynamic_sandbox = build_dynamic_sandbox(static_sandbox, static_installer)
          install_dynamic_pod(dynamic_sandbox, static_sandbox, static_installer, platform)
        end
        config.silent = false
        end_time = (Time.now.to_f * 1000).to_i
        duration = end_time - begin_time
        UI.puts "-> 依赖检查完成 [#{duration / 1000.0} sec]".green
      end


      def build_static_sandbox

      end

    end
  end
end
