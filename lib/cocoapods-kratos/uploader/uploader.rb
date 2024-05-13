module Pod
  class JRPackageUploader

    def initialize(spec_name, spec_summary, version, upload, source_dir)
      @spec_name = spec_name
      @spec_summary = spec_summary
      @version = version
      @upload = upload
      @source_dir = source_dir
    end

    # 压缩文件
    def create_zip_file(zip_file, target_dir, vendored_frameworks)
      UI.puts "-> 正在创建 #{zip_file}...".yellow
      name = zip_file.split('-').first
      zip_root_dir = File.dirname(Dir.new(target_dir))
      `ditto #{target_dir}/ios/#{name}.framework #{zip_root_dir}/tmp/#{name}.framework`
      resources_dir = "tmp/#{name}.framework/Versions/A/Resources"
      if Dir.exist?(resources_dir)
        `mv #{resources_dir}/#{name}.bundle tmp/` if Dir.exist?("#{resources_dir}/#{name}.bundle")
        `rm -rf #{resources_dir}`
        `rm -rf tmp/#{name}.framework/Resources`
      end

      if File.exist?("#{File.dirname(Dir.new(target_dir))}/#{zip_file}")
        `rm #{File.dirname(Dir.new(target_dir))}/#{zip_file}`
      end

      # 拷贝依赖
      unless vendored_frameworks.empty?
        vendored_frameworks.each {|fw| `ditto #{fw} #{zip_root_dir}/tmp/#{Pathname(fw).basename}`}
      end

      Dir.chdir("#{zip_root_dir}/tmp")
      `zip --symlinks -q -r -o -9 #{zip_file} ./`
      `mv #{zip_file} "#{File.dirname(Dir.new(target_dir))}"`
      Dir.chdir(@source_dir)
      `rm -rf #{zip_root_dir}/tmp`

      zip_path = "#{zip_root_dir}/#{zip_file}"
      if File.exist?("#{zip_path}")
        `rm -rf #{target_dir}`
      end
      unless File.exist?(zip_path)
        UI.puts "-> 二进制文件压缩失败！".red
        Process.exit(1)
      end
      UI.puts "-> 二进制文件压缩成功！".green
      zip_path
    end

  end

end
