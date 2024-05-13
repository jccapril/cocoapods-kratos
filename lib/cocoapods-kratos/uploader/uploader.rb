module Pod
  class JRPackageUploader

    def initialize(spec_name, spec_summary, version, upload, source_dir)
      @spec_name = spec_name
      @spec_summary = spec_summary
      @version = version
      @upload = upload
      @source_dir = source_dir
    end

  end

end
