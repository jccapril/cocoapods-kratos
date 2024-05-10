module Pod
  # 混淆代码
  class JRCodeMixup

    # 初始化
    def initialize(spec_name, source_path, old_class_prefix, new_class_prefixes, filter_file_prefixes = ['Target_'])
      @source_path = source_path
      @old_class_prefix = old_class_prefix
      @new_class_prefixes = new_class_prefixes
      @new_class_prefix = @new_class_prefixes.first
      @filter_file_prefixes = filter_file_prefixes
      @spec_name = spec_name
      @spec_file = "#{@source_path}/#{@spec_name}.podspec"

      @code_dir = "#{@source_path}/#{@spec_name}"
    end

    def run
      clean_mixup_config_in_podspec
      @new_class_prefixes.each do |new_class_prefix|
        @new_class_prefix = new_class_prefix
        @des_path = mixup
        yield @des_path, self, @new_spec_file
      end
    end


    # 删除已配置的混淆参数，需要根据最新构建自动生成
    def clean_mixup_config_in_podspec
      content = File.open(@spec_file).read.to_s
      if content.include?("if ENV['")
        content.gsub!(/# 以下为脚本依赖CoreFramework自动生成代码，勿动⚠️⚠️ 如CoreFramework有改动请删除。[\w\W]*?\bend[\w\W]*?end/, '')
      else
        content.gsub!(/# 以下为脚本依赖CoreFramework自动生成代码，勿动⚠️⚠️ 如CoreFramework有改动请删除。[\w\W]*?\bend/, '')
      end

      zip_file_path = <<~CONTENT
        end

          s.subspec
      CONTENT
      content.gsub!(/\bend\W*?\bs.subspec/, zip_file_path.chomp)

      File.open(@spec_file, 'w') { |fw| fw.write(content) }
    end

    # 混淆类配置项
    def mixup_config
      @old_class_prefix = 'BT'
      @new_class_prefixes = ['MNL']
      @new_class_prefix = @new_class_prefixes.first
      @filter_file_prefixes = ['Target_']
    end

    # 执行混淆
    def mixup
      @new_spec_name = @spec_name.gsub(@old_class_prefix, @new_class_prefix)
      @des_path = "#{@source_path}/.tmp/#{@new_spec_name}"

      # 移除旧的文件夹
      `rm -rf #{@des_path}` if Dir.exist?(@des_path)
      # 创建新的文件夹
      `mkdir #{@source_path}/.tmp/`

      # 拷贝到新的文件夹
      `cp -r -P #{@code_dir} #{@des_path}`

      Dir.chdir(@des_path)

      begin_time = (Time.now.to_f * 1000).to_i

      # 混淆代码
      mix_code

      # 混淆文件夹
      mix_dirs

      # 混淆图片资源
      mix_images_hash

      # 混淆podspec文件
      mix_podspec

      end_time = (Time.now.to_f * 1000).to_i
      duration = end_time - begin_time

      puts "-> 混淆处理完成 [#{duration / 1000.0} sec]".green

      @des_path
    end

    MixupFile = Struct.new(:name, :new_name, :path, :new_path, :contents, :is_not_in_filter)

    # 混淆代码
    def mix_code
      begin_time = (Time.now.to_f * 1000).to_i
      # 搜索代码文件
      @files = Dir.glob("**/*.{h,m,swift}").map { |file|
        path = Pathname(file)
        name = path.basename.to_s.split('.').first
        is_not_in_filter = mixup_check(name)
        new_name = is_not_in_filter ? name.gsub(@old_class_prefix, @new_class_prefix) : name
        new_file_path = is_not_in_filter ? "#{path.parent}/#{new_name}#{path.extname}" : file
        contents = File.open(file).read
        MixupFile.new(name, new_name, file, new_file_path, contents, is_not_in_filter)
      }.to_a
      puts "-> 正在处理[#{@old_class_prefix} >> #{@new_class_prefix}]代码混淆...".yellow

      # 开始混淆
      # 修改引用
      @files.each { |file| mix_class_prefix(file) if file.is_not_in_filter }

      # 修改文件名
      @files.each do |file|
        unless file.path.equal?(file.new_path) && !file.is_not_in_filter
          FileUtils.remove_file(file.path)
          File.open(file.new_path, 'w') { |fw| fw.write(file.contents) }
        end
      end

      end_time = (Time.now.to_f * 1000).to_i
      duration = end_time - begin_time
      puts "-> 代码混淆处理完成 [#{duration / 1000.0} sec]".green
    end

    # 过滤路由相关
    def mixup_check(file_name)
      @filter_file_prefixes.select { |prefix| file_name.start_with?(prefix) }.count.zero?
    end

    # 修改类前缀
    def mix_class_prefix(file)
      # 查找引用
      ref_files = @files.filter {|f| f.contents.gsub(file.name).count > 0}

      # 修改引用
      ref_files.each {|ref_file|
        contents = File.open(ref_file.path).read
        contents.gsub!("Target_#{file.name}", "☢☢☢☢☢☢")
        contents.gsub!(file.name, file.new_name)
        contents.gsub!("☢☢☢☢☢☢", "Target_#{file.name}")
        ref_file.contents = contents
        FileUtils.remove_file(ref_file.path)
        File.open(ref_file.path, 'w') { |fw| fw.write(contents) }
      }
    end

    # 混淆文件夹
    def mix_dirs
      dirs = match_dirs

      while dirs.count > 0
        mix_dir_name(dirs[0])
        dirs = match_dirs
      end
    end

    # 匹配需要混淆的文件夹
    def match_dirs
      # 匹配所有包含 "Submodules" 子目录，并且在 "Submodules" 之后的某个位置有一个以 "BT" 开头的目录。
      # 排除 ".xc" 结尾的路径
      # 排除所有文件的路径
      Dir.glob("**/Submodules/**/BT*/")
         .filter {|f| !Pathname(f).basename.to_s.include?('.xc')}
         .filter {|f| Pathname(f).directory? }
    end

    # 混淆文件夹名称 重命名
    def mix_dir_name(dir_path)
      path = Pathname(dir_path)
      name = path.basename.to_s
      name.gsub!(@old_class_prefix, @new_class_prefix)
      new_path = Pathname("#{path.parent.to_s}/#{name}")
      path.rename(new_path)
    end


    # 混淆图片资源 依赖：`brew install imagemagick`
    def mix_images_hash

      if Dir.glob("#{@des_path}/**/*@*x.png").empty? && Dir.glob("#{@des_path}/**/*.{jpeg,jpg}")
        puts "-> 未检测到需要混淆的图片资源，跳过图片混淆。".green
        return
      end
      `convert -version`
      if $? != 0
        puts "-> 命令不全，请考虑用[brew install imagemagick]来安装。".red
        `rm -rf #{@des_path}`
        Process.exit(1)
      end

      begin_time = (Time.now.to_f * 1000).to_i
      puts "-> 正在处理图片hash混淆...".yellow

      # 过滤 包含 AnimationImages 和 Logo -  的图片
      Dir.glob("#{@des_path}/**/*@*x.png")
         .filter {|f| f.gsub('AnimationImages').count == 0 && f.gsub('Logo - ').count == 0 }
         .each {
        |f|
           command = "convert #{f} #{f}"
           `#{command}`
      }

      # 过滤 包含 AnimationImages 和 Logo -  的图片
      Dir.glob("#{@des_path}/**/*.{jpeg,jpg}")
        .filter {|f| f.gsub('AnimationImages').count == 0 && f.gsub('Logo - ').count == 0 }
        .each {
        |f|
          command = "convert #{f} #{f}"
          `#{command}`
      }
      end_time = (Time.now.to_f * 1000).to_i
      duration = end_time - begin_time
      puts "-> 图片hash混淆处理完成 [#{duration / 1000.0} sec]".green
    end

    # 混淆podspec文件
    def mix_podspec

      begin_time = (Time.now.to_f * 1000).to_i
      puts "-> 正在处理[#{@new_spec_name}.podspec]混淆...".yellow
      content = File.open(@spec_file).read
      content = content.gsub("#{@spec_name}", "#{@new_spec_name}")
      @new_spec_file = @spec_file.gsub("#{@spec_name}.podspec", ".tmp/#{@new_spec_name}.podspec")
      File.open(@new_spec_file, 'w') {|fw| fw.write(content) }

      end_time = (Time.now.to_f * 1000).to_i
      duration = end_time - begin_time
      puts "-> [#{@new_spec_name}.podspec]混淆处理完成 [#{duration / 1000.0} sec]".green

    end

    public
    # 添加subspec
    def append_subspec
      content = File.open(@spec_file).read.to_s
      # 已添加subspec跳过
      return content unless content.gsub(/\s{2}s\.subspec '#{@new_class_prefix}[\w\W]*?\bend/).to_a.empty?

      # 获取原有的subspec
      framework_spec_contents = content.gsub(/\s{2}s\.subspec 'CoreFramework[\w\W]*?\bend/).to_a
      file_urls = content.gsub(/:http => "https:\/\/gitlab.v.show\/api\/v4\/projects\/(\d+)\/#\{zip_file_path}%2F#\{s.name.to_s}-#\{s.version.to_s}\.zip\/raw\?ref=main",/).to_a

      if framework_spec_contents.empty? || file_urls.empty?
        puts "-> podspec配置不正确，请检查#{@spec_file}s.source、CoreFramework字段。".red
        `rm -rf #{@des_path}`
        `rm -rf .tmp` if Dir.exist?('.tmp')
        Process.exit(1)
      end
      framework_spec_content = framework_spec_contents.first.to_s

      new_framework_spec_content = framework_spec_content.gsub(@spec_name, @new_spec_name)
      new_framework_spec_content = new_framework_spec_content.gsub('CoreFramework', "#{@new_class_prefix}")

      spec_content = <<-SPEC
#{framework_spec_content}

  # 以下为脚本依赖CoreFramework自动生成代码，勿动⚠️⚠️ 如CoreFramework有改动请删除。
#{new_framework_spec_content}
      SPEC
      content.gsub!(framework_spec_content, spec_content)

      # 插入下载地址
      file_url = file_urls.first.to_s
      new_file_url = file_url.gsub(/\#{s.name.to_s}/, @new_spec_name)
      new_file_url.gsub!(":http", ":http_#{@new_class_prefix}")

      http_url = <<~SOURCE
        #{file_url}
              #{new_file_url}
      SOURCE
      content.gsub!(file_url, http_url.chomp) unless content.include?(new_file_url)

      File.open(@spec_file, 'w') {|fw| fw.write(content) }
    end


  end

end
